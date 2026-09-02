import 'package:flutter/material.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/articles/domain/article.dart';
import 'package:tourism_mobile/features/articles/presentation/widgets/article_images.dart';

/// Renders one text or image block. Image blocks reserve their
/// `imageWidth`/`imageHeight` aspect ratio before the network image decodes,
/// so the reading screen doesn't jump as covers load in.
class ArticleBlockView extends StatelessWidget {
  const ArticleBlockView({
    required this.block,
    required this.config,
    super.key,
  });

  final ArticleBlock block;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return switch (block.blockType) {
      ArticleBlockType.text => _text(),
      ArticleBlockType.image => _image(),
      ArticleBlockType.quote => _quote(),
      ArticleBlockType.list => _list(),
      ArticleBlockType.divider => _divider(),
    };
  }

  Widget _text() {
    final text = block.textContent;
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppFonts.rubik,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.primaryInk,
      ),
    );
  }

  Widget _image() {
    final url = block.imageUrl;
    if (url == null || url.isEmpty) {
      // Empty image block awaiting upload — nothing to render on the reading
      // screen (this only happens if a draft leaks into a published article,
      // which the backend's `article_empty` check prevents).
      return const SizedBox.shrink();
    }
    final aspectRatio =
        (block.imageWidth != null &&
            block.imageHeight != null &&
            block.imageHeight! > 0)
        ? block.imageWidth! / block.imageHeight!
        : 4 / 3;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.tile),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Image(
          image: articleImageProvider(
            config: config,
            url: url,
            fallbackSeed: block.id,
          ),
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) => const ColoredBox(
            color: AppColors.controlSurface,
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.secondaryInk,
            ),
          ),
        ),
      ),
    );
  }

  Widget _quote() {
    final text = block.textContent;
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    // IntrinsicHeight + stretch, like `_ReplyComposerContext` in the reviews
    // section: a bare Container in a Row has no height of its own, so the
    // accent bar would otherwise collapse to nothing.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: AppColors.accentBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    height: 1.45,
                    color: AppColors.primaryInk,
                  ),
                ),
                if (block.caption case final caption?
                    when caption.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '— $caption',
                    style: const TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 12,
                      color: AppColors.secondaryInk,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    final items = block.listItems;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final numbered = block.listStyle == ListStyle.numbered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < items.length; index++)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: numbered
                      ? Text(
                          '${index + 1}.',
                          style: const TextStyle(
                            fontFamily: AppFonts.rubik,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentBlue,
                          ),
                        )
                      : const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: 6,
                            height: 6,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.accentBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                ),
                Expanded(
                  child: Text(
                    items[index],
                    style: const TextStyle(
                      fontFamily: AppFonts.rubik,
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.primaryInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Divider(
        key: ValueKey('article-divider-block'),
        height: 1,
        color: Color(0xFFE3E3E5),
      ),
    );
  }
}
