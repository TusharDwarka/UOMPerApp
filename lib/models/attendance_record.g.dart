// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_record.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAttendanceRecordCollection on Isar {
  IsarCollection<AttendanceRecord> get attendanceRecords => this.collection();
}

const AttendanceRecordSchema = CollectionSchema(
  name: r'AttendanceRecord',
  id: 3264724351450497341,
  properties: {
    r'attendedSessions': PropertySchema(
      id: 0,
      name: r'attendedSessions',
      type: IsarType.long,
    ),
    r'classesToSkip': PropertySchema(
      id: 1,
      name: r'classesToSkip',
      type: IsarType.long,
    ),
    r'isBelowThreshold': PropertySchema(
      id: 2,
      name: r'isBelowThreshold',
      type: IsarType.bool,
    ),
    r'moduleCode': PropertySchema(
      id: 3,
      name: r'moduleCode',
      type: IsarType.string,
    ),
    r'percentage': PropertySchema(
      id: 4,
      name: r'percentage',
      type: IsarType.double,
    ),
    r'totalSessions': PropertySchema(
      id: 5,
      name: r'totalSessions',
      type: IsarType.long,
    )
  },
  estimateSize: _attendanceRecordEstimateSize,
  serialize: _attendanceRecordSerialize,
  deserialize: _attendanceRecordDeserialize,
  deserializeProp: _attendanceRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'moduleCode': IndexSchema(
      id: -4649366853241320215,
      name: r'moduleCode',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'moduleCode',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _attendanceRecordGetId,
  getLinks: _attendanceRecordGetLinks,
  attach: _attendanceRecordAttach,
  version: '3.3.0',
);

int _attendanceRecordEstimateSize(
  AttendanceRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.moduleCode.length * 3;
  return bytesCount;
}

void _attendanceRecordSerialize(
  AttendanceRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.attendedSessions);
  writer.writeLong(offsets[1], object.classesToSkip);
  writer.writeBool(offsets[2], object.isBelowThreshold);
  writer.writeString(offsets[3], object.moduleCode);
  writer.writeDouble(offsets[4], object.percentage);
  writer.writeLong(offsets[5], object.totalSessions);
}

AttendanceRecord _attendanceRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AttendanceRecord(
    attendedSessions: reader.readLongOrNull(offsets[0]) ?? 0,
    moduleCode: reader.readStringOrNull(offsets[3]) ?? '',
    totalSessions: reader.readLongOrNull(offsets[5]) ?? 0,
  );
  object.id = id;
  return object;
}

P _attendanceRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 4:
      return (reader.readDouble(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _attendanceRecordGetId(AttendanceRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _attendanceRecordGetLinks(AttendanceRecord object) {
  return [];
}

void _attendanceRecordAttach(
    IsarCollection<dynamic> col, Id id, AttendanceRecord object) {
  object.id = id;
}

extension AttendanceRecordByIndex on IsarCollection<AttendanceRecord> {
  Future<AttendanceRecord?> getByModuleCode(String moduleCode) {
    return getByIndex(r'moduleCode', [moduleCode]);
  }

  AttendanceRecord? getByModuleCodeSync(String moduleCode) {
    return getByIndexSync(r'moduleCode', [moduleCode]);
  }

  Future<bool> deleteByModuleCode(String moduleCode) {
    return deleteByIndex(r'moduleCode', [moduleCode]);
  }

  bool deleteByModuleCodeSync(String moduleCode) {
    return deleteByIndexSync(r'moduleCode', [moduleCode]);
  }

  Future<List<AttendanceRecord?>> getAllByModuleCode(
      List<String> moduleCodeValues) {
    final values = moduleCodeValues.map((e) => [e]).toList();
    return getAllByIndex(r'moduleCode', values);
  }

  List<AttendanceRecord?> getAllByModuleCodeSync(
      List<String> moduleCodeValues) {
    final values = moduleCodeValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'moduleCode', values);
  }

  Future<int> deleteAllByModuleCode(List<String> moduleCodeValues) {
    final values = moduleCodeValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'moduleCode', values);
  }

  int deleteAllByModuleCodeSync(List<String> moduleCodeValues) {
    final values = moduleCodeValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'moduleCode', values);
  }

  Future<Id> putByModuleCode(AttendanceRecord object) {
    return putByIndex(r'moduleCode', object);
  }

  Id putByModuleCodeSync(AttendanceRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'moduleCode', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByModuleCode(List<AttendanceRecord> objects) {
    return putAllByIndex(r'moduleCode', objects);
  }

  List<Id> putAllByModuleCodeSync(List<AttendanceRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'moduleCode', objects, saveLinks: saveLinks);
  }
}

extension AttendanceRecordQueryWhereSort
    on QueryBuilder<AttendanceRecord, AttendanceRecord, QWhere> {
  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AttendanceRecordQueryWhere
    on QueryBuilder<AttendanceRecord, AttendanceRecord, QWhereClause> {
  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterWhereClause>
      moduleCodeEqualTo(String moduleCode) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'moduleCode',
        value: [moduleCode],
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterWhereClause>
      moduleCodeNotEqualTo(String moduleCode) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleCode',
              lower: [],
              upper: [moduleCode],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleCode',
              lower: [moduleCode],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleCode',
              lower: [moduleCode],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'moduleCode',
              lower: [],
              upper: [moduleCode],
              includeUpper: false,
            ));
      }
    });
  }
}

