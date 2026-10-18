/// Groups of companions walking one route together (spec 11b).
///
/// Every member walks a run of their own; the group only says who walks
/// with whom, and the server reads everyone's marks to show the progress.
library;

enum CompanionGroupStatus {
  gathering,
  started,
  settled,
  cancelled;

  static CompanionGroupStatus parse(Object? value) => switch (value) {
    'started' => started,
    'settled' => settled,
    'cancelled' => cancelled,
    _ => gathering,
  };

  bool get isLive => this == gathering || this == started;
}

enum CompanionMemberState {
  invited,
  requested,
  joined,
  declined,
  revoked,
  rejected,
  removed,
  left;

  static CompanionMemberState? tryParse(Object? value) {
    for (final state in values) {
      if (state.name == value) return state;
    }
    return null;
  }
}

class CompanionMember {
  const CompanionMember({
    required this.userId,
    required this.displayName,
    required this.state,
    this.avatarUrl,
    this.isOrganizer = false,
    this.ready = false,
    this.joinedLate = false,
    this.started = false,
    this.inviteExpiresAt,
    this.beanHat,
    this.beanKind,
    this.beanOutfit,
    this.rankTitle,
  });

  /// The person's rank, as on the profile (BACKEND-74).
  final String? rankTitle;

  /// The hat on this person's character; null is the default one.
  final String? beanHat;

  /// Which of the four characters and what it wears (FRONTEND-79); null
  /// is the given build and no clothes.
  final String? beanKind;
  final String? beanOutfit;

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final CompanionMemberState state;
  final bool isOrganizer;
  final bool ready;
  final bool joinedLate;

  /// The member's own run is attached to the group.
  final bool started;
  final DateTime? inviteExpiresAt;

  factory CompanionMember.fromJson(Map<String, dynamic> json) =>
      CompanionMember(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        state:
            CompanionMemberState.tryParse(json['state']) ??
            CompanionMemberState.joined,
        isOrganizer: json['is_organizer'] as bool? ?? false,
        ready: json['ready'] as bool? ?? false,
        joinedLate: json['joined_late'] as bool? ?? false,
        started: json['started'] as bool? ?? false,
        beanHat: json['bean_hat'] as String?,
        beanKind: json['bean_kind'] as String?,
        beanOutfit: json['bean_outfit'] as String?,
        rankTitle: json['rank_title'] as String?,
        inviteExpiresAt: DateTime.tryParse(
          json['invite_expires_at'] as String? ?? '',
        ),
      );
}

class CompanionGroup {
  const CompanionGroup({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.status,
    required this.organizerUserId,
    required this.organizerName,
    required this.isOrganizer,
    required this.maxMembers,
    required this.members,
    this.routeCoverUrl,
    this.myState,
    this.joinCode,
    this.joinedCount = 0,
    this.startedAt,
    this.cancelReason,
  });

  final String id;
  final String routeId;
  final String routeName;
  final String? routeCoverUrl;
  final CompanionGroupStatus status;
  final String organizerUserId;
  final String organizerName;
  final bool isOrganizer;
  final int maxMembers;
  final CompanionMemberState? myState;

  /// Shown to the people in the group only.
  final String? joinCode;
  final List<CompanionMember> members;
  final int joinedCount;
  final DateTime? startedAt;
  final String? cancelReason;

  bool get isInvitation => myState == CompanionMemberState.invited;
  bool get isRequest => myState == CompanionMemberState.requested;
  bool get isInside => isOrganizer || myState == CompanionMemberState.joined;

  List<CompanionMember> get joined => [
    for (final member in members)
      if (member.state == CompanionMemberState.joined) member,
  ];

  List<CompanionMember> get invited => [
    for (final member in members)
      if (member.state == CompanionMemberState.invited) member,
  ];

  List<CompanionMember> get requests => [
    for (final member in members)
      if (member.state == CompanionMemberState.requested) member,
  ];

  CompanionMember? memberOf(String userId) {
    for (final member in members) {
      if (member.userId == userId) return member;
    }
    return null;
  }

