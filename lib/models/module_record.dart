import '../utils/ids.dart';

/// Where a module is in its life: being taught, finished, or waiting on a
/// resit exam.
class ModuleStatus {
  static const active = 'active';
  static const ended = 'ended';
  static const resit = 'resit';
  static const all = [active, ended, resit];

  static String label(String s) => switch (s) {
        ended => 'Ended',
        resit => 'Resit',
        _ => 'Ongoing',
      };
}

/// One module the student takes: grade holder entry, end-of-module state and
/// resit details. Stored as JSON in settings (synced like the course name).
class ModuleRecord {
  final String id;
  String name;
  String code;
  double credits;
  int year; // 1..5
  int semester; // 1..2
  String status;

  /// Final mark out of 100 (null until the result is known).
  double? mark;

  /// Mark obtained at the resit, which replaces [mark] for the CPA.
  double? resitMark;
  DateTime? resitDate;
  DateTime? endedAt;

  ModuleRecord({
    String? id,
    required this.name,
    this.code = '',
    this.credits = 3,
    this.year = 1,
    this.semester = 1,
    this.status = ModuleStatus.active,
    this.mark,
    this.resitMark,
    this.resitDate,
    this.endedAt,
  }) : id = id ?? newSyncId();

  /// Lower-cased name used to match timetable classes and tasks.
  String get key => keyFor(name);
  static String keyFor(String name) => name.trim().toLowerCase();

  bool get isActive => status == ModuleStatus.active;
  bool get isEnded => status != ModuleStatus.active;

  /// The mark that counts: a resit replaces the first attempt.
  double? effectiveMark({bool capResit = false, double passMark = 40}) {
    final r = resitMark;
    if (r != null) return capResit && r > passMark ? passMark : r;
    return mark;
  }

  ModuleRecord copy() => ModuleRecord.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'credits': credits,
        'year': year,
        'semester': semester,
        'status': status,
        'mark': mark,
        'resitMark': resitMark,
        'resitDate': resitDate?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
      };

  factory ModuleRecord.fromJson(Map<String, dynamic> j) => ModuleRecord(
        id: j['id'] as String?,
        name: (j['name'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
        credits: (j['credits'] as num?)?.toDouble() ?? 3,
        year: (j['year'] as num?)?.toInt() ?? 1,
        semester: (j['semester'] as num?)?.toInt() ?? 1,
        status: ModuleStatus.all.contains(j['status']) ? j['status'] as String : ModuleStatus.active,
        mark: (j['mark'] as num?)?.toDouble(),
        resitMark: (j['resitMark'] as num?)?.toDouble(),
        resitDate: j['resitDate'] == null ? null : DateTime.tryParse(j['resitDate'].toString()),
        endedAt: j['endedAt'] == null ? null : DateTime.tryParse(j['endedAt'].toString()),
      );
}

/// University of Mauritius style letter grades and degree bands. Programmes
/// can differ, so screens label these as a guide.
class Grading {
  static const passMark = 40.0;

  static String letter(double mark) {
    if (mark >= 70) return 'A';
    if (mark >= 60) return 'B';
    if (mark >= 50) return 'C';
    if (mark >= 40) return 'D';
    return 'F';
  }

  static String degreeBand(double cpa) {
    if (cpa >= 70) return 'First Class';
    if (cpa >= 60) return 'Second Class Upper';
    if (cpa >= 50) return 'Second Class Lower';
    if (cpa >= 45) return 'Third Class';
    if (cpa >= 40) return 'Pass';
    return 'Below pass';
  }

  /// Credit-weighted average of (credits, mark) pairs; null when empty.
  static double? weightedAverage(Iterable<(double credits, double mark)> items) {
    var credits = 0.0, total = 0.0;
    for (final (c, m) in items) {
      if (c <= 0) continue;
      credits += c;
      total += c * m;
    }
    return credits == 0 ? null : total / credits;
  }

  /// Average needed over [remainingCredits] to reach [target], given the
  /// current [cpa] over [doneCredits]. Null when nothing is left to sit.
  static double? neededAverage({required double? cpa, required double doneCredits, required double remainingCredits, required double target}) {
    if (remainingCredits <= 0) return null;
    final done = (cpa ?? 0) * doneCredits;
    return (target * (doneCredits + remainingCredits) - done) / remainingCredits;
  }
}
