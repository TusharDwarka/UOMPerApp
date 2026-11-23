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

/// One piece of a module's assessment: a class test, an assignment, the
/// final exam... [weight] is its share of the module mark (out of 100) and
/// [score] the mark obtained out of [outOf] (null until it's marked).
class AssessmentPart {
  final String id;
  String name;
  double weight;
  double? score;
  double outOf;

  AssessmentPart({String? id, required this.name, required this.weight, this.score, this.outOf = 100}) : id = id ?? newSyncId();

  bool get isMarked => score != null && outOf > 0;

  /// The result as a percentage (null until marked).
  double? get percent => isMarked ? (score! / outOf * 100).clamp(0, 100).toDouble() : null;

  /// Module points earned by this part (e.g. 15/20 on a 20% test → 15).
  double get points => (percent ?? 0) * weight / 100;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'weight': weight, 'score': score, 'outOf': outOf};

  factory AssessmentPart.fromJson(Map<String, dynamic> j) => AssessmentPart(
        id: j['id'] as String?,
        name: (j['name'] ?? '').toString(),
        weight: (j['weight'] as num?)?.toDouble() ?? 0,
        score: (j['score'] as num?)?.toDouble(),
        outOf: (j['outOf'] as num?)?.toDouble() ?? 100,
      );

  /// Common ways a module is marked, offered as one-tap starting points.
  static const templates = <String, List<(String, double)>>{
    '2 tests · assignment · exam': [('Test 1', 20), ('Test 2', 20), ('Assignment', 10), ('Final exam', 50)],
    '3 class tests · exam': [('Class test 1', 10), ('Class test 2', 10), ('Class test 3', 10), ('Final exam', 70)],
    'Coursework 40 · exam 60': [('Coursework', 40), ('Final exam', 60)],
    'Coursework 30 · exam 70': [('Coursework', 30), ('Final exam', 70)],
    'Project only': [('Project', 100)],
  };

  /// Quick-add names for a single part.
  static const kinds = ['Class test', 'Assignment', 'Class activity', 'Lab', 'Presentation', 'Project', 'Mid-semester test', 'Final exam'];
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

  /// How the module is marked; filled in as results come back.
  List<AssessmentPart> parts;

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
    List<AssessmentPart>? parts,
  })  : id = id ?? newSyncId(),
        parts = parts ?? [];

  /// Lower-cased name used to match timetable classes and tasks.
  String get key => keyFor(name);
  static String keyFor(String name) => name.trim().toLowerCase();

  bool get isActive => status == ModuleStatus.active;
  bool get isEnded => status != ModuleStatus.active;

  // ── Assessment breakdown ──

  /// Sum of the parts' weights (should be 100).
  double get totalWeight => parts.fold(0.0, (a, x) => a + x.weight);

  /// Weight of the parts already marked.
  double get markedWeight => parts.where((x) => x.isMarked).fold(0.0, (a, x) => a + x.weight);

  /// Module points earned so far, out of [markedWeight].
  double get pointsEarned => parts.fold(0.0, (a, x) => a + x.points);

  /// Average over the marked parts, i.e. how it's going (null before any result).
  double? get averageSoFar => markedWeight <= 0 ? null : pointsEarned / markedWeight * 100;

  /// Every part has a result.
  bool get partsComplete => parts.isNotEmpty && parts.every((x) => x.isMarked) && totalWeight > 0;

  /// Final mark worked out from the parts once all are marked. Weights that
  /// don't add up to 100 are scaled so the mark stays out of 100.
  double? get calculatedMark => partsComplete ? pointsEarned / totalWeight * 100 : null;

  /// Average needed on the unmarked parts to finish on [target] (null when
  /// nothing is left). Above 100 = out of reach; 0 or less = already safe.
  double? neededForTarget(double target) {
    final total = totalWeight > 0 ? totalWeight : 100;
    final left = total - markedWeight;
    if (parts.isEmpty || left <= 0) return null;
    return (target * total / 100 - pointsEarned) / left * 100;
  }

  /// First-attempt mark: an official mark typed in wins over the calculated one.
  double? get firstMark => mark ?? calculatedMark;

  /// Best guess at the final mark: the real one, else the average so far.
  double? get projectedMark => firstMark ?? averageSoFar;

  /// The mark that counts: a resit replaces the first attempt.
  double? effectiveMark({bool capResit = false, double passMark = 40}) {
    final r = resitMark;
    if (r != null) return capResit && r > passMark ? passMark : r;
    return firstMark;
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
        if (parts.isNotEmpty) 'parts': [for (final x in parts) x.toJson()],
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
        parts: [
          if (j['parts'] is List)
            for (final x in j['parts'] as List)
              if (x is Map) AssessmentPart.fromJson(Map<String, dynamic>.from(x))
        ],
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