  factory CompanionGroup.fromJson(Map<String, dynamic> json) => CompanionGroup(
    id: json['id'] as String,
    routeId: json['route_id'] as String,
    routeName: json['route_name'] as String? ?? '',
    routeCoverUrl: json['route_cover_url'] as String?,
    status: CompanionGroupStatus.parse(json['status']),
    organizerUserId: json['organizer_user_id'] as String,
    organizerName: json['organizer_display_name'] as String? ?? '',
    isOrganizer: json['is_organizer'] as bool? ?? false,
    maxMembers: (json['max_members'] as num?)?.toInt() ?? 8,
    myState: CompanionMemberState.tryParse(json['my_state']),
    joinCode: json['join_code'] as String?,
    members: [
      for (final item in json['members'] as List<dynamic>? ?? const [])
        CompanionMember.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
    joinedCount: (json['joined_count'] as num?)?.toInt() ?? 0,
    startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
    cancelReason: json['cancel_reason'] as String?,
  );
}

enum CompanionRunStatus {
  notStarted,
  walking,
  paused,
  finished,
  quit,
  notFinished;

  static CompanionRunStatus parse(Object? value) => switch (value) {
    'walking' => walking,
    'paused' => paused,
    'finished' => finished,
    'quit' => quit,
    'not_finished' => notFinished,
    _ => notStarted,
  };

  String get label => switch (this) {
    notStarted => 'Не стартовал',
    walking => 'В пути',
    paused => 'На паузе',
    finished => 'Дошёл',
    quit => 'Сошёл',
    notFinished => 'Не завершил',
  };
}

class CompanionStopMark {
  const CompanionStopMark({
    required this.position,
    this.markedAt,
    this.skipped = false,
    this.offline = false,
  });

  final int position;
  final DateTime? markedAt;
  final bool skipped;
  final bool offline;

  factory CompanionStopMark.fromJson(Map<String, dynamic> json) =>
      CompanionStopMark(
        position: (json['position'] as num).toInt(),
        markedAt: DateTime.tryParse(json['marked_at'] as String? ?? ''),
        skipped: json['skipped'] as bool? ?? false,
        offline: json['offline'] as bool? ?? false,
      );
}

class CompanionMemberProgress {
  const CompanionMemberProgress({
    required this.userId,
    required this.displayName,
    required this.status,
    this.avatarUrl,
    this.isOrganizer = false,
    this.joinedLate = false,
    this.lastPosition = 0,
    this.marks = const [],
    this.reached = false,
    this.finishedAt,
    this.beanHat,
    this.beanKind,
    this.beanOutfit,
    this.rankTitle,
    this.startedAt,
  });

  final String? beanHat;
  final String? beanKind;
  final String? beanOutfit;
  final String? rankTitle;

  /// When this member's own run began; null before.
  final DateTime? startedAt;

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool isOrganizer;
  final bool joinedLate;
  final CompanionRunStatus status;
  final int lastPosition;
  final List<CompanionStopMark> marks;
  final bool reached;
  final DateTime? finishedAt;

  factory CompanionMemberProgress.fromJson(Map<String, dynamic> json) =>
      CompanionMemberProgress(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        isOrganizer: json['is_organizer'] as bool? ?? false,
        joinedLate: json['joined_late'] as bool? ?? false,
        status: CompanionRunStatus.parse(json['status']),
        lastPosition: (json['last_position'] as num?)?.toInt() ?? 0,
        marks: [
          for (final item in json['marks'] as List<dynamic>? ?? const [])
            CompanionStopMark.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
        reached: json['reached'] as bool? ?? false,
        beanHat: json['bean_hat'] as String?,
        beanKind: json['bean_kind'] as String?,
        beanOutfit: json['bean_outfit'] as String?,
        rankTitle: json['rank_title'] as String?,
        startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
        finishedAt: DateTime.tryParse(json['finished_at'] as String? ?? ''),
      );
}

class CompanionStop {
  const CompanionStop({
    required this.position,
    required this.placeName,
    this.isOptional = false,
    this.firstUserId,
    this.distanceFromStartMeters,
  });

  final int position;
  final String placeName;
  final bool isOptional;

  /// Along the route from the first stop (BACKEND-74); null if unknown.
  final int? distanceFromStartMeters;

  /// Who got here first among marks made online.
  final String? firstUserId;