extension AttendanceRecordQueryFilter
    on QueryBuilder<AttendanceRecord, AttendanceRecord, QFilterCondition> {
  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      attendedSessionsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attendedSessions',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      attendedSessionsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attendedSessions',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      attendedSessionsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attendedSessions',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      attendedSessionsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attendedSessions',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      classesToSkipEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'classesToSkip',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      classesToSkipGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'classesToSkip',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      classesToSkipLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'classesToSkip',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      classesToSkipBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'classesToSkip',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      isBelowThresholdEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isBelowThreshold',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      moduleCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      moduleCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'moduleCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      moduleCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'moduleCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      moduleCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'moduleCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      moduleCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'moduleCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      moduleCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'moduleCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      moduleCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'moduleCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      moduleCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'moduleCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      moduleCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'moduleCode',
        value: '',
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      moduleCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'moduleCode',
        value: '',
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      percentageEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'percentage',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      percentageGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'percentage',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      percentageLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'percentage',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      percentageBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'percentage',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      totalSessionsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalSessions',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      totalSessionsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalSessions',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      totalSessionsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalSessions',
        value: value,
      ));
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterFilterCondition>
      totalSessionsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalSessions',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension AttendanceRecordQueryObject
    on QueryBuilder<AttendanceRecord, AttendanceRecord, QFilterCondition> {}

extension AttendanceRecordQueryLinks
    on QueryBuilder<AttendanceRecord, AttendanceRecord, QFilterCondition> {}

extension AttendanceRecordQuerySortBy
    on QueryBuilder<AttendanceRecord, AttendanceRecord, QSortBy> {
  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      sortByAttendedSessions() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attendedSessions', Sort.asc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      sortByAttendedSessionsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attendedSessions', Sort.desc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      sortByClassesToSkip() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'classesToSkip', Sort.asc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      sortByClassesToSkipDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'classesToSkip', Sort.desc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      sortByIsBelowThreshold() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBelowThreshold', Sort.asc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      sortByIsBelowThresholdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBelowThreshold', Sort.desc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      sortByModuleCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleCode', Sort.asc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      sortByModuleCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleCode', Sort.desc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      sortByPercentage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'percentage', Sort.asc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      sortByPercentageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'percentage', Sort.desc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      sortByTotalSessions() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalSessions', Sort.asc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      sortByTotalSessionsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalSessions', Sort.desc);
    });
  }
}

extension AttendanceRecordQuerySortThenBy
    on QueryBuilder<AttendanceRecord, AttendanceRecord, QSortThenBy> {
  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      thenByAttendedSessions() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attendedSessions', Sort.asc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      thenByAttendedSessionsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attendedSessions', Sort.desc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      thenByClassesToSkip() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'classesToSkip', Sort.asc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      thenByClassesToSkipDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'classesToSkip', Sort.desc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      thenByIsBelowThreshold() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBelowThreshold', Sort.asc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      thenByIsBelowThresholdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBelowThreshold', Sort.desc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      thenByModuleCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleCode', Sort.asc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      thenByModuleCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'moduleCode', Sort.desc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      thenByPercentage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'percentage', Sort.asc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      thenByPercentageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'percentage', Sort.desc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      thenByTotalSessions() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalSessions', Sort.asc);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QAfterSortBy>
      thenByTotalSessionsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalSessions', Sort.desc);
    });
  }
}

extension AttendanceRecordQueryWhereDistinct
    on QueryBuilder<AttendanceRecord, AttendanceRecord, QDistinct> {
  QueryBuilder<AttendanceRecord, AttendanceRecord, QDistinct>
      distinctByAttendedSessions() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attendedSessions');
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QDistinct>
      distinctByClassesToSkip() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'classesToSkip');
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QDistinct>
      distinctByIsBelowThreshold() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isBelowThreshold');
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QDistinct>
      distinctByModuleCode({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'moduleCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QDistinct>
      distinctByPercentage() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'percentage');
    });
  }

  QueryBuilder<AttendanceRecord, AttendanceRecord, QDistinct>
      distinctByTotalSessions() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalSessions');
    });
  }
}

extension AttendanceRecordQueryProperty
    on QueryBuilder<AttendanceRecord, AttendanceRecord, QQueryProperty> {
  QueryBuilder<AttendanceRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AttendanceRecord, int, QQueryOperations>
      attendedSessionsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attendedSessions');
    });
  }

  QueryBuilder<AttendanceRecord, int, QQueryOperations>
      classesToSkipProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'classesToSkip');
    });
  }

  QueryBuilder<AttendanceRecord, bool, QQueryOperations>
      isBelowThresholdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isBelowThreshold');
    });
  }

  QueryBuilder<AttendanceRecord, String, QQueryOperations>
      moduleCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'moduleCode');
    });
  }

  QueryBuilder<AttendanceRecord, double, QQueryOperations>
      percentageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'percentage');
    });
  }

  QueryBuilder<AttendanceRecord, int, QQueryOperations>
      totalSessionsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalSessions');
    });
  }
}
