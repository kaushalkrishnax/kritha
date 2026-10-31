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

class $ModelConfigurationsTable extends ModelConfigurations
    with TableInfo<$ModelConfigurationsTable, ModelConfigurationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelConfigurationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repositoryIdMeta = const VerificationMeta(
    'repositoryId',
  );
  @override
  late final GeneratedColumn<String> repositoryId = GeneratedColumn<String>(
    'repository_id',
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
  static const VerificationMeta _runtimeIdMeta = const VerificationMeta(
    'runtimeId',
  );
  @override
  late final GeneratedColumn<String> runtimeId = GeneratedColumn<String>(
    'runtime_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _branchMeta = const VerificationMeta('branch');
  @override
  late final GeneratedColumn<String> branch = GeneratedColumn<String>(
    'branch',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commitShaMeta = const VerificationMeta(
    'commitSha',
  );
  @override
  late final GeneratedColumn<String> commitSha = GeneratedColumn<String>(
    'commit_sha',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rootPathMeta = const VerificationMeta(
    'rootPath',
  );
  @override
  late final GeneratedColumn<String> rootPath = GeneratedColumn<String>(
    'root_path',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    repositoryId,
    displayName,
    runtimeId,
    branch,
    commitSha,
    rootPath,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_configurations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelConfigurationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('repository_id')) {
      context.handle(
        _repositoryIdMeta,
        repositoryId.isAcceptableOrUnknown(
          data['repository_id']!,
          _repositoryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repositoryIdMeta);
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
    if (data.containsKey('runtime_id')) {
      context.handle(
        _runtimeIdMeta,
        runtimeId.isAcceptableOrUnknown(data['runtime_id']!, _runtimeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runtimeIdMeta);
    }
    if (data.containsKey('branch')) {
      context.handle(
        _branchMeta,
        branch.isAcceptableOrUnknown(data['branch']!, _branchMeta),
      );
    } else if (isInserting) {
      context.missing(_branchMeta);
    }
    if (data.containsKey('commit_sha')) {
      context.handle(
        _commitShaMeta,
        commitSha.isAcceptableOrUnknown(data['commit_sha']!, _commitShaMeta),
      );
    }
    if (data.containsKey('root_path')) {
      context.handle(
        _rootPathMeta,
        rootPath.isAcceptableOrUnknown(data['root_path']!, _rootPathMeta),
      );
    } else if (isInserting) {
      context.missing(_rootPathMeta);
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
  ModelConfigurationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelConfigurationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      repositoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repository_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      runtimeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}runtime_id'],
      )!,
      branch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch'],
      )!,
      commitSha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commit_sha'],
      ),
      rootPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_path'],
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
  $ModelConfigurationsTable createAlias(String alias) {
    return $ModelConfigurationsTable(attachedDatabase, alias);
  }
}

class ModelConfigurationRow extends DataClass
    implements Insertable<ModelConfigurationRow> {
  final String id;
  final String repositoryId;
  final String displayName;
  final String runtimeId;
  final String branch;
  final String? commitSha;
  final String rootPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ModelConfigurationRow({
    required this.id,
    required this.repositoryId,
    required this.displayName,
    required this.runtimeId,
    required this.branch,
    this.commitSha,
    required this.rootPath,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['repository_id'] = Variable<String>(repositoryId);
    map['display_name'] = Variable<String>(displayName);
    map['runtime_id'] = Variable<String>(runtimeId);
    map['branch'] = Variable<String>(branch);
    if (!nullToAbsent || commitSha != null) {
      map['commit_sha'] = Variable<String>(commitSha);
    }
    map['root_path'] = Variable<String>(rootPath);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ModelConfigurationsCompanion toCompanion(bool nullToAbsent) {
    return ModelConfigurationsCompanion(
      id: Value(id),
      repositoryId: Value(repositoryId),
      displayName: Value(displayName),
      runtimeId: Value(runtimeId),
      branch: Value(branch),
      commitSha: commitSha == null && nullToAbsent
          ? const Value.absent()
          : Value(commitSha),
      rootPath: Value(rootPath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ModelConfigurationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelConfigurationRow(
      id: serializer.fromJson<String>(json['id']),
      repositoryId: serializer.fromJson<String>(json['repositoryId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      runtimeId: serializer.fromJson<String>(json['runtimeId']),
      branch: serializer.fromJson<String>(json['branch']),
      commitSha: serializer.fromJson<String?>(json['commitSha']),
      rootPath: serializer.fromJson<String>(json['rootPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'repositoryId': serializer.toJson<String>(repositoryId),
      'displayName': serializer.toJson<String>(displayName),
      'runtimeId': serializer.toJson<String>(runtimeId),
      'branch': serializer.toJson<String>(branch),
      'commitSha': serializer.toJson<String?>(commitSha),
      'rootPath': serializer.toJson<String>(rootPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ModelConfigurationRow copyWith({
    String? id,
    String? repositoryId,
    String? displayName,
    String? runtimeId,
    String? branch,
    Value<String?> commitSha = const Value.absent(),
    String? rootPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ModelConfigurationRow(
    id: id ?? this.id,
    repositoryId: repositoryId ?? this.repositoryId,
    displayName: displayName ?? this.displayName,
    runtimeId: runtimeId ?? this.runtimeId,
    branch: branch ?? this.branch,
    commitSha: commitSha.present ? commitSha.value : this.commitSha,
    rootPath: rootPath ?? this.rootPath,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ModelConfigurationRow copyWithCompanion(ModelConfigurationsCompanion data) {
    return ModelConfigurationRow(
      id: data.id.present ? data.id.value : this.id,
      repositoryId: data.repositoryId.present
          ? data.repositoryId.value
          : this.repositoryId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      runtimeId: data.runtimeId.present ? data.runtimeId.value : this.runtimeId,
      branch: data.branch.present ? data.branch.value : this.branch,
      commitSha: data.commitSha.present ? data.commitSha.value : this.commitSha,
      rootPath: data.rootPath.present ? data.rootPath.value : this.rootPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelConfigurationRow(')
          ..write('id: $id, ')
          ..write('repositoryId: $repositoryId, ')
          ..write('displayName: $displayName, ')
          ..write('runtimeId: $runtimeId, ')
          ..write('branch: $branch, ')
          ..write('commitSha: $commitSha, ')
          ..write('rootPath: $rootPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    repositoryId,
    displayName,
    runtimeId,
    branch,
    commitSha,
    rootPath,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelConfigurationRow &&
          other.id == this.id &&
          other.repositoryId == this.repositoryId &&
          other.displayName == this.displayName &&
          other.runtimeId == this.runtimeId &&
          other.branch == this.branch &&
          other.commitSha == this.commitSha &&
          other.rootPath == this.rootPath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ModelConfigurationsCompanion
    extends UpdateCompanion<ModelConfigurationRow> {
  final Value<String> id;
  final Value<String> repositoryId;
  final Value<String> displayName;
  final Value<String> runtimeId;
  final Value<String> branch;
  final Value<String?> commitSha;
  final Value<String> rootPath;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ModelConfigurationsCompanion({
    this.id = const Value.absent(),
    this.repositoryId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.runtimeId = const Value.absent(),
    this.branch = const Value.absent(),
    this.commitSha = const Value.absent(),
    this.rootPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelConfigurationsCompanion.insert({
    required String id,
    required String repositoryId,
    required String displayName,
    required String runtimeId,
    required String branch,
    this.commitSha = const Value.absent(),
    required String rootPath,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       repositoryId = Value(repositoryId),
       displayName = Value(displayName),
       runtimeId = Value(runtimeId),
       branch = Value(branch),
       rootPath = Value(rootPath),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ModelConfigurationRow> custom({
    Expression<String>? id,
    Expression<String>? repositoryId,
    Expression<String>? displayName,
    Expression<String>? runtimeId,
    Expression<String>? branch,
    Expression<String>? commitSha,
    Expression<String>? rootPath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (repositoryId != null) 'repository_id': repositoryId,
      if (displayName != null) 'display_name': displayName,
      if (runtimeId != null) 'runtime_id': runtimeId,
      if (branch != null) 'branch': branch,
      if (commitSha != null) 'commit_sha': commitSha,
      if (rootPath != null) 'root_path': rootPath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelConfigurationsCompanion copyWith({
    Value<String>? id,
    Value<String>? repositoryId,
    Value<String>? displayName,
    Value<String>? runtimeId,
    Value<String>? branch,
    Value<String?>? commitSha,
    Value<String>? rootPath,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ModelConfigurationsCompanion(
      id: id ?? this.id,
      repositoryId: repositoryId ?? this.repositoryId,
      displayName: displayName ?? this.displayName,
      runtimeId: runtimeId ?? this.runtimeId,
      branch: branch ?? this.branch,
      commitSha: commitSha ?? this.commitSha,
      rootPath: rootPath ?? this.rootPath,
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
    if (repositoryId.present) {
      map['repository_id'] = Variable<String>(repositoryId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (runtimeId.present) {
      map['runtime_id'] = Variable<String>(runtimeId.value);
    }
    if (branch.present) {
      map['branch'] = Variable<String>(branch.value);
    }
    if (commitSha.present) {
      map['commit_sha'] = Variable<String>(commitSha.value);
    }
    if (rootPath.present) {
      map['root_path'] = Variable<String>(rootPath.value);
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
    return (StringBuffer('ModelConfigurationsCompanion(')
          ..write('id: $id, ')
          ..write('repositoryId: $repositoryId, ')
          ..write('displayName: $displayName, ')
          ..write('runtimeId: $runtimeId, ')
          ..write('branch: $branch, ')
          ..write('commitSha: $commitSha, ')
          ..write('rootPath: $rootPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModelConfigurationArtifactsTable extends ModelConfigurationArtifacts
    with
        TableInfo<
          $ModelConfigurationArtifactsTable,
          ModelConfigurationArtifactRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModelConfigurationArtifactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configurationIdMeta = const VerificationMeta(
    'configurationId',
  );
  @override
  late final GeneratedColumn<String> configurationId = GeneratedColumn<String>(
    'configuration_id',
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
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _selectedMeta = const VerificationMeta(
    'selected',
  );
  @override
  late final GeneratedColumn<bool> selected = GeneratedColumn<bool>(
    'selected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("selected" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _downloadedMeta = const VerificationMeta(
    'downloaded',
  );
  @override
  late final GeneratedColumn<bool> downloaded = GeneratedColumn<bool>(
    'downloaded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("downloaded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    configurationId,
    kind,
    sourceType,
    repositoryPath,
    deviceSourcePath,
    targetPath,
    sizeBytes,
    selected,
    downloaded,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'model_configuration_artifacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModelConfigurationArtifactRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('configuration_id')) {
      context.handle(
        _configurationIdMeta,
        configurationId.isAcceptableOrUnknown(
          data['configuration_id']!,
          _configurationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_configurationIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
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
    } else if (isInserting) {
      context.missing(_targetPathMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('selected')) {
      context.handle(
        _selectedMeta,
        selected.isAcceptableOrUnknown(data['selected']!, _selectedMeta),
      );
    }
    if (data.containsKey('downloaded')) {
      context.handle(
        _downloadedMeta,
        downloaded.isAcceptableOrUnknown(data['downloaded']!, _downloadedMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModelConfigurationArtifactRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModelConfigurationArtifactRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      configurationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}configuration_id'],
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
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      selected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}selected'],
      )!,
      downloaded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}downloaded'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $ModelConfigurationArtifactsTable createAlias(String alias) {
    return $ModelConfigurationArtifactsTable(attachedDatabase, alias);
  }
}

class ModelConfigurationArtifactRow extends DataClass
    implements Insertable<ModelConfigurationArtifactRow> {
  final String id;
  final String configurationId;
  final String kind;
  final String sourceType;
  final String? repositoryPath;
  final String? deviceSourcePath;
  final String targetPath;
  final int? sizeBytes;
  final bool selected;
  final bool downloaded;
  final int position;
  const ModelConfigurationArtifactRow({
    required this.id,
    required this.configurationId,
    required this.kind,
    required this.sourceType,
    this.repositoryPath,
    this.deviceSourcePath,
    required this.targetPath,
    this.sizeBytes,
    required this.selected,
    required this.downloaded,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['configuration_id'] = Variable<String>(configurationId);
    map['kind'] = Variable<String>(kind);
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || repositoryPath != null) {
      map['repository_path'] = Variable<String>(repositoryPath);
    }
    if (!nullToAbsent || deviceSourcePath != null) {
      map['device_source_path'] = Variable<String>(deviceSourcePath);
    }
    map['target_path'] = Variable<String>(targetPath);
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    map['selected'] = Variable<bool>(selected);
    map['downloaded'] = Variable<bool>(downloaded);
    map['position'] = Variable<int>(position);
    return map;
  }

  ModelConfigurationArtifactsCompanion toCompanion(bool nullToAbsent) {
    return ModelConfigurationArtifactsCompanion(
      id: Value(id),
      configurationId: Value(configurationId),
      kind: Value(kind),
      sourceType: Value(sourceType),
      repositoryPath: repositoryPath == null && nullToAbsent
          ? const Value.absent()
          : Value(repositoryPath),
      deviceSourcePath: deviceSourcePath == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceSourcePath),
      targetPath: Value(targetPath),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      selected: Value(selected),
      downloaded: Value(downloaded),
      position: Value(position),
    );
  }

  factory ModelConfigurationArtifactRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModelConfigurationArtifactRow(
      id: serializer.fromJson<String>(json['id']),
      configurationId: serializer.fromJson<String>(json['configurationId']),
      kind: serializer.fromJson<String>(json['kind']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      repositoryPath: serializer.fromJson<String?>(json['repositoryPath']),
      deviceSourcePath: serializer.fromJson<String?>(json['deviceSourcePath']),
      targetPath: serializer.fromJson<String>(json['targetPath']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      selected: serializer.fromJson<bool>(json['selected']),
      downloaded: serializer.fromJson<bool>(json['downloaded']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'configurationId': serializer.toJson<String>(configurationId),
      'kind': serializer.toJson<String>(kind),
      'sourceType': serializer.toJson<String>(sourceType),
      'repositoryPath': serializer.toJson<String?>(repositoryPath),
      'deviceSourcePath': serializer.toJson<String?>(deviceSourcePath),
      'targetPath': serializer.toJson<String>(targetPath),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'selected': serializer.toJson<bool>(selected),
      'downloaded': serializer.toJson<bool>(downloaded),
      'position': serializer.toJson<int>(position),
    };
  }

  ModelConfigurationArtifactRow copyWith({
    String? id,
    String? configurationId,
    String? kind,
    String? sourceType,
    Value<String?> repositoryPath = const Value.absent(),
    Value<String?> deviceSourcePath = const Value.absent(),
    String? targetPath,
    Value<int?> sizeBytes = const Value.absent(),
    bool? selected,
    bool? downloaded,
    int? position,
  }) => ModelConfigurationArtifactRow(
    id: id ?? this.id,
    configurationId: configurationId ?? this.configurationId,
    kind: kind ?? this.kind,
    sourceType: sourceType ?? this.sourceType,
    repositoryPath: repositoryPath.present
        ? repositoryPath.value
        : this.repositoryPath,
    deviceSourcePath: deviceSourcePath.present
        ? deviceSourcePath.value
        : this.deviceSourcePath,
    targetPath: targetPath ?? this.targetPath,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    selected: selected ?? this.selected,
    downloaded: downloaded ?? this.downloaded,
    position: position ?? this.position,
  );
  ModelConfigurationArtifactRow copyWithCompanion(
    ModelConfigurationArtifactsCompanion data,
  ) {
    return ModelConfigurationArtifactRow(
      id: data.id.present ? data.id.value : this.id,
      configurationId: data.configurationId.present
          ? data.configurationId.value
          : this.configurationId,
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
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      selected: data.selected.present ? data.selected.value : this.selected,
      downloaded: data.downloaded.present
          ? data.downloaded.value
          : this.downloaded,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModelConfigurationArtifactRow(')
          ..write('id: $id, ')
          ..write('configurationId: $configurationId, ')
          ..write('kind: $kind, ')
          ..write('sourceType: $sourceType, ')
          ..write('repositoryPath: $repositoryPath, ')
          ..write('deviceSourcePath: $deviceSourcePath, ')
          ..write('targetPath: $targetPath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('selected: $selected, ')
          ..write('downloaded: $downloaded, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    configurationId,
    kind,
    sourceType,
    repositoryPath,
    deviceSourcePath,
    targetPath,
    sizeBytes,
    selected,
    downloaded,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelConfigurationArtifactRow &&
          other.id == this.id &&
          other.configurationId == this.configurationId &&
          other.kind == this.kind &&
          other.sourceType == this.sourceType &&
          other.repositoryPath == this.repositoryPath &&
          other.deviceSourcePath == this.deviceSourcePath &&
          other.targetPath == this.targetPath &&
          other.sizeBytes == this.sizeBytes &&
          other.selected == this.selected &&
          other.downloaded == this.downloaded &&
          other.position == this.position);
}

class ModelConfigurationArtifactsCompanion
    extends UpdateCompanion<ModelConfigurationArtifactRow> {
  final Value<String> id;
  final Value<String> configurationId;
  final Value<String> kind;
  final Value<String> sourceType;
  final Value<String?> repositoryPath;
  final Value<String?> deviceSourcePath;
  final Value<String> targetPath;
  final Value<int?> sizeBytes;
  final Value<bool> selected;
  final Value<bool> downloaded;
  final Value<int> position;
  final Value<int> rowid;
  const ModelConfigurationArtifactsCompanion({
    this.id = const Value.absent(),
    this.configurationId = const Value.absent(),
    this.kind = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.repositoryPath = const Value.absent(),
    this.deviceSourcePath = const Value.absent(),
    this.targetPath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.selected = const Value.absent(),
    this.downloaded = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModelConfigurationArtifactsCompanion.insert({
    required String id,
    required String configurationId,
    required String kind,
    required String sourceType,
    this.repositoryPath = const Value.absent(),
    this.deviceSourcePath = const Value.absent(),
    required String targetPath,
    this.sizeBytes = const Value.absent(),
    this.selected = const Value.absent(),
    this.downloaded = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       configurationId = Value(configurationId),
       kind = Value(kind),
       sourceType = Value(sourceType),
       targetPath = Value(targetPath);
  static Insertable<ModelConfigurationArtifactRow> custom({
    Expression<String>? id,
    Expression<String>? configurationId,
    Expression<String>? kind,
    Expression<String>? sourceType,
    Expression<String>? repositoryPath,
    Expression<String>? deviceSourcePath,
    Expression<String>? targetPath,
    Expression<int>? sizeBytes,
    Expression<bool>? selected,
    Expression<bool>? downloaded,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (configurationId != null) 'configuration_id': configurationId,
      if (kind != null) 'kind': kind,
      if (sourceType != null) 'source_type': sourceType,
      if (repositoryPath != null) 'repository_path': repositoryPath,
      if (deviceSourcePath != null) 'device_source_path': deviceSourcePath,
      if (targetPath != null) 'target_path': targetPath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (selected != null) 'selected': selected,
      if (downloaded != null) 'downloaded': downloaded,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModelConfigurationArtifactsCompanion copyWith({
    Value<String>? id,
    Value<String>? configurationId,
    Value<String>? kind,
    Value<String>? sourceType,
    Value<String?>? repositoryPath,
    Value<String?>? deviceSourcePath,
    Value<String>? targetPath,
    Value<int?>? sizeBytes,
    Value<bool>? selected,
    Value<bool>? downloaded,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return ModelConfigurationArtifactsCompanion(
      id: id ?? this.id,
      configurationId: configurationId ?? this.configurationId,
      kind: kind ?? this.kind,
      sourceType: sourceType ?? this.sourceType,
      repositoryPath: repositoryPath ?? this.repositoryPath,
      deviceSourcePath: deviceSourcePath ?? this.deviceSourcePath,
      targetPath: targetPath ?? this.targetPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      selected: selected ?? this.selected,
      downloaded: downloaded ?? this.downloaded,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (configurationId.present) {
      map['configuration_id'] = Variable<String>(configurationId.value);
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
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (selected.present) {
      map['selected'] = Variable<bool>(selected.value);
    }
    if (downloaded.present) {
      map['downloaded'] = Variable<bool>(downloaded.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModelConfigurationArtifactsCompanion(')
          ..write('id: $id, ')
          ..write('configurationId: $configurationId, ')
          ..write('kind: $kind, ')
          ..write('sourceType: $sourceType, ')
          ..write('repositoryPath: $repositoryPath, ')
          ..write('deviceSourcePath: $deviceSourcePath, ')
          ..write('targetPath: $targetPath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('selected: $selected, ')
          ..write('downloaded: $downloaded, ')
          ..write('position: $position, ')
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
  late final $ModelConfigurationsTable modelConfigurations =
      $ModelConfigurationsTable(this);
  late final $ModelConfigurationArtifactsTable modelConfigurationArtifacts =
      $ModelConfigurationArtifactsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    chatSessions,
    chatEntries,
    modelConfigurations,
    modelConfigurationArtifacts,
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
typedef $$ModelConfigurationsTableCreateCompanionBuilder =
    ModelConfigurationsCompanion Function({
      required String id,
      required String repositoryId,
      required String displayName,
      required String runtimeId,
      required String branch,
      Value<String?> commitSha,
      required String rootPath,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ModelConfigurationsTableUpdateCompanionBuilder =
    ModelConfigurationsCompanion Function({
      Value<String> id,
      Value<String> repositoryId,
      Value<String> displayName,
      Value<String> runtimeId,
      Value<String> branch,
      Value<String?> commitSha,
      Value<String> rootPath,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ModelConfigurationsTableFilterComposer
    extends Composer<_$AppDatabase, $ModelConfigurationsTable> {
  $$ModelConfigurationsTableFilterComposer({
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

  ColumnFilters<String> get repositoryId => $composableBuilder(
    column: $table.repositoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runtimeId => $composableBuilder(
    column: $table.runtimeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commitSha => $composableBuilder(
    column: $table.commitSha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootPath => $composableBuilder(
    column: $table.rootPath,
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

class $$ModelConfigurationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelConfigurationsTable> {
  $$ModelConfigurationsTableOrderingComposer({
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

  ColumnOrderings<String> get repositoryId => $composableBuilder(
    column: $table.repositoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runtimeId => $composableBuilder(
    column: $table.runtimeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commitSha => $composableBuilder(
    column: $table.commitSha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootPath => $composableBuilder(
    column: $table.rootPath,
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

class $$ModelConfigurationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelConfigurationsTable> {
  $$ModelConfigurationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get repositoryId => $composableBuilder(
    column: $table.repositoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get runtimeId =>
      $composableBuilder(column: $table.runtimeId, builder: (column) => column);

  GeneratedColumn<String> get branch =>
      $composableBuilder(column: $table.branch, builder: (column) => column);

  GeneratedColumn<String> get commitSha =>
      $composableBuilder(column: $table.commitSha, builder: (column) => column);

  GeneratedColumn<String> get rootPath =>
      $composableBuilder(column: $table.rootPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ModelConfigurationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelConfigurationsTable,
          ModelConfigurationRow,
          $$ModelConfigurationsTableFilterComposer,
          $$ModelConfigurationsTableOrderingComposer,
          $$ModelConfigurationsTableAnnotationComposer,
          $$ModelConfigurationsTableCreateCompanionBuilder,
          $$ModelConfigurationsTableUpdateCompanionBuilder,
          (
            ModelConfigurationRow,
            BaseReferences<
              _$AppDatabase,
              $ModelConfigurationsTable,
              ModelConfigurationRow
            >,
          ),
          ModelConfigurationRow,
          PrefetchHooks Function()
        > {
  $$ModelConfigurationsTableTableManager(
    _$AppDatabase db,
    $ModelConfigurationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelConfigurationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModelConfigurationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ModelConfigurationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> repositoryId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> runtimeId = const Value.absent(),
                Value<String> branch = const Value.absent(),
                Value<String?> commitSha = const Value.absent(),
                Value<String> rootPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelConfigurationsCompanion(
                id: id,
                repositoryId: repositoryId,
                displayName: displayName,
                runtimeId: runtimeId,
                branch: branch,
                commitSha: commitSha,
                rootPath: rootPath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String repositoryId,
                required String displayName,
                required String runtimeId,
                required String branch,
                Value<String?> commitSha = const Value.absent(),
                required String rootPath,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ModelConfigurationsCompanion.insert(
                id: id,
                repositoryId: repositoryId,
                displayName: displayName,
                runtimeId: runtimeId,
                branch: branch,
                commitSha: commitSha,
                rootPath: rootPath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModelConfigurationsTable, ModelConfigurationRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ModelConfigurationsTable,
                    ModelConfigurationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ModelConfigurationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelConfigurationsTable,
      ModelConfigurationRow,
      $$ModelConfigurationsTableFilterComposer,
      $$ModelConfigurationsTableOrderingComposer,
      $$ModelConfigurationsTableAnnotationComposer,
      $$ModelConfigurationsTableCreateCompanionBuilder,
      $$ModelConfigurationsTableUpdateCompanionBuilder,
      (
        ModelConfigurationRow,
        BaseReferences<
          _$AppDatabase,
          $ModelConfigurationsTable,
          ModelConfigurationRow
        >,
      ),
      ModelConfigurationRow,
      PrefetchHooks Function()
    >;
typedef $$ModelConfigurationArtifactsTableCreateCompanionBuilder =
    ModelConfigurationArtifactsCompanion Function({
      required String id,
      required String configurationId,
      required String kind,
      required String sourceType,
      Value<String?> repositoryPath,
      Value<String?> deviceSourcePath,
      required String targetPath,
      Value<int?> sizeBytes,
      Value<bool> selected,
      Value<bool> downloaded,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$ModelConfigurationArtifactsTableUpdateCompanionBuilder =
    ModelConfigurationArtifactsCompanion Function({
      Value<String> id,
      Value<String> configurationId,
      Value<String> kind,
      Value<String> sourceType,
      Value<String?> repositoryPath,
      Value<String?> deviceSourcePath,
      Value<String> targetPath,
      Value<int?> sizeBytes,
      Value<bool> selected,
      Value<bool> downloaded,
      Value<int> position,
      Value<int> rowid,
    });

class $$ModelConfigurationArtifactsTableFilterComposer
    extends Composer<_$AppDatabase, $ModelConfigurationArtifactsTable> {
  $$ModelConfigurationArtifactsTableFilterComposer({
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

  ColumnFilters<String> get configurationId => $composableBuilder(
    column: $table.configurationId,
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

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get selected => $composableBuilder(
    column: $table.selected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get downloaded => $composableBuilder(
    column: $table.downloaded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ModelConfigurationArtifactsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModelConfigurationArtifactsTable> {
  $$ModelConfigurationArtifactsTableOrderingComposer({
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

  ColumnOrderings<String> get configurationId => $composableBuilder(
    column: $table.configurationId,
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

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get selected => $composableBuilder(
    column: $table.selected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get downloaded => $composableBuilder(
    column: $table.downloaded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModelConfigurationArtifactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModelConfigurationArtifactsTable> {
  $$ModelConfigurationArtifactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get configurationId => $composableBuilder(
    column: $table.configurationId,
    builder: (column) => column,
  );

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

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<bool> get selected =>
      $composableBuilder(column: $table.selected, builder: (column) => column);

  GeneratedColumn<bool> get downloaded => $composableBuilder(
    column: $table.downloaded,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$ModelConfigurationArtifactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModelConfigurationArtifactsTable,
          ModelConfigurationArtifactRow,
          $$ModelConfigurationArtifactsTableFilterComposer,
          $$ModelConfigurationArtifactsTableOrderingComposer,
          $$ModelConfigurationArtifactsTableAnnotationComposer,
          $$ModelConfigurationArtifactsTableCreateCompanionBuilder,
          $$ModelConfigurationArtifactsTableUpdateCompanionBuilder,
          (
            ModelConfigurationArtifactRow,
            BaseReferences<
              _$AppDatabase,
              $ModelConfigurationArtifactsTable,
              ModelConfigurationArtifactRow
            >,
          ),
          ModelConfigurationArtifactRow,
          PrefetchHooks Function()
        > {
  $$ModelConfigurationArtifactsTableTableManager(
    _$AppDatabase db,
    $ModelConfigurationArtifactsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModelConfigurationArtifactsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ModelConfigurationArtifactsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ModelConfigurationArtifactsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> configurationId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> repositoryPath = const Value.absent(),
                Value<String?> deviceSourcePath = const Value.absent(),
                Value<String> targetPath = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<bool> selected = const Value.absent(),
                Value<bool> downloaded = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelConfigurationArtifactsCompanion(
                id: id,
                configurationId: configurationId,
                kind: kind,
                sourceType: sourceType,
                repositoryPath: repositoryPath,
                deviceSourcePath: deviceSourcePath,
                targetPath: targetPath,
                sizeBytes: sizeBytes,
                selected: selected,
                downloaded: downloaded,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String configurationId,
                required String kind,
                required String sourceType,
                Value<String?> repositoryPath = const Value.absent(),
                Value<String?> deviceSourcePath = const Value.absent(),
                required String targetPath,
                Value<int?> sizeBytes = const Value.absent(),
                Value<bool> selected = const Value.absent(),
                Value<bool> downloaded = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModelConfigurationArtifactsCompanion.insert(
                id: id,
                configurationId: configurationId,
                kind: kind,
                sourceType: sourceType,
                repositoryPath: repositoryPath,
                deviceSourcePath: deviceSourcePath,
                targetPath: targetPath,
                sizeBytes: sizeBytes,
                selected: selected,
                downloaded: downloaded,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ModelConfigurationArtifactsTable,
                    ModelConfigurationArtifactRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ModelConfigurationArtifactsTable,
                    ModelConfigurationArtifactRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ModelConfigurationArtifactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModelConfigurationArtifactsTable,
      ModelConfigurationArtifactRow,
      $$ModelConfigurationArtifactsTableFilterComposer,
      $$ModelConfigurationArtifactsTableOrderingComposer,
      $$ModelConfigurationArtifactsTableAnnotationComposer,
      $$ModelConfigurationArtifactsTableCreateCompanionBuilder,
      $$ModelConfigurationArtifactsTableUpdateCompanionBuilder,
      (
        ModelConfigurationArtifactRow,
        BaseReferences<
          _$AppDatabase,
          $ModelConfigurationArtifactsTable,
          ModelConfigurationArtifactRow
        >,
      ),
      ModelConfigurationArtifactRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChatSessionsTableTableManager get chatSessions =>
      $$ChatSessionsTableTableManager(_db, _db.chatSessions);
  $$ChatEntriesTableTableManager get chatEntries =>
      $$ChatEntriesTableTableManager(_db, _db.chatEntries);
  $$ModelConfigurationsTableTableManager get modelConfigurations =>
      $$ModelConfigurationsTableTableManager(_db, _db.modelConfigurations);
  $$ModelConfigurationArtifactsTableTableManager
  get modelConfigurationArtifacts =>
      $$ModelConfigurationArtifactsTableTableManager(
        _db,
        _db.modelConfigurationArtifacts,
      );
}
