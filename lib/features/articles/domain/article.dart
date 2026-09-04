/// Domain models for the article/blog content type (Workstream G).
///
/// Mirrors the backend wire shapes in
/// `tourism_backend/modules/content/application/article_schemas.py` field for
/// field — see the mobile backlog doc (G.7) for the full contract.
library;

enum ArticleStatus {
  draft('draft'),
  pendingReview('pending_review'),
  published('published'),
  rejected('rejected'),
  deleted('deleted');

  const ArticleStatus(this.apiValue);
  final String apiValue;

  static ArticleStatus fromApi(String? value) {
    return values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => draft,
    );
  }
}

enum ArticleCommentStatus {
  pendingReview('pending_review'),
  published('published'),
  rejected('rejected'),
  deleted('deleted');

  const ArticleCommentStatus(this.apiValue);
  final String apiValue;

  static ArticleCommentStatus fromApi(String? value) {
    return values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => published,
    );
  }
}

enum ArticleBlockType {
  text('text'),
  image('image'),
  quote('quote'),
  list('list'),
  divider('divider');

  const ArticleBlockType(this.apiValue);
  final String apiValue;

  static ArticleBlockType fromApi(String? value) {
    return values.firstWhere(
      (type) => type.apiValue == value,
      orElse: () => text,
    );
  }
}

enum ListStyle {
  bullet('bullet'),
  numbered('numbered');

  const ListStyle(this.apiValue);
  final String apiValue;

  static ListStyle fromApi(String? value) {
    return values.firstWhere(
      (style) => style.apiValue == value,
      orElse: () => bullet,
    );
  }
}

class ArticleBlock {
  const ArticleBlock({
    required this.id,
    required this.position,
    required this.blockType,
    this.textContent,
    this.caption,
    this.listStyle,
    this.imageUrl,
    this.imageWidth,
    this.imageHeight,
  });

  final String id;
  final int position;
  final ArticleBlockType blockType;
  final String? textContent;
  final String? caption;
  final ListStyle? listStyle;
  final String? imageUrl;
  final int? imageWidth;
  final int? imageHeight;

  /// `list`-type [textContent] is stored newline-separated — this is the
  /// rendering-ready split, never empty lines.
  List<String> get listItems => textContent == null
      ? const []
      : [
          for (final line in textContent!.split('\n'))
            if (line.trim().isNotEmpty) line.trim(),
        ];

  ArticleBlock copyWith({
    String? id,
    int? position,
    ArticleBlockType? blockType,
    String? textContent,
    bool clearTextContent = false,
    String? caption,
    bool clearCaption = false,
    ListStyle? listStyle,
    bool clearListStyle = false,
    String? imageUrl,
    bool clearImageUrl = false,
    int? imageWidth,
    int? imageHeight,
  }) {
    return ArticleBlock(
      id: id ?? this.id,
      position: position ?? this.position,
      blockType: blockType ?? this.blockType,
      textContent: clearTextContent ? null : textContent ?? this.textContent,
      caption: clearCaption ? null : caption ?? this.caption,
      listStyle: clearListStyle ? null : listStyle ?? this.listStyle,
      imageUrl: clearImageUrl ? null : imageUrl ?? this.imageUrl,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
    );
  }

  factory ArticleBlock.fromJson(Map<String, Object?> json) {
    return ArticleBlock(
      id: json['id']! as String,
      position: (json['position'] as num?)?.toInt() ?? 0,
      blockType: ArticleBlockType.fromApi(json['block_type'] as String?),
      textContent: json['text_content'] as String?,
      caption: json['caption'] as String?,
      listStyle: json['list_style'] == null
          ? null
          : ListStyle.fromApi(json['list_style'] as String?),
      imageUrl: json['image_url'] as String?,
      imageWidth: (json['image_width'] as num?)?.toInt(),
      imageHeight: (json['image_height'] as num?)?.toInt(),
    );
  }
}

/// Feed/section card shape — no blocks, matching `ArticleSummaryOut`.
class ArticleSummary {
  const ArticleSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.createdAt,
    this.authorAvatarUrl,
    this.authorRankTitle,
    this.authorIsExpert = false,
    this.relatedRouteId,
    this.relatedPlaceId,
    this.coverImageUrl,
    this.publishedAt,
    this.tags = const [],
    this.excerpt,
    this.readingTimeMinutes = 1,
    this.likeCount = 0,
    this.likedByMe = false,
    this.savedByMe = false,
    this.viewCount = 0,
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final ArticleStatus status;
  final String authorUserId;
  final String authorDisplayName;
  final String? authorAvatarUrl;
  final String? authorRankTitle;

