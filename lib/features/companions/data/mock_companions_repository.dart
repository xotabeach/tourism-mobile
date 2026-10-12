import 'package:tourism_mobile/features/companions/domain/companion_group.dart';

/// In-memory groups for the demo build and tests: the same rules as the
/// server where the screens depend on them, nothing more.
class MockCompanionsRepository implements CompanionsRepository {
  MockCompanionsRepository({this.meId = 'mock-user', this.meName = 'Никита'});

  final String meId;
  final String meName;
  final _groups = <String, CompanionGroup>{};
  var _seq = 0;

  static const people = [
    InvitablePerson(userId: 'friend-1', displayName: 'Андрей'),
    InvitablePerson(userId: 'friend-2', displayName: 'Марина'),
    InvitablePerson(userId: 'friend-3', displayName: 'Глеб'),
  ];

  CompanionGroup _put(CompanionGroup group) => _groups[group.id] = group;

  CompanionGroup _copy(
    CompanionGroup group, {
    CompanionGroupStatus? status,
    List<CompanionMember>? members,
    DateTime? startedAt,
  }) => CompanionGroup(
    id: group.id,
    routeId: group.routeId,
    routeName: group.routeName,
    routeCoverUrl: group.routeCoverUrl,
    status: status ?? group.status,
    organizerUserId: group.organizerUserId,
    organizerName: group.organizerName,
    isOrganizer: group.isOrganizer,
    maxMembers: group.maxMembers,
    myState: group.myState,
    joinCode: group.joinCode,
    members: members ?? group.members,
    joinedCount: (members ?? group.members)
        .where((m) => m.state == CompanionMemberState.joined)
        .length,
    startedAt: startedAt ?? group.startedAt,
    cancelReason: group.cancelReason,
  );

  CompanionGroup _byId(String id) {
    final group = _groups[id];
    if (group == null) throw StateError('Группа не найдена');
    return group;
  }

  CompanionMember _member(
    String userId,
    String name,
    CompanionMemberState state, {
    bool organizer = false,
    bool ready = false,
  }) => CompanionMember(
    userId: userId,
    displayName: name,
    state: state,
    isOrganizer: organizer,
    ready: ready,
  );

  @override
  Future<CompanionGroup> create(String routeId) async {
    final id = 'group-${++_seq}';
    return _put(
      CompanionGroup(
        id: id,
        routeId: routeId,
        routeName: 'Классика Южного берега',
        status: CompanionGroupStatus.gathering,
        organizerUserId: meId,
        organizerName: meName,
        isOrganizer: true,
        maxMembers: 8,
        myState: CompanionMemberState.joined,
        joinCode: 'KRM${_seq}2Q',
        members: [
          _member(meId, meName, CompanionMemberState.joined, organizer: true),
        ],
        joinedCount: 1,
      ),
    );
  }

  @override
  Future<List<CompanionGroup>> myGroups() async => _groups.values
      .where((group) => group.status.isLive)
      .toList(growable: false);

  @override
  Future<CompanionGroup> get(String groupId) async => _byId(groupId);

  @override
  Future<CompanionProgress> progress(String groupId) async {
    final group = _byId(groupId);
    return CompanionProgress(
      groupId: group.id,
      status: group.status,
      startedAt: group.startedAt,
      stops: const [
        CompanionStop(position: 1, placeName: 'Ливадийский дворец'),
        CompanionStop(position: 2, placeName: 'Ласточкино гнездо'),
        CompanionStop(position: 3, placeName: 'Воронцовский дворец'),
      ],
      members: [
        for (final member in group.joined)
          CompanionMemberProgress(
            userId: member.userId,
            displayName: member.displayName,
            isOrganizer: member.isOrganizer,
            status: group.status == CompanionGroupStatus.started
                ? CompanionRunStatus.walking
                : CompanionRunStatus.notStarted,
          ),
      ],
      summary: CompanionSummary(
        settled: group.status == CompanionGroupStatus.settled,
        startedCount: 0,
        reachedCount: 0,
        everyoneReached: false,
      ),
    );
  }

  @override
  Future<List<InvitablePerson>> invitable() async => people;

  @override
  Future<CompanionGroup> invite(String groupId, String userId) async {
    final group = _byId(groupId);
    if (group.memberOf(userId) != null) return group;
    final person = people.firstWhere((p) => p.userId == userId);
    return _put(
      _copy(
        group,
        members: [
          ...group.members,
          _member(userId, person.displayName, CompanionMemberState.invited),
        ],
      ),
    );
  }

  @override
  Future<CompanionGroup> respond(String groupId, {required bool accept}) async {
    final group = _byId(groupId);
    return _put(_copy(group));
  }

  @override
  Future<CompanionGroup> joinByCode(String code) async {
    for (final group in _groups.values) {
      if (group.joinCode == code.toUpperCase()) return group;
    }
    throw StateError('Код не подошёл');
  }

  @override
  Future<CompanionGroup> answerRequest(
    String groupId,
    String userId, {
    required bool approve,
  }) async {
    final group = _byId(groupId);
    return _put(
      _copy(
        group,
        members: [
          for (final member in group.members)
            member.userId == userId
                ? _member(
                    member.userId,
                    member.displayName,
                    approve
                        ? CompanionMemberState.joined
                        : CompanionMemberState.rejected,
                  )
                : member,
        ],
      ),
    );
  }

  @override
  Future<CompanionGroup?> removeMember(String groupId, String userId) async {
    final group = _byId(groupId);
    final updated = _put(
      _copy(
        group,
        members: [
          for (final member in group.members)
            if (member.userId != userId) member,
        ],
      ),
    );
    return userId == meId ? null : updated;
  }

  @override
  Future<CompanionGroup> cancel(String groupId) async =>
      _put(_copy(_byId(groupId), status: CompanionGroupStatus.cancelled));

  @override
  Future<CompanionGroup> setReady(String groupId, {required bool ready}) async {
    final group = _byId(groupId);
    return _put(
      _copy(
        group,
        members: [
          for (final member in group.members)
            member.userId == meId
                ? _member(
                    member.userId,
                    member.displayName,
                    member.state,
                    organizer: member.isOrganizer,
                    ready: ready,
                  )
                : member,
        ],
      ),
    );
  }

  @override
  Future<CompanionGroup> start(String groupId) async => _put(
    _copy(
      _byId(groupId),
      status: CompanionGroupStatus.started,
      startedAt: DateTime.now(),
    ),
  );

  @override
  Future<void> report(
    String groupId, {
    required String reason,
    String? comment,
  }) async {}
}