  factory CompanionStop.fromJson(Map<String, dynamic> json) => CompanionStop(
    position: (json['position'] as num).toInt(),
    placeName: json['place_name'] as String? ?? '',
    isOptional: json['is_optional'] as bool? ?? false,
    firstUserId: json['first_user_id'] as String?,
    distanceFromStartMeters: (json['distance_from_start_meters'] as num?)
        ?.toInt(),
  );
}

class CompanionSummary {
  const CompanionSummary({
    required this.settled,
    required this.startedCount,
    required this.reachedCount,
    required this.everyoneReached,
    this.distanceMeters,
    this.totalSeconds,
    this.firstFinisherUserId,
  });

  final bool settled;
  final int startedCount;
  final int reachedCount;
  final bool everyoneReached;
  final int? distanceMeters;
  final int? totalSeconds;
  final String? firstFinisherUserId;

  factory CompanionSummary.fromJson(Map<String, dynamic> json) =>
      CompanionSummary(
        settled: json['settled'] as bool? ?? false,
        startedCount: (json['started_count'] as num?)?.toInt() ?? 0,
        reachedCount: (json['reached_count'] as num?)?.toInt() ?? 0,
        everyoneReached: json['everyone_reached'] as bool? ?? false,
        distanceMeters: (json['distance_meters'] as num?)?.toInt(),
        totalSeconds: (json['total_seconds'] as num?)?.toInt(),
        firstFinisherUserId: json['first_finisher_user_id'] as String?,
      );
}

class CompanionProgress {
  const CompanionProgress({
    required this.groupId,
    required this.status,
    required this.stops,
    required this.members,
    required this.summary,
    this.leaderboardHidden = false,
    this.startedAt,
  });

  final String groupId;
  final CompanionGroupStatus status;
  final DateTime? startedAt;
  final bool leaderboardHidden;
  final List<CompanionStop> stops;
  final List<CompanionMemberProgress> members;
  final CompanionSummary summary;

  factory CompanionProgress.fromJson(Map<String, dynamic> json) =>
      CompanionProgress(
        groupId: json['group_id'] as String,
        status: CompanionGroupStatus.parse(json['status']),
        startedAt: DateTime.tryParse(json['started_at'] as String? ?? ''),
        leaderboardHidden: json['leaderboard_hidden'] as bool? ?? false,
        stops: [
          for (final item in json['stops'] as List<dynamic>? ?? const [])
            CompanionStop.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
        members: [
          for (final item in json['members'] as List<dynamic>? ?? const [])
            CompanionMemberProgress.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
        ],
        summary: CompanionSummary.fromJson(
          Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
        ),
      );
}

/// A person the user may invite: a mutual follower who accepts invites.
class InvitablePerson {
  const InvitablePerson({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.rankTitle,
    this.coverUrl,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? rankTitle;

  /// The profile cover: the background of a person's card (DESIGN-19).
  final String? coverUrl;

  factory InvitablePerson.fromJson(Map<String, dynamic> json) =>
      InvitablePerson(
        userId: json['id'] as String,
        displayName: json['display_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        rankTitle: json['rank_title'] as String?,
        coverUrl: json['cover_url'] as String?,
      );
}

abstract interface class CompanionsRepository {
  Future<CompanionGroup> create(String routeId);
  Future<List<CompanionGroup>> myGroups();
  Future<CompanionGroup> get(String groupId);
  Future<CompanionProgress> progress(String groupId);
  Future<List<InvitablePerson>> invitable();
  Future<CompanionGroup> invite(String groupId, String userId);
  Future<CompanionGroup> respond(String groupId, {required bool accept});
  Future<CompanionGroup> joinByCode(String code);
  Future<CompanionGroup> answerRequest(
    String groupId,
    String userId, {
    required bool approve,
  });

  /// Null when the person left the group themselves.
  Future<CompanionGroup?> removeMember(String groupId, String userId);
  Future<CompanionGroup> cancel(String groupId);
  Future<CompanionGroup> setReady(String groupId, {required bool ready});
  Future<CompanionGroup> start(String groupId);
  Future<void> report(
    String groupId, {
    required String reason,
    String? comment,
  });
}