  /// Проверенный эксперт: карточка и аватар получают градиентную рамку,
  /// как у карточек маршрутов ([AppExpertFrame]).
  final bool authorIsExpert;
  final String? relatedRouteId;
  final String? relatedPlaceId;
  final String? coverImageUrl;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final List<String> tags;
  final String? excerpt;
  final int readingTimeMinutes;
  final int likeCount;
  final bool likedByMe;
  final bool savedByMe;
  final int viewCount;
  final bool isFeatured;

  factory ArticleSummary.fromJson(Map<String, Object?> json) {
    return ArticleSummary(
      id: json['id']! as String,
      title: json['title'] as String? ?? '',
      status: ArticleStatus.fromApi(json['status'] as String?),
      authorUserId: json['author_user_id']! as String,
      authorDisplayName:
          json['author_display_name'] as String? ?? 'Путешественник',
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorRankTitle: json['author_rank_title'] as String?,
      authorIsExpert: json['author_is_expert'] as bool? ?? false,
      relatedRouteId: json['related_route_id'] as String?,
      relatedPlaceId: json['related_place_id'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      createdAt: DateTime.parse(json['created_at']! as String),
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      excerpt: json['excerpt'] as String?,
      readingTimeMinutes: (json['reading_time_minutes'] as num?)?.toInt() ?? 1,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
      savedByMe: json['saved_by_me'] as bool? ?? false,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      isFeatured: json['is_featured'] as bool? ?? false,
    );
  }
}

/// Full article with blocks, matching `ArticleOut`.
class Article {
  const Article({
    required this.id,
    required this.title,
    required this.status,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.createdAt,
    this.authorAvatarUrl,
    this.authorRankTitle,
    this.authorIsExpert = false,
    this.relatedRouteId,
    this.relatedPlaceId,
    this.coverImageUrl,
    this.moderatorNote,
    this.publishedAt,
    this.blocks = const [],
    this.tags = const [],
    this.excerpt,
    this.readingTimeMinutes = 1,
    this.likeCount = 0,
    this.likedByMe = false,
    this.savedByMe = false,
    this.viewCount = 0,
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final ArticleStatus status;
  final String authorUserId;
  final String authorDisplayName;
  final String? authorAvatarUrl;
  final String? authorRankTitle;

  /// Проверенный эксперт: карточка и аватар получают градиентную рамку,
  /// как у карточек маршрутов ([AppExpertFrame]).
  final bool authorIsExpert;
  final String? relatedRouteId;
  final String? relatedPlaceId;
  final String? coverImageUrl;
  final String? moderatorNote;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final List<ArticleBlock> blocks;
  final List<String> tags;
  final String? excerpt;
  final int readingTimeMinutes;
  final int likeCount;
  final bool likedByMe;
  final bool savedByMe;
  final int viewCount;
  final bool isFeatured;

  /// Sorted view — the backend orders blocks by `position` already, but a
  /// client-held draft (after local reordering) should not assume that.
  List<ArticleBlock> get sortedBlocks =>
      [...blocks]..sort((a, b) => a.position.compareTo(b.position));

  bool get isEditableByAuthor =>
      status == ArticleStatus.draft || status == ArticleStatus.rejected;

  /// Used only for the optimistic like overlay on the reading screen — every
  /// other field on an already-loaded article is immutable from the client's
  /// point of view.
  Article copyWithLike({required int likeCount, required bool likedByMe}) {
    return Article(
      id: id,
      title: title,
      status: status,
      authorUserId: authorUserId,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
      authorRankTitle: authorRankTitle,
      authorIsExpert: authorIsExpert,
      relatedRouteId: relatedRouteId,
      relatedPlaceId: relatedPlaceId,
      coverImageUrl: coverImageUrl,
      moderatorNote: moderatorNote,
      createdAt: createdAt,
      publishedAt: publishedAt,
      blocks: blocks,
      tags: tags,
      excerpt: excerpt,
      readingTimeMinutes: readingTimeMinutes,
      likeCount: likeCount,
      likedByMe: likedByMe,
      savedByMe: savedByMe,
      viewCount: viewCount,
      isFeatured: isFeatured,
    );
  }

  factory Article.fromJson(Map<String, Object?> json) {
    final rawBlocks = json['blocks'];
    return Article(
      id: json['id']! as String,
      title: json['title'] as String? ?? '',
      status: ArticleStatus.fromApi(json['status'] as String?),
      authorUserId: json['author_user_id']! as String,
      authorDisplayName:
          json['author_display_name'] as String? ?? 'Путешественник',
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorRankTitle: json['author_rank_title'] as String?,
      authorIsExpert: json['author_is_expert'] as bool? ?? false,
      relatedRouteId: json['related_route_id'] as String?,
      relatedPlaceId: json['related_place_id'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      moderatorNote: json['moderator_note'] as String?,
      createdAt: DateTime.parse(json['created_at']! as String),
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      blocks: rawBlocks is List
          ? [
              for (final item in rawBlocks)
                if (item is Map<String, Object?>) ArticleBlock.fromJson(item),
            ]
          : const [],
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      excerpt: json['excerpt'] as String?,
      readingTimeMinutes: (json['reading_time_minutes'] as num?)?.toInt() ?? 1,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
      savedByMe: json['saved_by_me'] as bool? ?? false,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      isFeatured: json['is_featured'] as bool? ?? false,
    );
  }
}

class ArticleListPage {
  const ArticleListPage({required this.items, required this.total});

  final List<ArticleSummary> items;
  final int total;

  factory ArticleListPage.fromJson(Map<String, Object?> json) {
    final raw = json['items'];
    return ArticleListPage(
      items: raw is List
          ? [
              for (final item in raw)
                if (item is Map<String, Object?>) ArticleSummary.fromJson(item),
            ]
          : const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A block to send on create/update — text blocks carry `textContent`, image
/// blocks are always created empty (see G.9: the file uploads separately).
class ArticleBlockDraft {
  const ArticleBlockDraft({
    required this.blockType,
    this.id,
    this.textContent,
    this.caption,
    this.listStyle,
  });

  final String? id;
  final ArticleBlockType blockType;
  final String? textContent;
  final String? caption;
  final ListStyle? listStyle;

  Map<String, Object?> toJson() => {
    if (id != null) 'id': id,
    'block_type': blockType.apiValue,
    'text_content': textContent,
    'caption': caption,
    'list_style': listStyle?.apiValue,
  };
}

/// Response of the like/unlike toggle — cheaper than a full [Article].
class ArticleLikeStatus {
  const ArticleLikeStatus({required this.likeCount, required this.likedByMe});

  final int likeCount;
  final bool likedByMe;

  factory ArticleLikeStatus.fromJson(Map<String, Object?> json) {
    return ArticleLikeStatus(
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
    );
  }
}

class ArticleComment {
  const ArticleComment({
    required this.id,
    required this.articleId,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.body,
    required this.status,
    required this.createdAt,
    this.authorAvatarUrl,
    this.authorRankTitle,
    this.replyToCommentId,
  });

  final String id;
  final String articleId;
  final String authorUserId;
  final String authorDisplayName;
  final String? authorAvatarUrl;

  /// Ранг автора под именем — как на макете страницы блога.
  final String? authorRankTitle;
  final String body;
  final ArticleCommentStatus status;
  final String? replyToCommentId;
  final DateTime createdAt;

  factory ArticleComment.fromJson(Map<String, Object?> json) {
    return ArticleComment(
      id: json['id']! as String,
      articleId: json['article_id']! as String,
      authorUserId: json['author_user_id']! as String,
      authorDisplayName:
          json['author_display_name'] as String? ?? 'Путешественник',
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorRankTitle: json['author_rank_title'] as String?,
      body: json['body'] as String? ?? '',
      status: ArticleCommentStatus.fromApi(json['status'] as String?),
      replyToCommentId: json['reply_to_comment_id'] as String?,
      createdAt: DateTime.parse(json['created_at']! as String),
    );
  }
}

class ArticleCommentPage {
  const ArticleCommentPage({required this.items, required this.total});

  final List<ArticleComment> items;
  final int total;

  factory ArticleCommentPage.fromJson(Map<String, Object?> json) {
    final raw = json['items'];
    return ArticleCommentPage(
      items: raw is List
          ? [
              for (final item in raw)
                if (item is Map<String, Object?>) ArticleComment.fromJson(item),
            ]
          : const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
