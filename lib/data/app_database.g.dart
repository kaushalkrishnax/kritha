// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ChatSessionsTable extends ChatSessions
    with TableInfo<$ChatSessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    updatedAt,
    pinned,
    archived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
    );
  }

  @override
  $ChatSessionsTable createAlias(String alias) {
    return $ChatSessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pinned;
  final bool archived;
  const SessionRow({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.pinned,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['pinned'] = Variable<bool>(pinned);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  ChatSessionsCompanion toCompanion(bool nullToAbsent) {
    return ChatSessionsCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      pinned: Value(pinned),
      archived: Value(archived),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'pinned': serializer.toJson<bool>(pinned),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  SessionRow copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? pinned,
    bool? archived,
  }) => SessionRow(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    pinned: pinned ?? this.pinned,
    archived: archived ?? this.archived,
  );
  SessionRow copyWithCompanion(ChatSessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pinned: $pinned, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, createdAt, updatedAt, pinned, archived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.pinned == this.pinned &&
          other.archived == this.archived);
}

class ChatSessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> pinned;
  final Value<bool> archived;
  final Value<int> rowid;
  const ChatSessionsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.pinned = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatSessionsCompanion.insert({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.pinned = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? pinned,
    Expression<bool>? archived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (pinned != null) 'pinned': pinned,
      if (archived != null) 'archived': archived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? pinned,
    Value<bool>? archived,
    Value<int>? rowid,
  }) {
    return ChatSessionsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatSessionsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pinned: $pinned, ')
          ..write('archived: $archived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatEntriesTable extends ChatEntries
    with TableInfo<$ChatEntriesTable, ChatEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attachmentsJsonMeta = const VerificationMeta(
    'attachmentsJson',
  );
  @override
  late final GeneratedColumn<String> attachmentsJson = GeneratedColumn<String>(
    'attachments_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    role,
    content,
    createdAt,
    attachmentsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attachments_json')) {
      context.handle(
        _attachmentsJsonMeta,
        attachmentsJson.isAcceptableOrUnknown(
          data['attachments_json']!,
          _attachmentsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attachmentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments_json'],
      )!,
    );
  }

  @override
  $ChatEntriesTable createAlias(String alias) {
    return $ChatEntriesTable(attachedDatabase, alias);
  }
}

class ChatEntry extends DataClass implements Insertable<ChatEntry> {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final DateTime createdAt;
  final String attachmentsJson;
  const ChatEntry({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.attachmentsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attachments_json'] = Variable<String>(attachmentsJson);
    return map;
  }

  ChatEntriesCompanion toCompanion(bool nullToAbsent) {
    return ChatEntriesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      role: Value(role),
      content: Value(content),
      createdAt: Value(createdAt),
      attachmentsJson: Value(attachmentsJson),
    );
  }

  factory ChatEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatEntry(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attachmentsJson: serializer.fromJson<String>(json['attachmentsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attachmentsJson': serializer.toJson<String>(attachmentsJson),
    };
  }

  ChatEntry copyWith({
    String? id,
    String? sessionId,
    String? role,
    String? content,
    DateTime? createdAt,
    String? attachmentsJson,
  }) => ChatEntry(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    role: role ?? this.role,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    attachmentsJson: attachmentsJson ?? this.attachmentsJson,
  );
  ChatEntry copyWithCompanion(ChatEntriesCompanion data) {
    return ChatEntry(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attachmentsJson: data.attachmentsJson.present
          ? data.attachmentsJson.value
          : this.attachmentsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatEntry(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('attachmentsJson: $attachmentsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, role, content, createdAt, attachmentsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatEntry &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.role == this.role &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.attachmentsJson == this.attachmentsJson);
}

class ChatEntriesCompanion extends UpdateCompanion<ChatEntry> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> role;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<String> attachmentsJson;
  final Value<int> rowid;
  const ChatEntriesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attachmentsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatEntriesCompanion.insert({
    required String id,
    this.sessionId = const Value.absent(),
    required String role,
    required String content,
    required DateTime createdAt,
    this.attachmentsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       role = Value(role),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<ChatEntry> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<String>? attachmentsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (attachmentsJson != null) 'attachments_json': attachmentsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? role,
    Value<String>? content,
    Value<DateTime>? createdAt,
    Value<String>? attachmentsJson,
    Value<int>? rowid,
  }) {
    return ChatEntriesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      attachmentsJson: attachmentsJson ?? this.attachmentsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attachmentsJson.present) {
      map['attachments_json'] = Variable<String>(attachmentsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatEntriesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('attachmentsJson: $attachmentsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActionPreferencesTable extends ActionPreferences
    with TableInfo<$ActionPreferencesTable, ActionPreferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActionPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _actionKeyMeta = const VerificationMeta(
    'actionKey',
  );
  @override
  late final GeneratedColumn<String> actionKey = GeneratedColumn<String>(
    'action_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [actionKey, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'action_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActionPreferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('action_key')) {
      context.handle(
        _actionKeyMeta,
        actionKey.isAcceptableOrUnknown(data['action_key']!, _actionKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_actionKeyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {actionKey};
  @override
  ActionPreferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActionPreferenceRow(
      actionKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ActionPreferencesTable createAlias(String alias) {
    return $ActionPreferencesTable(attachedDatabase, alias);
  }
}

class ActionPreferenceRow extends DataClass
    implements Insertable<ActionPreferenceRow> {
  final String actionKey;
  final String value;
  final DateTime updatedAt;
  const ActionPreferenceRow({
    required this.actionKey,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['action_key'] = Variable<String>(actionKey);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ActionPreferencesCompanion toCompanion(bool nullToAbsent) {
    return ActionPreferencesCompanion(
      actionKey: Value(actionKey),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory ActionPreferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActionPreferenceRow(
      actionKey: serializer.fromJson<String>(json['actionKey']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'actionKey': serializer.toJson<String>(actionKey),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ActionPreferenceRow copyWith({
    String? actionKey,
    String? value,
    DateTime? updatedAt,
  }) => ActionPreferenceRow(
    actionKey: actionKey ?? this.actionKey,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ActionPreferenceRow copyWithCompanion(ActionPreferencesCompanion data) {
    return ActionPreferenceRow(
      actionKey: data.actionKey.present ? data.actionKey.value : this.actionKey,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActionPreferenceRow(')
          ..write('actionKey: $actionKey, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(actionKey, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActionPreferenceRow &&
          other.actionKey == this.actionKey &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class ActionPreferencesCompanion extends UpdateCompanion<ActionPreferenceRow> {
  final Value<String> actionKey;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ActionPreferencesCompanion({
    this.actionKey = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActionPreferencesCompanion.insert({
    required String actionKey,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : actionKey = Value(actionKey),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<ActionPreferenceRow> custom({
    Expression<String>? actionKey,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (actionKey != null) 'action_key': actionKey,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActionPreferencesCompanion copyWith({
    Value<String>? actionKey,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ActionPreferencesCompanion(
      actionKey: actionKey ?? this.actionKey,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (actionKey.present) {
      map['action_key'] = Variable<String>(actionKey.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActionPreferencesCompanion(')
          ..write('actionKey: $actionKey, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelsTable extends Models with TableInfo<$ModelsTable, Model> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalModelIdMeta = const VerificationMeta(
    'externalModelId',
  );
  @override
  late final GeneratedColumn<String> externalModelId = GeneratedColumn<String>(
    'external_model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentModelIdMeta = const VerificationMeta(
    'parentModelId',
  );
  @override
  late final GeneratedColumn<String> parentModelId = GeneratedColumn<String>(
    'parent_model_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _suffixMeta = const VerificationMeta('suffix');
  @override
  late final GeneratedColumn<String> suffix = GeneratedColumn<String>(
    'suffix',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publisherMeta = const VerificationMeta(
    'publisher',
  );
  @override
  late final GeneratedColumn<String> publisher = GeneratedColumn<String>(
    'publisher',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _taskJsonMeta = const VerificationMeta(
    'taskJson',
  );
  @override
  late final GeneratedColumn<String> taskJson = GeneratedColumn<String>(
    'task_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    externalModelId,
    displayName,
    parentModelId,
    suffix,
    publisher,
    sourceType,
    metadataJson,
    taskJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'models';
  @override
  VerificationContext validateIntegrity(
    Insertable<Model> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('external_model_id')) {
      context.handle(
        _externalModelIdMeta,
        externalModelId.isAcceptableOrUnknown(
          data['external_model_id']!,
          _externalModelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_externalModelIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('parent_model_id')) {
      context.handle(
        _parentModelIdMeta,
        parentModelId.isAcceptableOrUnknown(
          data['parent_model_id']!,
          _parentModelIdMeta,
        ),
      );
    }
    if (data.containsKey('suffix')) {
      context.handle(
        _suffixMeta,
        suffix.isAcceptableOrUnknown(data['suffix']!, _suffixMeta),
      );
    }
    if (data.containsKey('publisher')) {
      context.handle(
        _publisherMeta,
        publisher.isAcceptableOrUnknown(data['publisher']!, _publisherMeta),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('task_json')) {
      context.handle(
        _taskJsonMeta,
        taskJson.isAcceptableOrUnknown(data['task_json']!, _taskJsonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Model map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Model(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      externalModelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_model_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      parentModelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_model_id'],
      ),
      suffix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suffix'],
      ),
      publisher: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}publisher'],
      ),
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
      taskJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ModelsTable createAlias(String alias) {
    return $ModelsTable(attachedDatabase, alias);
  }
}

class Model extends DataClass implements Insertable<Model> {
  final String id;
  final String sourceId;
  final String externalModelId;
  final String displayName;
  final String? parentModelId;
  final String? suffix;
  final String? publisher;
  final String sourceType;
  final String metadataJson;
  final String taskJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Model({
    required this.id,
    required this.sourceId,
    required this.externalModelId,
    required this.displayName,
    this.parentModelId,
    this.suffix,
    this.publisher,
    required this.sourceType,
    required this.metadataJson,
    required this.taskJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['external_model_id'] = Variable<String>(externalModelId);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || parentModelId != null) {
      map['parent_model_id'] = Variable<String>(parentModelId);
    }
    if (!nullToAbsent || suffix != null) {
      map['suffix'] = Variable<String>(suffix);
    }
    if (!nullToAbsent || publisher != null) {
      map['publisher'] = Variable<String>(publisher);
    }
    map['source_type'] = Variable<String>(sourceType);
    map['metadata_json'] = Variable<String>(metadataJson);
    map['task_json'] = Variable<String>(taskJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ModelsCompanion toCompanion(bool nullToAbsent) {
    return ModelsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      externalModelId: Value(externalModelId),
      displayName: Value(displayName),
      parentModelId: parentModelId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentModelId),
      suffix: suffix == null && nullToAbsent
          ? const Value.absent()
          : Value(suffix),
      publisher: publisher == null && nullToAbsent
          ? const Value.absent()
          : Value(publisher),
      sourceType: Value(sourceType),
      metadataJson: Value(metadataJson),
      taskJson: Value(taskJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Model.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Model(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      externalModelId: serializer.fromJson<String>(json['externalModelId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      parentModelId: serializer.fromJson<String?>(json['parentModelId']),
      suffix: serializer.fromJson<String?>(json['suffix']),
      publisher: serializer.fromJson<String?>(json['publisher']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
      taskJson: serializer.fromJson<String>(json['taskJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'externalModelId': serializer.toJson<String>(externalModelId),
      'displayName': serializer.toJson<String>(displayName),
      'parentModelId': serializer.toJson<String?>(parentModelId),
      'suffix': serializer.toJson<String?>(suffix),
      'publisher': serializer.toJson<String?>(publisher),
      'sourceType': serializer.toJson<String>(sourceType),
      'metadataJson': serializer.toJson<String>(metadataJson),
      'taskJson': serializer.toJson<String>(taskJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Model copyWith({
    String? id,
    String? sourceId,
    String? externalModelId,
    String? displayName,
    Value<String?> parentModelId = const Value.absent(),
    Value<String?> suffix = const Value.absent(),
    Value<String?> publisher = const Value.absent(),
    String? sourceType,
    String? metadataJson,
    String? taskJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Model(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    externalModelId: externalModelId ?? this.externalModelId,
    displayName: displayName ?? this.displayName,
    parentModelId: parentModelId.present
        ? parentModelId.value
        : this.parentModelId,
    suffix: suffix.present ? suffix.value : this.suffix,
    publisher: publisher.present ? publisher.value : this.publisher,
    sourceType: sourceType ?? this.sourceType,
    metadataJson: metadataJson ?? this.metadataJson,
    taskJson: taskJson ?? this.taskJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Model copyWithCompanion(ModelsCompanion data) {
    return Model(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      externalModelId: data.externalModelId.present
          ? data.externalModelId.value
          : this.externalModelId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      parentModelId: data.parentModelId.present
          ? data.parentModelId.value
          : this.parentModelId,
      suffix: data.suffix.present ? data.suffix.value : this.suffix,
      publisher: data.publisher.present ? data.publisher.value : this.publisher,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      taskJson: data.taskJson.present ? data.taskJson.value : this.taskJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Model(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('externalModelId: $externalModelId, ')
          ..write('displayName: $displayName, ')
          ..write('parentModelId: $parentModelId, ')
          ..write('suffix: $suffix, ')
          ..write('publisher: $publisher, ')
          ..write('sourceType: $sourceType, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('taskJson: $taskJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    externalModelId,
    displayName,
    parentModelId,
    suffix,
    publisher,
    sourceType,
    metadataJson,
    taskJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Model &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.externalModelId == this.externalModelId &&
          other.displayName == this.displayName &&
          other.parentModelId == this.parentModelId &&
          other.suffix == this.suffix &&
          other.publisher == this.publisher &&
          other.sourceType == this.sourceType &&
          other.metadataJson == this.metadataJson &&
          other.taskJson == this.taskJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ModelsCompanion extends UpdateCompanion<Model> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> externalModelId;
  final Value<String> displayName;
  final Value<String?> parentModelId;
  final Value<String?> suffix;
  final Value<String?> publisher;
  final Value<String> sourceType;
  final Value<String> metadataJson;
  final Value<String> taskJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ModelsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.externalModelId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.parentModelId = const Value.absent(),
    this.suffix = const Value.absent(),
    this.publisher = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.taskJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelsCompanion.insert({
    required String id,
    required String sourceId,
    required String externalModelId,
    required String displayName,
    this.parentModelId = const Value.absent(),
    this.suffix = const Value.absent(),
    this.publisher = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.taskJson = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       externalModelId = Value(externalModelId),
       displayName = Value(displayName),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Model> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? externalModelId,
    Expression<String>? displayName,
    Expression<String>? parentModelId,
    Expression<String>? suffix,
    Expression<String>? publisher,
    Expression<String>? sourceType,
    Expression<String>? metadataJson,
    Expression<String>? taskJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (externalModelId != null) 'external_model_id': externalModelId,
      if (displayName != null) 'display_name': displayName,
      if (parentModelId != null) 'parent_model_id': parentModelId,
      if (suffix != null) 'suffix': suffix,
      if (publisher != null) 'publisher': publisher,
      if (sourceType != null) 'source_type': sourceType,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (taskJson != null) 'task_json': taskJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String>? externalModelId,
    Value<String>? displayName,
    Value<String?>? parentModelId,
    Value<String?>? suffix,
    Value<String?>? publisher,
    Value<String>? sourceType,
    Value<String>? metadataJson,
    Value<String>? taskJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ModelsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      externalModelId: externalModelId ?? this.externalModelId,
      displayName: displayName ?? this.displayName,
      parentModelId: parentModelId ?? this.parentModelId,
      suffix: suffix ?? this.suffix,
      publisher: publisher ?? this.publisher,
      sourceType: sourceType ?? this.sourceType,
      metadataJson: metadataJson ?? this.metadataJson,
      taskJson: taskJson ?? this.taskJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (externalModelId.present) {
      map['external_model_id'] = Variable<String>(externalModelId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (parentModelId.present) {
      map['parent_model_id'] = Variable<String>(parentModelId.value);
    }
    if (suffix.present) {
      map['suffix'] = Variable<String>(suffix.value);
    }
    if (publisher.present) {
      map['publisher'] = Variable<String>(publisher.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (taskJson.present) {
      map['task_json'] = Variable<String>(taskJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('externalModelId: $externalModelId, ')
          ..write('displayName: $displayName, ')
          ..write('parentModelId: $parentModelId, ')
          ..write('suffix: $suffix, ')
          ..write('publisher: $publisher, ')
          ..write('sourceType: $sourceType, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('taskJson: $taskJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelArtifactsTable extends ModelArtifacts
    with TableInfo<$ModelArtifactsTable, ModelArtifact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelArtifactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalPathMeta = const VerificationMeta(
    'externalPath',
  );
  @override
  late final GeneratedColumn<String> externalPath = GeneratedColumn<String>(
    'external_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('other'),
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('repository'),
  );
  static const VerificationMeta _repositoryPathMeta = const VerificationMeta(
    'repositoryPath',
  );
  @override
  late final GeneratedColumn<String> repositoryPath = GeneratedColumn<String>(
    'repository_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceSourcePathMeta = const VerificationMeta(
    'deviceSourcePath',
  );
  @override
  late final GeneratedColumn<String> deviceSourcePath = GeneratedColumn<String>(
    'device_source_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetPathMeta = const VerificationMeta(
    'targetPath',
  );
  @override
  late final GeneratedColumn<String> targetPath = GeneratedColumn<String>(
    'target_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isLfsMeta = const VerificationMeta('isLfs');
  @override
  late final GeneratedColumn<bool> isLfs = GeneratedColumn<bool>(
    'is_lfs',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_lfs" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _oidMeta = const VerificationMeta('oid');
  @override
  late final GeneratedColumn<String> oid = GeneratedColumn<String>(
    'oid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<String> revision = GeneratedColumn<String>(
    'revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    modelId,
    externalPath,
    fileName,
    kind,
    sourceType,
    repositoryPath,
    deviceSourcePath,
    targetPath,
    format,
    sizeBytes,
    isLfs,
    oid,
    revision,
    enabled,
    position,
    metadataJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_artifacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelArtifact> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('external_path')) {
      context.handle(
        _externalPathMeta,
        externalPath.isAcceptableOrUnknown(
          data['external_path']!,
          _externalPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_externalPathMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    }
    if (data.containsKey('repository_path')) {
      context.handle(
        _repositoryPathMeta,
        repositoryPath.isAcceptableOrUnknown(
          data['repository_path']!,
          _repositoryPathMeta,
        ),
      );
    }
    if (data.containsKey('device_source_path')) {
      context.handle(
        _deviceSourcePathMeta,
        deviceSourcePath.isAcceptableOrUnknown(
          data['device_source_path']!,
          _deviceSourcePathMeta,
        ),
      );
    }
    if (data.containsKey('target_path')) {
      context.handle(
        _targetPathMeta,
        targetPath.isAcceptableOrUnknown(data['target_path']!, _targetPathMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('is_lfs')) {
      context.handle(
        _isLfsMeta,
        isLfs.isAcceptableOrUnknown(data['is_lfs']!, _isLfsMeta),
      );
    }
    if (data.containsKey('oid')) {
      context.handle(
        _oidMeta,
        oid.isAcceptableOrUnknown(data['oid']!, _oidMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModelArtifact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelArtifact(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      externalPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_path'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      repositoryPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repository_path'],
      ),
      deviceSourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_source_path'],
      ),
      targetPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_path'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      isLfs: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_lfs'],
      )!,
      oid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}oid'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ModelArtifactsTable createAlias(String alias) {
    return $ModelArtifactsTable(attachedDatabase, alias);
  }
}

class ModelArtifact extends DataClass implements Insertable<ModelArtifact> {
  final String id;
  final String modelId;
  final String externalPath;
  final String fileName;
  final String kind;
  final String sourceType;
  final String? repositoryPath;
  final String? deviceSourcePath;
  final String? targetPath;
  final String? format;
  final int? sizeBytes;
  final bool isLfs;
  final String? oid;
  final String? revision;
  final bool enabled;
  final int position;
  final String metadataJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ModelArtifact({
    required this.id,
    required this.modelId,
    required this.externalPath,
    required this.fileName,
    required this.kind,
    required this.sourceType,
    this.repositoryPath,
    this.deviceSourcePath,
    this.targetPath,
    this.format,
    this.sizeBytes,
    required this.isLfs,
    this.oid,
    this.revision,
    required this.enabled,
    required this.position,
    required this.metadataJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['model_id'] = Variable<String>(modelId);
    map['external_path'] = Variable<String>(externalPath);
    map['file_name'] = Variable<String>(fileName);
    map['kind'] = Variable<String>(kind);
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || repositoryPath != null) {
      map['repository_path'] = Variable<String>(repositoryPath);
    }
    if (!nullToAbsent || deviceSourcePath != null) {
      map['device_source_path'] = Variable<String>(deviceSourcePath);
    }
    if (!nullToAbsent || targetPath != null) {
      map['target_path'] = Variable<String>(targetPath);
    }
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    map['is_lfs'] = Variable<bool>(isLfs);
    if (!nullToAbsent || oid != null) {
      map['oid'] = Variable<String>(oid);
    }
    if (!nullToAbsent || revision != null) {
      map['revision'] = Variable<String>(revision);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['position'] = Variable<int>(position);
    map['metadata_json'] = Variable<String>(metadataJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ModelArtifactsCompanion toCompanion(bool nullToAbsent) {
    return ModelArtifactsCompanion(
      id: Value(id),
      modelId: Value(modelId),
      externalPath: Value(externalPath),
      fileName: Value(fileName),
      kind: Value(kind),
      sourceType: Value(sourceType),
      repositoryPath: repositoryPath == null && nullToAbsent
          ? const Value.absent()
          : Value(repositoryPath),
      deviceSourcePath: deviceSourcePath == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceSourcePath),
      targetPath: targetPath == null && nullToAbsent
          ? const Value.absent()
          : Value(targetPath),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      isLfs: Value(isLfs),
      oid: oid == null && nullToAbsent ? const Value.absent() : Value(oid),
      revision: revision == null && nullToAbsent
          ? const Value.absent()
          : Value(revision),
      enabled: Value(enabled),
      position: Value(position),
      metadataJson: Value(metadataJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ModelArtifact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelArtifact(
      id: serializer.fromJson<String>(json['id']),
      modelId: serializer.fromJson<String>(json['modelId']),
      externalPath: serializer.fromJson<String>(json['externalPath']),
      fileName: serializer.fromJson<String>(json['fileName']),
      kind: serializer.fromJson<String>(json['kind']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      repositoryPath: serializer.fromJson<String?>(json['repositoryPath']),
      deviceSourcePath: serializer.fromJson<String?>(json['deviceSourcePath']),
      targetPath: serializer.fromJson<String?>(json['targetPath']),
      format: serializer.fromJson<String?>(json['format']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      isLfs: serializer.fromJson<bool>(json['isLfs']),
      oid: serializer.fromJson<String?>(json['oid']),
      revision: serializer.fromJson<String?>(json['revision']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      position: serializer.fromJson<int>(json['position']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'modelId': serializer.toJson<String>(modelId),
      'externalPath': serializer.toJson<String>(externalPath),
      'fileName': serializer.toJson<String>(fileName),
      'kind': serializer.toJson<String>(kind),
      'sourceType': serializer.toJson<String>(sourceType),
      'repositoryPath': serializer.toJson<String?>(repositoryPath),
      'deviceSourcePath': serializer.toJson<String?>(deviceSourcePath),
      'targetPath': serializer.toJson<String?>(targetPath),
      'format': serializer.toJson<String?>(format),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'isLfs': serializer.toJson<bool>(isLfs),
      'oid': serializer.toJson<String?>(oid),
      'revision': serializer.toJson<String?>(revision),
      'enabled': serializer.toJson<bool>(enabled),
      'position': serializer.toJson<int>(position),
      'metadataJson': serializer.toJson<String>(metadataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ModelArtifact copyWith({
    String? id,
    String? modelId,
    String? externalPath,
    String? fileName,
    String? kind,
    String? sourceType,
    Value<String?> repositoryPath = const Value.absent(),
    Value<String?> deviceSourcePath = const Value.absent(),
    Value<String?> targetPath = const Value.absent(),
    Value<String?> format = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    bool? isLfs,
    Value<String?> oid = const Value.absent(),
    Value<String?> revision = const Value.absent(),
    bool? enabled,
    int? position,
    String? metadataJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ModelArtifact(
    id: id ?? this.id,
    modelId: modelId ?? this.modelId,
    externalPath: externalPath ?? this.externalPath,
    fileName: fileName ?? this.fileName,
    kind: kind ?? this.kind,
    sourceType: sourceType ?? this.sourceType,
    repositoryPath: repositoryPath.present
        ? repositoryPath.value
        : this.repositoryPath,
    deviceSourcePath: deviceSourcePath.present
        ? deviceSourcePath.value
        : this.deviceSourcePath,
    targetPath: targetPath.present ? targetPath.value : this.targetPath,
    format: format.present ? format.value : this.format,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    isLfs: isLfs ?? this.isLfs,
    oid: oid.present ? oid.value : this.oid,
    revision: revision.present ? revision.value : this.revision,
    enabled: enabled ?? this.enabled,
    position: position ?? this.position,
    metadataJson: metadataJson ?? this.metadataJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ModelArtifact copyWithCompanion(ModelArtifactsCompanion data) {
    return ModelArtifact(
      id: data.id.present ? data.id.value : this.id,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      externalPath: data.externalPath.present
          ? data.externalPath.value
          : this.externalPath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      kind: data.kind.present ? data.kind.value : this.kind,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      repositoryPath: data.repositoryPath.present
          ? data.repositoryPath.value
          : this.repositoryPath,
      deviceSourcePath: data.deviceSourcePath.present
          ? data.deviceSourcePath.value
          : this.deviceSourcePath,
      targetPath: data.targetPath.present
          ? data.targetPath.value
          : this.targetPath,
      format: data.format.present ? data.format.value : this.format,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      isLfs: data.isLfs.present ? data.isLfs.value : this.isLfs,
      oid: data.oid.present ? data.oid.value : this.oid,
      revision: data.revision.present ? data.revision.value : this.revision,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      position: data.position.present ? data.position.value : this.position,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelArtifact(')
          ..write('id: $id, ')
          ..write('modelId: $modelId, ')
          ..write('externalPath: $externalPath, ')
          ..write('fileName: $fileName, ')
          ..write('kind: $kind, ')
          ..write('sourceType: $sourceType, ')
          ..write('repositoryPath: $repositoryPath, ')
          ..write('deviceSourcePath: $deviceSourcePath, ')
          ..write('targetPath: $targetPath, ')
          ..write('format: $format, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('isLfs: $isLfs, ')
          ..write('oid: $oid, ')
          ..write('revision: $revision, ')
          ..write('enabled: $enabled, ')
          ..write('position: $position, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    modelId,
    externalPath,
    fileName,
    kind,
    sourceType,
    repositoryPath,
    deviceSourcePath,
    targetPath,
    format,
    sizeBytes,
    isLfs,
    oid,
    revision,
    enabled,
    position,
    metadataJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelArtifact &&
          other.id == this.id &&
          other.modelId == this.modelId &&
          other.externalPath == this.externalPath &&
          other.fileName == this.fileName &&
          other.kind == this.kind &&
          other.sourceType == this.sourceType &&
          other.repositoryPath == this.repositoryPath &&
          other.deviceSourcePath == this.deviceSourcePath &&
          other.targetPath == this.targetPath &&
          other.format == this.format &&
          other.sizeBytes == this.sizeBytes &&
          other.isLfs == this.isLfs &&
          other.oid == this.oid &&
          other.revision == this.revision &&
          other.enabled == this.enabled &&
          other.position == this.position &&
          other.metadataJson == this.metadataJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ModelArtifactsCompanion extends UpdateCompanion<ModelArtifact> {
  final Value<String> id;
  final Value<String> modelId;
  final Value<String> externalPath;
  final Value<String> fileName;
  final Value<String> kind;
  final Value<String> sourceType;
  final Value<String?> repositoryPath;
  final Value<String?> deviceSourcePath;
  final Value<String?> targetPath;
  final Value<String?> format;
  final Value<int?> sizeBytes;
  final Value<bool> isLfs;
  final Value<String?> oid;
  final Value<String?> revision;
  final Value<bool> enabled;
  final Value<int> position;
  final Value<String> metadataJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ModelArtifactsCompanion({
    this.id = const Value.absent(),
    this.modelId = const Value.absent(),
    this.externalPath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.kind = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.repositoryPath = const Value.absent(),
    this.deviceSourcePath = const Value.absent(),
    this.targetPath = const Value.absent(),
    this.format = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.isLfs = const Value.absent(),
    this.oid = const Value.absent(),
    this.revision = const Value.absent(),
    this.enabled = const Value.absent(),
    this.position = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelArtifactsCompanion.insert({
    required String id,
    required String modelId,
    required String externalPath,
    required String fileName,
    this.kind = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.repositoryPath = const Value.absent(),
    this.deviceSourcePath = const Value.absent(),
    this.targetPath = const Value.absent(),
    this.format = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.isLfs = const Value.absent(),
    this.oid = const Value.absent(),
    this.revision = const Value.absent(),
    this.enabled = const Value.absent(),
    this.position = const Value.absent(),
    this.metadataJson = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       modelId = Value(modelId),
       externalPath = Value(externalPath),
       fileName = Value(fileName),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ModelArtifact> custom({
    Expression<String>? id,
    Expression<String>? modelId,
    Expression<String>? externalPath,
    Expression<String>? fileName,
    Expression<String>? kind,
    Expression<String>? sourceType,
    Expression<String>? repositoryPath,
    Expression<String>? deviceSourcePath,
    Expression<String>? targetPath,
    Expression<String>? format,
    Expression<int>? sizeBytes,
    Expression<bool>? isLfs,
    Expression<String>? oid,
    Expression<String>? revision,
    Expression<bool>? enabled,
    Expression<int>? position,
    Expression<String>? metadataJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (modelId != null) 'model_id': modelId,
      if (externalPath != null) 'external_path': externalPath,
      if (fileName != null) 'file_name': fileName,
      if (kind != null) 'kind': kind,
      if (sourceType != null) 'source_type': sourceType,
      if (repositoryPath != null) 'repository_path': repositoryPath,
      if (deviceSourcePath != null) 'device_source_path': deviceSourcePath,
      if (targetPath != null) 'target_path': targetPath,
      if (format != null) 'format': format,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (isLfs != null) 'is_lfs': isLfs,
      if (oid != null) 'oid': oid,
      if (revision != null) 'revision': revision,
      if (enabled != null) 'enabled': enabled,
      if (position != null) 'position': position,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelArtifactsCompanion copyWith({
    Value<String>? id,
    Value<String>? modelId,
    Value<String>? externalPath,
    Value<String>? fileName,
    Value<String>? kind,
    Value<String>? sourceType,
    Value<String?>? repositoryPath,
    Value<String?>? deviceSourcePath,
    Value<String?>? targetPath,
    Value<String?>? format,
    Value<int?>? sizeBytes,
    Value<bool>? isLfs,
    Value<String?>? oid,
    Value<String?>? revision,
    Value<bool>? enabled,
    Value<int>? position,
    Value<String>? metadataJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ModelArtifactsCompanion(
      id: id ?? this.id,
      modelId: modelId ?? this.modelId,
      externalPath: externalPath ?? this.externalPath,
      fileName: fileName ?? this.fileName,
      kind: kind ?? this.kind,
      sourceType: sourceType ?? this.sourceType,
      repositoryPath: repositoryPath ?? this.repositoryPath,
      deviceSourcePath: deviceSourcePath ?? this.deviceSourcePath,
      targetPath: targetPath ?? this.targetPath,
      format: format ?? this.format,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      isLfs: isLfs ?? this.isLfs,
      oid: oid ?? this.oid,
      revision: revision ?? this.revision,
      enabled: enabled ?? this.enabled,
      position: position ?? this.position,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (externalPath.present) {
      map['external_path'] = Variable<String>(externalPath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (repositoryPath.present) {
      map['repository_path'] = Variable<String>(repositoryPath.value);
    }
    if (deviceSourcePath.present) {
      map['device_source_path'] = Variable<String>(deviceSourcePath.value);
    }
    if (targetPath.present) {
      map['target_path'] = Variable<String>(targetPath.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (isLfs.present) {
      map['is_lfs'] = Variable<bool>(isLfs.value);
    }
    if (oid.present) {
      map['oid'] = Variable<String>(oid.value);
    }
    if (revision.present) {
      map['revision'] = Variable<String>(revision.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelArtifactsCompanion(')
          ..write('id: $id, ')
          ..write('modelId: $modelId, ')
          ..write('externalPath: $externalPath, ')
          ..write('fileName: $fileName, ')
          ..write('kind: $kind, ')
          ..write('sourceType: $sourceType, ')
          ..write('repositoryPath: $repositoryPath, ')
          ..write('deviceSourcePath: $deviceSourcePath, ')
          ..write('targetPath: $targetPath, ')
          ..write('format: $format, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('isLfs: $isLfs, ')
          ..write('oid: $oid, ')
          ..write('revision: $revision, ')
          ..write('enabled: $enabled, ')
          ..write('position: $position, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelSettingsTable extends ModelSettings
    with TableInfo<$ModelSettingsTable, ModelSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _optionsJsonMeta = const VerificationMeta(
    'optionsJson',
  );
  @override
  late final GeneratedColumn<String> optionsJson = GeneratedColumn<String>(
    'options_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _overridesJsonMeta = const VerificationMeta(
    'overridesJson',
  );
  @override
  late final GeneratedColumn<String> overridesJson = GeneratedColumn<String>(
    'overrides_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _maxThinkingTokensMeta = const VerificationMeta(
    'maxThinkingTokens',
  );
  @override
  late final GeneratedColumn<int> maxThinkingTokens = GeneratedColumn<int>(
    'max_thinking_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thinkingConfigJsonMeta =
      const VerificationMeta('thinkingConfigJson');
  @override
  late final GeneratedColumn<String> thinkingConfigJson =
      GeneratedColumn<String>(
        'thinking_config_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('{}'),
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    modelId,
    version,
    optionsJson,
    overridesJson,
    maxThinkingTokens,
    thinkingConfigJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('options_json')) {
      context.handle(
        _optionsJsonMeta,
        optionsJson.isAcceptableOrUnknown(
          data['options_json']!,
          _optionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('overrides_json')) {
      context.handle(
        _overridesJsonMeta,
        overridesJson.isAcceptableOrUnknown(
          data['overrides_json']!,
          _overridesJsonMeta,
        ),
      );
    }
    if (data.containsKey('max_thinking_tokens')) {
      context.handle(
        _maxThinkingTokensMeta,
        maxThinkingTokens.isAcceptableOrUnknown(
          data['max_thinking_tokens']!,
          _maxThinkingTokensMeta,
        ),
      );
    }
    if (data.containsKey('thinking_config_json')) {
      context.handle(
        _thinkingConfigJsonMeta,
        thinkingConfigJson.isAcceptableOrUnknown(
          data['thinking_config_json']!,
          _thinkingConfigJsonMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModelSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      optionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}options_json'],
      )!,
      overridesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overrides_json'],
      )!,
      maxThinkingTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_thinking_tokens'],
      ),
      thinkingConfigJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thinking_config_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ModelSettingsTable createAlias(String alias) {
    return $ModelSettingsTable(attachedDatabase, alias);
  }
}

class ModelSetting extends DataClass implements Insertable<ModelSetting> {
  final String id;
  final String modelId;
  final int version;
  final String optionsJson;
  final String overridesJson;
  final int? maxThinkingTokens;
  final String thinkingConfigJson;
  final DateTime updatedAt;
  const ModelSetting({
    required this.id,
    required this.modelId,
    required this.version,
    required this.optionsJson,
    required this.overridesJson,
    this.maxThinkingTokens,
    required this.thinkingConfigJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['model_id'] = Variable<String>(modelId);
    map['version'] = Variable<int>(version);
    map['options_json'] = Variable<String>(optionsJson);
    map['overrides_json'] = Variable<String>(overridesJson);
    if (!nullToAbsent || maxThinkingTokens != null) {
      map['max_thinking_tokens'] = Variable<int>(maxThinkingTokens);
    }
    map['thinking_config_json'] = Variable<String>(thinkingConfigJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ModelSettingsCompanion toCompanion(bool nullToAbsent) {
    return ModelSettingsCompanion(
      id: Value(id),
      modelId: Value(modelId),
      version: Value(version),
      optionsJson: Value(optionsJson),
      overridesJson: Value(overridesJson),
      maxThinkingTokens: maxThinkingTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(maxThinkingTokens),
      thinkingConfigJson: Value(thinkingConfigJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory ModelSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelSetting(
      id: serializer.fromJson<String>(json['id']),
      modelId: serializer.fromJson<String>(json['modelId']),
      version: serializer.fromJson<int>(json['version']),
      optionsJson: serializer.fromJson<String>(json['optionsJson']),
      overridesJson: serializer.fromJson<String>(json['overridesJson']),
      maxThinkingTokens: serializer.fromJson<int?>(json['maxThinkingTokens']),
      thinkingConfigJson: serializer.fromJson<String>(
        json['thinkingConfigJson'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'modelId': serializer.toJson<String>(modelId),
      'version': serializer.toJson<int>(version),
      'optionsJson': serializer.toJson<String>(optionsJson),
      'overridesJson': serializer.toJson<String>(overridesJson),
      'maxThinkingTokens': serializer.toJson<int?>(maxThinkingTokens),
      'thinkingConfigJson': serializer.toJson<String>(thinkingConfigJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ModelSetting copyWith({
    String? id,
    String? modelId,
    int? version,
    String? optionsJson,
    String? overridesJson,
    Value<int?> maxThinkingTokens = const Value.absent(),
    String? thinkingConfigJson,
    DateTime? updatedAt,
  }) => ModelSetting(
    id: id ?? this.id,
    modelId: modelId ?? this.modelId,
    version: version ?? this.version,
    optionsJson: optionsJson ?? this.optionsJson,
    overridesJson: overridesJson ?? this.overridesJson,
    maxThinkingTokens: maxThinkingTokens.present
        ? maxThinkingTokens.value
        : this.maxThinkingTokens,
    thinkingConfigJson: thinkingConfigJson ?? this.thinkingConfigJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ModelSetting copyWithCompanion(ModelSettingsCompanion data) {
    return ModelSetting(
      id: data.id.present ? data.id.value : this.id,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      version: data.version.present ? data.version.value : this.version,
      optionsJson: data.optionsJson.present
          ? data.optionsJson.value
          : this.optionsJson,
      overridesJson: data.overridesJson.present
          ? data.overridesJson.value
          : this.overridesJson,
      maxThinkingTokens: data.maxThinkingTokens.present
          ? data.maxThinkingTokens.value
          : this.maxThinkingTokens,
      thinkingConfigJson: data.thinkingConfigJson.present
          ? data.thinkingConfigJson.value
          : this.thinkingConfigJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelSetting(')
          ..write('id: $id, ')
          ..write('modelId: $modelId, ')
          ..write('version: $version, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('overridesJson: $overridesJson, ')
          ..write('maxThinkingTokens: $maxThinkingTokens, ')
          ..write('thinkingConfigJson: $thinkingConfigJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    modelId,
    version,
    optionsJson,
    overridesJson,
    maxThinkingTokens,
    thinkingConfigJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelSetting &&
          other.id == this.id &&
          other.modelId == this.modelId &&
          other.version == this.version &&
          other.optionsJson == this.optionsJson &&
          other.overridesJson == this.overridesJson &&
          other.maxThinkingTokens == this.maxThinkingTokens &&
          other.thinkingConfigJson == this.thinkingConfigJson &&
          other.updatedAt == this.updatedAt);
}

class ModelSettingsCompanion extends UpdateCompanion<ModelSetting> {
  final Value<String> id;
  final Value<String> modelId;
  final Value<int> version;
  final Value<String> optionsJson;
  final Value<String> overridesJson;
  final Value<int?> maxThinkingTokens;
  final Value<String> thinkingConfigJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ModelSettingsCompanion({
    this.id = const Value.absent(),
    this.modelId = const Value.absent(),
    this.version = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.overridesJson = const Value.absent(),
    this.maxThinkingTokens = const Value.absent(),
    this.thinkingConfigJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelSettingsCompanion.insert({
    required String id,
    required String modelId,
    this.version = const Value.absent(),
    this.optionsJson = const Value.absent(),
    this.overridesJson = const Value.absent(),
    this.maxThinkingTokens = const Value.absent(),
    this.thinkingConfigJson = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       modelId = Value(modelId),
       updatedAt = Value(updatedAt);
  static Insertable<ModelSetting> custom({
    Expression<String>? id,
    Expression<String>? modelId,
    Expression<int>? version,
    Expression<String>? optionsJson,
    Expression<String>? overridesJson,
    Expression<int>? maxThinkingTokens,
    Expression<String>? thinkingConfigJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (modelId != null) 'model_id': modelId,
      if (version != null) 'version': version,
      if (optionsJson != null) 'options_json': optionsJson,
      if (overridesJson != null) 'overrides_json': overridesJson,
      if (maxThinkingTokens != null) 'max_thinking_tokens': maxThinkingTokens,
      if (thinkingConfigJson != null)
        'thinking_config_json': thinkingConfigJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelSettingsCompanion copyWith({
    Value<String>? id,
    Value<String>? modelId,
    Value<int>? version,
    Value<String>? optionsJson,
    Value<String>? overridesJson,
    Value<int?>? maxThinkingTokens,
    Value<String>? thinkingConfigJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ModelSettingsCompanion(
      id: id ?? this.id,
      modelId: modelId ?? this.modelId,
      version: version ?? this.version,
      optionsJson: optionsJson ?? this.optionsJson,
      overridesJson: overridesJson ?? this.overridesJson,
      maxThinkingTokens: maxThinkingTokens ?? this.maxThinkingTokens,
      thinkingConfigJson: thinkingConfigJson ?? this.thinkingConfigJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (optionsJson.present) {
      map['options_json'] = Variable<String>(optionsJson.value);
    }
    if (overridesJson.present) {
      map['overrides_json'] = Variable<String>(overridesJson.value);
    }
    if (maxThinkingTokens.present) {
      map['max_thinking_tokens'] = Variable<int>(maxThinkingTokens.value);
    }
    if (thinkingConfigJson.present) {
      map['thinking_config_json'] = Variable<String>(thinkingConfigJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelSettingsCompanion(')
          ..write('id: $id, ')
          ..write('modelId: $modelId, ')
          ..write('version: $version, ')
          ..write('optionsJson: $optionsJson, ')
          ..write('overridesJson: $overridesJson, ')
          ..write('maxThinkingTokens: $maxThinkingTokens, ')
          ..write('thinkingConfigJson: $thinkingConfigJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActiveModelAssignmentsTable extends ActiveModelAssignments
    with TableInfo<$ActiveModelAssignmentsTable, ActiveModelAssignmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveModelAssignmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _assignmentTypeMeta = const VerificationMeta(
    'assignmentType',
  );
  @override
  late final GeneratedColumn<String> assignmentType = GeneratedColumn<String>(
    'assignment_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('single'),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    modelId,
    taskId,
    priority,
    assignmentType,
    enabled,
    metadataJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_model_assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveModelAssignmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('assignment_type')) {
      context.handle(
        _assignmentTypeMeta,
        assignmentType.isAcceptableOrUnknown(
          data['assignment_type']!,
          _assignmentTypeMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActiveModelAssignmentRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveModelAssignmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      assignmentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assignment_type'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ActiveModelAssignmentsTable createAlias(String alias) {
    return $ActiveModelAssignmentsTable(attachedDatabase, alias);
  }
}

class ActiveModelAssignmentRow extends DataClass
    implements Insertable<ActiveModelAssignmentRow> {
  final String id;
  final String modelId;
  final String taskId;
  final int priority;
  final String assignmentType;
  final bool enabled;
  final String metadataJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ActiveModelAssignmentRow({
    required this.id,
    required this.modelId,
    required this.taskId,
    required this.priority,
    required this.assignmentType,
    required this.enabled,
    required this.metadataJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['model_id'] = Variable<String>(modelId);
    map['task_id'] = Variable<String>(taskId);
    map['priority'] = Variable<int>(priority);
    map['assignment_type'] = Variable<String>(assignmentType);
    map['enabled'] = Variable<bool>(enabled);
    map['metadata_json'] = Variable<String>(metadataJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ActiveModelAssignmentsCompanion toCompanion(bool nullToAbsent) {
    return ActiveModelAssignmentsCompanion(
      id: Value(id),
      modelId: Value(modelId),
      taskId: Value(taskId),
      priority: Value(priority),
      assignmentType: Value(assignmentType),
      enabled: Value(enabled),
      metadataJson: Value(metadataJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ActiveModelAssignmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveModelAssignmentRow(
      id: serializer.fromJson<String>(json['id']),
      modelId: serializer.fromJson<String>(json['modelId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      priority: serializer.fromJson<int>(json['priority']),
      assignmentType: serializer.fromJson<String>(json['assignmentType']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'modelId': serializer.toJson<String>(modelId),
      'taskId': serializer.toJson<String>(taskId),
      'priority': serializer.toJson<int>(priority),
      'assignmentType': serializer.toJson<String>(assignmentType),
      'enabled': serializer.toJson<bool>(enabled),
      'metadataJson': serializer.toJson<String>(metadataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ActiveModelAssignmentRow copyWith({
    String? id,
    String? modelId,
    String? taskId,
    int? priority,
    String? assignmentType,
    bool? enabled,
    String? metadataJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ActiveModelAssignmentRow(
    id: id ?? this.id,
    modelId: modelId ?? this.modelId,
    taskId: taskId ?? this.taskId,
    priority: priority ?? this.priority,
    assignmentType: assignmentType ?? this.assignmentType,
    enabled: enabled ?? this.enabled,
    metadataJson: metadataJson ?? this.metadataJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ActiveModelAssignmentRow copyWithCompanion(
    ActiveModelAssignmentsCompanion data,
  ) {
    return ActiveModelAssignmentRow(
      id: data.id.present ? data.id.value : this.id,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      priority: data.priority.present ? data.priority.value : this.priority,
      assignmentType: data.assignmentType.present
          ? data.assignmentType.value
          : this.assignmentType,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveModelAssignmentRow(')
          ..write('id: $id, ')
          ..write('modelId: $modelId, ')
          ..write('taskId: $taskId, ')
          ..write('priority: $priority, ')
          ..write('assignmentType: $assignmentType, ')
          ..write('enabled: $enabled, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    modelId,
    taskId,
    priority,
    assignmentType,
    enabled,
    metadataJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveModelAssignmentRow &&
          other.id == this.id &&
          other.modelId == this.modelId &&
          other.taskId == this.taskId &&
          other.priority == this.priority &&
          other.assignmentType == this.assignmentType &&
          other.enabled == this.enabled &&
          other.metadataJson == this.metadataJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ActiveModelAssignmentsCompanion
    extends UpdateCompanion<ActiveModelAssignmentRow> {
  final Value<String> id;
  final Value<String> modelId;
  final Value<String> taskId;
  final Value<int> priority;
  final Value<String> assignmentType;
  final Value<bool> enabled;
  final Value<String> metadataJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ActiveModelAssignmentsCompanion({
    this.id = const Value.absent(),
    this.modelId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.priority = const Value.absent(),
    this.assignmentType = const Value.absent(),
    this.enabled = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActiveModelAssignmentsCompanion.insert({
    required String id,
    required String modelId,
    required String taskId,
    this.priority = const Value.absent(),
    this.assignmentType = const Value.absent(),
    this.enabled = const Value.absent(),
    this.metadataJson = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       modelId = Value(modelId),
       taskId = Value(taskId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ActiveModelAssignmentRow> custom({
    Expression<String>? id,
    Expression<String>? modelId,
    Expression<String>? taskId,
    Expression<int>? priority,
    Expression<String>? assignmentType,
    Expression<bool>? enabled,
    Expression<String>? metadataJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (modelId != null) 'model_id': modelId,
      if (taskId != null) 'task_id': taskId,
      if (priority != null) 'priority': priority,
      if (assignmentType != null) 'assignment_type': assignmentType,
      if (enabled != null) 'enabled': enabled,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActiveModelAssignmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? modelId,
    Value<String>? taskId,
    Value<int>? priority,
    Value<String>? assignmentType,
    Value<bool>? enabled,
    Value<String>? metadataJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ActiveModelAssignmentsCompanion(
      id: id ?? this.id,
      modelId: modelId ?? this.modelId,
      taskId: taskId ?? this.taskId,
      priority: priority ?? this.priority,
      assignmentType: assignmentType ?? this.assignmentType,
      enabled: enabled ?? this.enabled,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (assignmentType.present) {
      map['assignment_type'] = Variable<String>(assignmentType.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveModelAssignmentsCompanion(')
          ..write('id: $id, ')
          ..write('modelId: $modelId, ')
          ..write('taskId: $taskId, ')
          ..write('priority: $priority, ')
          ..write('assignmentType: $assignmentType, ')
          ..write('enabled: $enabled, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChatSessionsTable chatSessions = $ChatSessionsTable(this);
  late final $ChatEntriesTable chatEntries = $ChatEntriesTable(this);
  late final $ActionPreferencesTable actionPreferences =
      $ActionPreferencesTable(this);
  late final $ModelsTable models = $ModelsTable(this);
  late final $ModelArtifactsTable modelArtifacts = $ModelArtifactsTable(this);
  late final $ModelSettingsTable modelSettings = $ModelSettingsTable(this);
  late final $ActiveModelAssignmentsTable activeModelAssignments =
      $ActiveModelAssignmentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    chatSessions,
    chatEntries,
    actionPreferences,
    models,
    modelArtifacts,
    modelSettings,
    activeModelAssignments,
  ];
}

typedef $$ChatSessionsTableCreateCompanionBuilder =
    ChatSessionsCompanion Function({
      required String id,
      required String title,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> pinned,
      Value<bool> archived,
      Value<int> rowid,
    });
typedef $$ChatSessionsTableUpdateCompanionBuilder =
    ChatSessionsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> pinned,
      Value<bool> archived,
      Value<int> rowid,
    });

class $$ChatSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ChatSessionsTable> {
  $$ChatSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatSessionsTable> {
  $$ChatSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatSessionsTable> {
  $$ChatSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);
}

class $$ChatSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatSessionsTable,
          SessionRow,
          $$ChatSessionsTableFilterComposer,
          $$ChatSessionsTableOrderingComposer,
          $$ChatSessionsTableAnnotationComposer,
          $$ChatSessionsTableCreateCompanionBuilder,
          $$ChatSessionsTableUpdateCompanionBuilder,
          (
            SessionRow,
            BaseReferences<_$AppDatabase, $ChatSessionsTable, SessionRow>,
          ),
          SessionRow,
          PrefetchHooks Function()
        > {
  $$ChatSessionsTableTableManager(_$AppDatabase db, $ChatSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatSessionsCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                pinned: pinned,
                archived: archived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> pinned = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatSessionsCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                pinned: pinned,
                archived: archived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatSessionsTable, SessionRow>(table),
                  BaseReferences<_$AppDatabase, $ChatSessionsTable, SessionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatSessionsTable,
      SessionRow,
      $$ChatSessionsTableFilterComposer,
      $$ChatSessionsTableOrderingComposer,
      $$ChatSessionsTableAnnotationComposer,
      $$ChatSessionsTableCreateCompanionBuilder,
      $$ChatSessionsTableUpdateCompanionBuilder,
      (
        SessionRow,
        BaseReferences<_$AppDatabase, $ChatSessionsTable, SessionRow>,
      ),
      SessionRow,
      PrefetchHooks Function()
    >;
typedef $$ChatEntriesTableCreateCompanionBuilder =
    ChatEntriesCompanion Function({
      required String id,
      Value<String> sessionId,
      required String role,
      required String content,
      required DateTime createdAt,
      Value<String> attachmentsJson,
      Value<int> rowid,
    });
typedef $$ChatEntriesTableUpdateCompanionBuilder =
    ChatEntriesCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> role,
      Value<String> content,
      Value<DateTime> createdAt,
      Value<String> attachmentsJson,
      Value<int> rowid,
    });

class $$ChatEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ChatEntriesTable> {
  $$ChatEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatEntriesTable> {
  $$ChatEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatEntriesTable> {
  $$ChatEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get attachmentsJson => $composableBuilder(
    column: $table.attachmentsJson,
    builder: (column) => column,
  );
}

class $$ChatEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatEntriesTable,
          ChatEntry,
          $$ChatEntriesTableFilterComposer,
          $$ChatEntriesTableOrderingComposer,
          $$ChatEntriesTableAnnotationComposer,
          $$ChatEntriesTableCreateCompanionBuilder,
          $$ChatEntriesTableUpdateCompanionBuilder,
          (
            ChatEntry,
            BaseReferences<_$AppDatabase, $ChatEntriesTable, ChatEntry>,
          ),
          ChatEntry,
          PrefetchHooks Function()
        > {
  $$ChatEntriesTableTableManager(_$AppDatabase db, $ChatEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> attachmentsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatEntriesCompanion(
                id: id,
                sessionId: sessionId,
                role: role,
                content: content,
                createdAt: createdAt,
                attachmentsJson: attachmentsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> sessionId = const Value.absent(),
                required String role,
                required String content,
                required DateTime createdAt,
                Value<String> attachmentsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatEntriesCompanion.insert(
                id: id,
                sessionId: sessionId,
                role: role,
                content: content,
                createdAt: createdAt,
                attachmentsJson: attachmentsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatEntriesTable, ChatEntry>(table),
                  BaseReferences<_$AppDatabase, $ChatEntriesTable, ChatEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatEntriesTable,
      ChatEntry,
      $$ChatEntriesTableFilterComposer,
      $$ChatEntriesTableOrderingComposer,
      $$ChatEntriesTableAnnotationComposer,
      $$ChatEntriesTableCreateCompanionBuilder,
      $$ChatEntriesTableUpdateCompanionBuilder,
      (ChatEntry, BaseReferences<_$AppDatabase, $ChatEntriesTable, ChatEntry>),
      ChatEntry,
      PrefetchHooks Function()
    >;
typedef $$ActionPreferencesTableCreateCompanionBuilder =
    ActionPreferencesCompanion Function({
      required String actionKey,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ActionPreferencesTableUpdateCompanionBuilder =
    ActionPreferencesCompanion Function({
      Value<String> actionKey,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ActionPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $ActionPreferencesTable> {
  $$ActionPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get actionKey => $composableBuilder(
    column: $table.actionKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActionPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $ActionPreferencesTable> {
  $$ActionPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get actionKey => $composableBuilder(
    column: $table.actionKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActionPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActionPreferencesTable> {
  $$ActionPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get actionKey =>
      $composableBuilder(column: $table.actionKey, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ActionPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActionPreferencesTable,
          ActionPreferenceRow,
          $$ActionPreferencesTableFilterComposer,
          $$ActionPreferencesTableOrderingComposer,
          $$ActionPreferencesTableAnnotationComposer,
          $$ActionPreferencesTableCreateCompanionBuilder,
          $$ActionPreferencesTableUpdateCompanionBuilder,
          (
            ActionPreferenceRow,
            BaseReferences<
              _$AppDatabase,
              $ActionPreferencesTable,
              ActionPreferenceRow
            >,
          ),
          ActionPreferenceRow,
          PrefetchHooks Function()
        > {
  $$ActionPreferencesTableTableManager(
    _$AppDatabase db,
    $ActionPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActionPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActionPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActionPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> actionKey = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActionPreferencesCompanion(
                actionKey: actionKey,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String actionKey,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ActionPreferencesCompanion.insert(
                actionKey: actionKey,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActionPreferencesTable, ActionPreferenceRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ActionPreferencesTable,
                    ActionPreferenceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActionPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActionPreferencesTable,
      ActionPreferenceRow,
      $$ActionPreferencesTableFilterComposer,
      $$ActionPreferencesTableOrderingComposer,
      $$ActionPreferencesTableAnnotationComposer,
      $$ActionPreferencesTableCreateCompanionBuilder,
      $$ActionPreferencesTableUpdateCompanionBuilder,
      (
        ActionPreferenceRow,
        BaseReferences<
          _$AppDatabase,
          $ActionPreferencesTable,
          ActionPreferenceRow
        >,
      ),
      ActionPreferenceRow,
      PrefetchHooks Function()
    >;
typedef $$ModelsTableCreateCompanionBuilder = ModelsCompanion Function({
  required String id,
  required String sourceId,
  required String externalModelId,
  required String displayName,
  Value<String?> parentModelId,
  Value<String?> suffix,
  Value<String?> publisher,
  Value<String> sourceType,
  Value<String> metadataJson,
  Value<String> taskJson,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ModelsTableUpdateCompanionBuilder = ModelsCompanion Function({
  Value<String> id,
  Value<String> sourceId,
  Value<String> externalModelId,
  Value<String> displayName,
  Value<String?> parentModelId,
  Value<String?> suffix,
  Value<String?> publisher,
  Value<String> sourceType,
  Value<String> metadataJson,
  Value<String> taskJson,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ModelsTableFilterComposer
    extends Composer<_$AppDatabase, $ModelsTable> {
  $$ModelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalModelId => $composableBuilder(
    column: $table.externalModelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentModelId => $composableBuilder(
    column: $table.parentModelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suffix => $composableBuilder(
    column: $table.suffix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publisher => $composableBuilder(
    column: $table.publisher,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskJson => $composableBuilder(
    column: $table.taskJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ModelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelsTable> {
  $$ModelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalModelId => $composableBuilder(
    column: $table.externalModelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentModelId => $composableBuilder(
    column: $table.parentModelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suffix => $composableBuilder(
    column: $table.suffix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publisher => $composableBuilder(
    column: $table.publisher,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskJson => $composableBuilder(
    column: $table.taskJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelsTable> {
  $$ModelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get externalModelId => $composableBuilder(
    column: $table.externalModelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentModelId => $composableBuilder(
    column: $table.parentModelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suffix =>
      $composableBuilder(column: $table.suffix, builder: (column) => column);

  GeneratedColumn<String> get publisher =>
      $composableBuilder(column: $table.publisher, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taskJson =>
      $composableBuilder(column: $table.taskJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ModelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelsTable,
          Model,
          $$ModelsTableFilterComposer,
          $$ModelsTableOrderingComposer,
          $$ModelsTableAnnotationComposer,
          $$ModelsTableCreateCompanionBuilder,
          $$ModelsTableUpdateCompanionBuilder,
          (Model, BaseReferences<_$AppDatabase, $ModelsTable, Model>),
          Model,
          PrefetchHooks Function()
        > {
  $$ModelsTableTableManager(_$AppDatabase db, $ModelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> externalModelId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> parentModelId = const Value.absent(),
                Value<String?> suffix = const Value.absent(),
                Value<String?> publisher = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<String> taskJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelsCompanion(
                id: id,
                sourceId: sourceId,
                externalModelId: externalModelId,
                displayName: displayName,
                parentModelId: parentModelId,
                suffix: suffix,
                publisher: publisher,
                sourceType: sourceType,
                metadataJson: metadataJson,
                taskJson: taskJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                required String externalModelId,
                required String displayName,
                Value<String?> parentModelId = const Value.absent(),
                Value<String?> suffix = const Value.absent(),
                Value<String?> publisher = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<String> taskJson = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ModelsCompanion.insert(
                id: id,
                sourceId: sourceId,
                externalModelId: externalModelId,
                displayName: displayName,
                parentModelId: parentModelId,
                suffix: suffix,
                publisher: publisher,
                sourceType: sourceType,
                metadataJson: metadataJson,
                taskJson: taskJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelsTable, Model>(table),
                  BaseReferences<_$AppDatabase, $ModelsTable, Model>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ModelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelsTable,
      Model,
      $$ModelsTableFilterComposer,
      $$ModelsTableOrderingComposer,
      $$ModelsTableAnnotationComposer,
      $$ModelsTableCreateCompanionBuilder,
      $$ModelsTableUpdateCompanionBuilder,
      (Model, BaseReferences<_$AppDatabase, $ModelsTable, Model>),
      Model,
      PrefetchHooks Function()
    >;
typedef $$ModelArtifactsTableCreateCompanionBuilder =
    ModelArtifactsCompanion Function({
      required String id,
      required String modelId,
      required String externalPath,
      required String fileName,
      Value<String> kind,
      Value<String> sourceType,
      Value<String?> repositoryPath,
      Value<String?> deviceSourcePath,
      Value<String?> targetPath,
      Value<String?> format,
      Value<int?> sizeBytes,
      Value<bool> isLfs,
      Value<String?> oid,
      Value<String?> revision,
      Value<bool> enabled,
      Value<int> position,
      Value<String> metadataJson,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ModelArtifactsTableUpdateCompanionBuilder =
    ModelArtifactsCompanion Function({
      Value<String> id,
      Value<String> modelId,
      Value<String> externalPath,
      Value<String> fileName,
      Value<String> kind,
      Value<String> sourceType,
      Value<String?> repositoryPath,
      Value<String?> deviceSourcePath,
      Value<String?> targetPath,
      Value<String?> format,
      Value<int?> sizeBytes,
      Value<bool> isLfs,
      Value<String?> oid,
      Value<String?> revision,
      Value<bool> enabled,
      Value<int> position,
      Value<String> metadataJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ModelArtifactsTableFilterComposer
    extends Composer<_$AppDatabase, $ModelArtifactsTable> {
  $$ModelArtifactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalPath => $composableBuilder(
    column: $table.externalPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repositoryPath => $composableBuilder(
    column: $table.repositoryPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceSourcePath => $composableBuilder(
    column: $table.deviceSourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLfs => $composableBuilder(
    column: $table.isLfs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oid => $composableBuilder(
    column: $table.oid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ModelArtifactsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelArtifactsTable> {
  $$ModelArtifactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalPath => $composableBuilder(
    column: $table.externalPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repositoryPath => $composableBuilder(
    column: $table.repositoryPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceSourcePath => $composableBuilder(
    column: $table.deviceSourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLfs => $composableBuilder(
    column: $table.isLfs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oid => $composableBuilder(
    column: $table.oid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModelArtifactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelArtifactsTable> {
  $$ModelArtifactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get externalPath => $composableBuilder(
    column: $table.externalPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repositoryPath => $composableBuilder(
    column: $table.repositoryPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceSourcePath => $composableBuilder(
    column: $table.deviceSourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<bool> get isLfs =>
      $composableBuilder(column: $table.isLfs, builder: (column) => column);

  GeneratedColumn<String> get oid =>
      $composableBuilder(column: $table.oid, builder: (column) => column);

  GeneratedColumn<String> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ModelArtifactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelArtifactsTable,
          ModelArtifact,
          $$ModelArtifactsTableFilterComposer,
          $$ModelArtifactsTableOrderingComposer,
          $$ModelArtifactsTableAnnotationComposer,
          $$ModelArtifactsTableCreateCompanionBuilder,
          $$ModelArtifactsTableUpdateCompanionBuilder,
          (
            ModelArtifact,
            BaseReferences<_$AppDatabase, $ModelArtifactsTable, ModelArtifact>,
          ),
          ModelArtifact,
          PrefetchHooks Function()
        > {
  $$ModelArtifactsTableTableManager(
    _$AppDatabase db,
    $ModelArtifactsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelArtifactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelArtifactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelArtifactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<String> externalPath = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> repositoryPath = const Value.absent(),
                Value<String?> deviceSourcePath = const Value.absent(),
                Value<String?> targetPath = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<bool> isLfs = const Value.absent(),
                Value<String?> oid = const Value.absent(),
                Value<String?> revision = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelArtifactsCompanion(
                id: id,
                modelId: modelId,
                externalPath: externalPath,
                fileName: fileName,
                kind: kind,
                sourceType: sourceType,
                repositoryPath: repositoryPath,
                deviceSourcePath: deviceSourcePath,
                targetPath: targetPath,
                format: format,
                sizeBytes: sizeBytes,
                isLfs: isLfs,
                oid: oid,
                revision: revision,
                enabled: enabled,
                position: position,
                metadataJson: metadataJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String modelId,
                required String externalPath,
                required String fileName,
                Value<String> kind = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> repositoryPath = const Value.absent(),
                Value<String?> deviceSourcePath = const Value.absent(),
                Value<String?> targetPath = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<bool> isLfs = const Value.absent(),
                Value<String?> oid = const Value.absent(),
                Value<String?> revision = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ModelArtifactsCompanion.insert(
                id: id,
                modelId: modelId,
                externalPath: externalPath,
                fileName: fileName,
                kind: kind,
                sourceType: sourceType,
                repositoryPath: repositoryPath,
                deviceSourcePath: deviceSourcePath,
                targetPath: targetPath,
                format: format,
                sizeBytes: sizeBytes,
                isLfs: isLfs,
                oid: oid,
                revision: revision,
                enabled: enabled,
                position: position,
                metadataJson: metadataJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelArtifactsTable, ModelArtifact>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ModelArtifactsTable,
                    ModelArtifact
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ModelArtifactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelArtifactsTable,
      ModelArtifact,
      $$ModelArtifactsTableFilterComposer,
      $$ModelArtifactsTableOrderingComposer,
      $$ModelArtifactsTableAnnotationComposer,
      $$ModelArtifactsTableCreateCompanionBuilder,
      $$ModelArtifactsTableUpdateCompanionBuilder,
      (
        ModelArtifact,
        BaseReferences<_$AppDatabase, $ModelArtifactsTable, ModelArtifact>,
      ),
      ModelArtifact,
      PrefetchHooks Function()
    >;
typedef $$ModelSettingsTableCreateCompanionBuilder =
    ModelSettingsCompanion Function({
      required String id,
      required String modelId,
      Value<int> version,
      Value<String> optionsJson,
      Value<String> overridesJson,
      Value<int?> maxThinkingTokens,
      Value<String> thinkingConfigJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ModelSettingsTableUpdateCompanionBuilder =
    ModelSettingsCompanion Function({
      Value<String> id,
      Value<String> modelId,
      Value<int> version,
      Value<String> optionsJson,
      Value<String> overridesJson,
      Value<int?> maxThinkingTokens,
      Value<String> thinkingConfigJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ModelSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $ModelSettingsTable> {
  $$ModelSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overridesJson => $composableBuilder(
    column: $table.overridesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxThinkingTokens => $composableBuilder(
    column: $table.maxThinkingTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thinkingConfigJson => $composableBuilder(
    column: $table.thinkingConfigJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ModelSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelSettingsTable> {
  $$ModelSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overridesJson => $composableBuilder(
    column: $table.overridesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxThinkingTokens => $composableBuilder(
    column: $table.maxThinkingTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thinkingConfigJson => $composableBuilder(
    column: $table.thinkingConfigJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModelSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelSettingsTable> {
  $$ModelSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get optionsJson => $composableBuilder(
    column: $table.optionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get overridesJson => $composableBuilder(
    column: $table.overridesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxThinkingTokens => $composableBuilder(
    column: $table.maxThinkingTokens,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thinkingConfigJson => $composableBuilder(
    column: $table.thinkingConfigJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ModelSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelSettingsTable,
          ModelSetting,
          $$ModelSettingsTableFilterComposer,
          $$ModelSettingsTableOrderingComposer,
          $$ModelSettingsTableAnnotationComposer,
          $$ModelSettingsTableCreateCompanionBuilder,
          $$ModelSettingsTableUpdateCompanionBuilder,
          (
            ModelSetting,
            BaseReferences<_$AppDatabase, $ModelSettingsTable, ModelSetting>,
          ),
          ModelSetting,
          PrefetchHooks Function()
        > {
  $$ModelSettingsTableTableManager(_$AppDatabase db, $ModelSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModelSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> optionsJson = const Value.absent(),
                Value<String> overridesJson = const Value.absent(),
                Value<int?> maxThinkingTokens = const Value.absent(),
                Value<String> thinkingConfigJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelSettingsCompanion(
                id: id,
                modelId: modelId,
                version: version,
                optionsJson: optionsJson,
                overridesJson: overridesJson,
                maxThinkingTokens: maxThinkingTokens,
                thinkingConfigJson: thinkingConfigJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String modelId,
                Value<int> version = const Value.absent(),
                Value<String> optionsJson = const Value.absent(),
                Value<String> overridesJson = const Value.absent(),
                Value<int?> maxThinkingTokens = const Value.absent(),
                Value<String> thinkingConfigJson = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ModelSettingsCompanion.insert(
                id: id,
                modelId: modelId,
                version: version,
                optionsJson: optionsJson,
                overridesJson: overridesJson,
                maxThinkingTokens: maxThinkingTokens,
                thinkingConfigJson: thinkingConfigJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelSettingsTable, ModelSetting>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ModelSettingsTable,
                    ModelSetting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ModelSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelSettingsTable,
      ModelSetting,
      $$ModelSettingsTableFilterComposer,
      $$ModelSettingsTableOrderingComposer,
      $$ModelSettingsTableAnnotationComposer,
      $$ModelSettingsTableCreateCompanionBuilder,
      $$ModelSettingsTableUpdateCompanionBuilder,
      (
        ModelSetting,
        BaseReferences<_$AppDatabase, $ModelSettingsTable, ModelSetting>,
      ),
      ModelSetting,
      PrefetchHooks Function()
    >;
typedef $$ActiveModelAssignmentsTableCreateCompanionBuilder =
    ActiveModelAssignmentsCompanion Function({
      required String id,
      required String modelId,
      required String taskId,
      Value<int> priority,
      Value<String> assignmentType,
      Value<bool> enabled,
      Value<String> metadataJson,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ActiveModelAssignmentsTableUpdateCompanionBuilder =
    ActiveModelAssignmentsCompanion Function({
      Value<String> id,
      Value<String> modelId,
      Value<String> taskId,
      Value<int> priority,
      Value<String> assignmentType,
      Value<bool> enabled,
      Value<String> metadataJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ActiveModelAssignmentsTableFilterComposer
    extends Composer<_$AppDatabase, $ActiveModelAssignmentsTable> {
  $$ActiveModelAssignmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assignmentType => $composableBuilder(
    column: $table.assignmentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActiveModelAssignmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $ActiveModelAssignmentsTable> {
  $$ActiveModelAssignmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assignmentType => $composableBuilder(
    column: $table.assignmentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActiveModelAssignmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActiveModelAssignmentsTable> {
  $$ActiveModelAssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get assignmentType => $composableBuilder(
    column: $table.assignmentType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ActiveModelAssignmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActiveModelAssignmentsTable,
          ActiveModelAssignmentRow,
          $$ActiveModelAssignmentsTableFilterComposer,
          $$ActiveModelAssignmentsTableOrderingComposer,
          $$ActiveModelAssignmentsTableAnnotationComposer,
          $$ActiveModelAssignmentsTableCreateCompanionBuilder,
          $$ActiveModelAssignmentsTableUpdateCompanionBuilder,
          (
            ActiveModelAssignmentRow,
            BaseReferences<
              _$AppDatabase,
              $ActiveModelAssignmentsTable,
              ActiveModelAssignmentRow
            >,
          ),
          ActiveModelAssignmentRow,
          PrefetchHooks Function()
        > {
  $$ActiveModelAssignmentsTableTableManager(
    _$AppDatabase db,
    $ActiveModelAssignmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveModelAssignmentsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ActiveModelAssignmentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ActiveModelAssignmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> assignmentType = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActiveModelAssignmentsCompanion(
                id: id,
                modelId: modelId,
                taskId: taskId,
                priority: priority,
                assignmentType: assignmentType,
                enabled: enabled,
                metadataJson: metadataJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String modelId,
                required String taskId,
                Value<int> priority = const Value.absent(),
                Value<String> assignmentType = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ActiveModelAssignmentsCompanion.insert(
                id: id,
                modelId: modelId,
                taskId: taskId,
                priority: priority,
                assignmentType: assignmentType,
                enabled: enabled,
                metadataJson: metadataJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ActiveModelAssignmentsTable,
                    ActiveModelAssignmentRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ActiveModelAssignmentsTable,
                    ActiveModelAssignmentRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActiveModelAssignmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActiveModelAssignmentsTable,
      ActiveModelAssignmentRow,
      $$ActiveModelAssignmentsTableFilterComposer,
      $$ActiveModelAssignmentsTableOrderingComposer,
      $$ActiveModelAssignmentsTableAnnotationComposer,
      $$ActiveModelAssignmentsTableCreateCompanionBuilder,
      $$ActiveModelAssignmentsTableUpdateCompanionBuilder,
      (
        ActiveModelAssignmentRow,
        BaseReferences<
          _$AppDatabase,
          $ActiveModelAssignmentsTable,
          ActiveModelAssignmentRow
        >,
      ),
      ActiveModelAssignmentRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChatSessionsTableTableManager get chatSessions =>
      $$ChatSessionsTableTableManager(_db, _db.chatSessions);
  $$ChatEntriesTableTableManager get chatEntries =>
      $$ChatEntriesTableTableManager(_db, _db.chatEntries);
  $$ActionPreferencesTableTableManager get actionPreferences =>
      $$ActionPreferencesTableTableManager(_db, _db.actionPreferences);
  $$ModelsTableTableManager get models =>
      $$ModelsTableTableManager(_db, _db.models);
  $$ModelArtifactsTableTableManager get modelArtifacts =>
      $$ModelArtifactsTableTableManager(_db, _db.modelArtifacts);
  $$ModelSettingsTableTableManager get modelSettings =>
      $$ModelSettingsTableTableManager(_db, _db.modelSettings);
  $$ActiveModelAssignmentsTableTableManager get activeModelAssignments =>
      $$ActiveModelAssignmentsTableTableManager(
        _db,
        _db.activeModelAssignments,
      );
}
