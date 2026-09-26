import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/academic_task.dart';
import '../models/class_session.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';

/// Colours matching the app's design (ink, blue accent, soft greys).
class _Pdf {
  static const ink = PdfColor.fromInt(0xFF111318);
  static const accent = PdfColor.fromInt(0xFF2962FF);
  static const canvas = PdfColor.fromInt(0xFFF5F5F7);
  static const line = PdfColor.fromInt(0xFFE3E5EA);
  static const muted = PdfColor.fromInt(0xFF8A8E96);
  static const text2 = PdfColor.fromInt(0xFF55595F);
  static const margin = PdfColor.fromInt(0xFFB9C9F5);
}

/// The built-in PDF fonts cover Latin-1 only. Map typographic characters
/// (intl puts a narrow no-break space before AM/PM) and drop the rest.
String pdfSafe(String input) {
  final mapped = input
      .replaceAll(RegExp('[   ]'), ' ')
      .replaceAll(RegExp('[‘’]'), "'")
      .replaceAll(RegExp('[“”]'), '"')
      .replaceAll(RegExp('[–—]'), '-')
      .replaceAll('→', '->')
      .replaceAll('•', '-')
      .replaceAll('☐', '[ ]')
      .replaceAll('☑', '[x]');
  return mapped.replaceAll(RegExp(r'[^\x20-\x7E\xA0-\xFF\n\r\t]'), '');
}

PdfColor _taskColor(AcademicTask t) => PdfColor.fromInt(t.colorValue ?? AppColors.forType(t.type).toARGB32());

class TaskReportOptions {
  final String title;
  final Set<String> types; // empty = all
  final Set<String> statuses; // TaskStatus values
  final DateTime from;
  final DateTime to;
  final bool includeCalendar;
  final bool includeNotes;
  final bool includeCheckboxes;

  const TaskReportOptions({
    this.title = 'My deadlines',
    this.types = const {},
    this.statuses = const {TaskStatus.todo, TaskStatus.doing},
    required this.from,
    required this.to,
    this.includeCalendar = true,
    this.includeNotes = true,
    this.includeCheckboxes = true,
  });

  /// Types shown in the picker; anything else counts as "Other".
  static const baseTypes = ['Assignment', 'Homework', 'Test', 'Exam'];

  bool matches(AcademicTask t) {
    if (!statuses.contains(t.effectiveStatus)) return false;
    if (types.isNotEmpty) {
      final key = baseTypes.contains(t.type) ? t.type : 'Other';
      if (!types.contains(key)) return false;
    }
    final start = dateOnly(t.startDate ?? t.dueDate);
    final end = dateOnly(t.dueDate);
    return !end.isBefore(dateOnly(from)) && !start.isAfter(dateOnly(to));
  }
}

class PdfExport {
  // ───────────────────────── Task report ─────────────────────────

  static Future<Uint8List> taskReport(List<AcademicTask> all, TaskReportOptions o) async {
    final tasks = all.where(o.matches).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final doc = pw.Document(title: o.title, author: 'UOMPerApp');
    final today = dateOnly(DateTime.now());

    final exams = tasks.where((t) => t.type == 'Exam' || t.type == 'Test').length;
    final thisWeek = tasks.where((t) {
      final d = dateOnly(t.dueDate).difference(today).inDays;
      return d >= 0 && d < 7;
    }).length;
    final overdue = tasks.where((t) => !t.isCompleted && dateOnly(t.dueDate).isBefore(today)).length;

    // Cover + list
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 30),
      footer: _footer,
      build: (ctx) => [
        _header(o.title, '${DateFormat('d MMM yyyy').format(o.from)} - ${DateFormat('d MMM yyyy').format(o.to)}'),
        pw.SizedBox(height: 18),
        pw.Row(children: [
          _stat('Items', '${tasks.length}', _Pdf.ink),
          pw.SizedBox(width: 8),
          _stat('Due this week', '$thisWeek', _Pdf.accent),
          pw.SizedBox(width: 8),
          _stat('Exams & tests', '$exams', const PdfColor.fromInt(0xFFFF1744)),
          pw.SizedBox(width: 8),
          _stat('Overdue', '$overdue', const PdfColor.fromInt(0xFFFF6D00)),
        ]),
        pw.SizedBox(height: 22),
        if (tasks.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Text('Nothing matches the chosen filters.', style: const pw.TextStyle(color: _Pdf.muted)),
          ),
        ..._groupedList(tasks, o),
      ],
    ));

    if (o.includeCalendar) {
      for (final month in _monthsBetween(o.from, o.to)) {
        doc.addPage(_monthPage(month, tasks: tasks, title: DateFormat('MMMM yyyy').format(month)));
      }
    }
    return doc.save();
  }

  static List<pw.Widget> _groupedList(List<AcademicTask> tasks, TaskReportOptions o) {
    final widgets = <pw.Widget>[];
    DateTime? lastDay;
    final today = dateOnly(DateTime.now());
    for (final t in tasks) {
      final day = dateOnly(t.dueDate);
      if (lastDay == null || day != lastDay) {
        lastDay = day;
        final diff = day.difference(today).inDays;
        final rel = diff == 0 ? 'Today' : diff == 1 ? 'Tomorrow' : diff < 0 ? '${-diff}d ago' : 'in ${diff}d';
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
          child: pw.Row(children: [
            pw.Text(DateFormat('EEEE d MMMM').format(day),
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _Pdf.ink)),
            pw.SizedBox(width: 8),
            pw.Text(rel, style: const pw.TextStyle(fontSize: 10, color: _Pdf.muted)),
          ]),
        ));
      }
      widgets.add(_taskRow(t, o));
    }
    return widgets;
  }

  static pw.Widget _taskRow(AcademicTask t, TaskReportOptions o) {
    final c = _taskColor(t);
    var note = '', room = '';
    if (t.description.isNotEmpty) {
      final parts = t.description.split('\n---ROOM---\n');
      note = parts[0].trim();
      if (parts.length > 1) room = parts[1].trim();
    }
    final when = t.isSpanning
        ? '${DateFormat('d MMM').format(t.startDate!)} - ${DateFormat('d MMM').format(t.dueDate)}'
        : DateFormat('HH:mm').format(t.dueDate);
    final done = t.effectiveStatus == TaskStatus.done;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(color: _Pdf.canvas, borderRadius: pw.BorderRadius.circular(10)),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(width: 5, height: 46, decoration: pw.BoxDecoration(color: c, borderRadius: pw.BorderRadius.circular(3))),
        pw.SizedBox(width: 10),
        if (o.includeCheckboxes)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10, right: 8),
            child: pw.Container(
              width: 11,
              height: 11,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _Pdf.ink, width: 1),
                borderRadius: pw.BorderRadius.circular(3),
                color: done ? _Pdf.ink : null,
              ),
            ),
          ),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: c, width: 0.8), borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Text(pdfSafe(t.type), style: pw.TextStyle(fontSize: 8, color: c, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(width: 6),
                if (t.subject != 'General')
                  pw.Expanded(
                    child: pw.Text(pdfSafe(t.subject), maxLines: 1, style: const pw.TextStyle(fontSize: 9, color: _Pdf.text2)),
                  )
                else
                  pw.Spacer(),
                pw.Text(pdfSafe(when), style: const pw.TextStyle(fontSize: 9, color: _Pdf.text2)),
              ]),
              pw.SizedBox(height: 4),
              pw.Text(pdfSafe(t.title),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: done ? _Pdf.muted : _Pdf.ink,
                    decoration: done ? pw.TextDecoration.lineThrough : null,
                  )),
              if (room.isNotEmpty) pw.Text('Room: ${pdfSafe(room)}', style: const pw.TextStyle(fontSize: 9, color: _Pdf.text2)),
              if (o.includeNotes && note.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Text(pdfSafe(note), style: const pw.TextStyle(fontSize: 9, color: _Pdf.text2)),
                ),
            ]),
          ),
        ),
        pw.SizedBox(width: 10),
      ]),
    );
  }

  // ───────────────────────── Calendar pages ─────────────────────────

  static List<DateTime> _monthsBetween(DateTime from, DateTime to) {
    final months = <DateTime>[];
    var m = DateTime(from.year, from.month);
    final last = DateTime(to.year, to.month);
    while (!m.isAfter(last) && months.length < 12) {
      months.add(m);
      m = DateTime(m.year, m.month + 1);
    }
    return months;
  }

  /// Landscape month grid; events are written into their days (multi-day
  /// events appear on each day they cover). With no tasks it is a blank
  /// printable planner.
  static pw.Page _monthPage(DateTime month, {List<AcademicTask> tasks = const [], required String title, bool notesColumn = false}) {
    final first = DateTime(month.year, month.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((first.weekday - 1 + daysInMonth) / 7).ceil();

    return pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(26),
      build: (ctx) => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(pdfSafe(title), style: const pw.TextStyle(fontSize: 26, color: _Pdf.ink)),
              pw.Spacer(),
              pw.Text('UOMPerApp', style: const pw.TextStyle(fontSize: 9, color: _Pdf.muted)),
            ]),
            pw.SizedBox(height: 10),
            pw.Row(children: [
              for (final d in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 4, bottom: 4),
                    child: pw.Text(d, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _Pdf.text2)),
                  ),
                ),
            ]),
            pw.Expanded(
              child: pw.Column(children: [
                for (var r = 0; r < rows; r++)
                  pw.Expanded(
                    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                      for (var c = 0; c < 7; c++) _dayCell(gridStart.add(Duration(days: r * 7 + c)), month, tasks),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
        if (notesColumn) ...[
          pw.SizedBox(width: 16),
          pw.SizedBox(width: 170, child: _linedBox('Notes', lines: 26)),
        ],
      ]),
    );
  }

  static pw.Widget _dayCell(DateTime day, DateTime month, List<AcademicTask> tasks) {
    final inMonth = day.month == month.month;
    final isToday = isSameDate(day, DateTime.now());
    final items = inMonth ? tasks.where((t) => t.occursOn(day)).toList() : const <AcademicTask>[];
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.all(2),
        padding: const pw.EdgeInsets.all(4),
        decoration: pw.BoxDecoration(
          color: inMonth ? PdfColors.white : _Pdf.canvas,
          border: pw.Border.all(color: _Pdf.line, width: 0.8),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: isToday ? pw.BoxDecoration(color: _Pdf.ink, borderRadius: pw.BorderRadius.circular(8)) : null,
            child: pw.Text('${day.day}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: isToday ? PdfColors.white : (inMonth ? _Pdf.ink : _Pdf.muted),
                )),
          ),
          for (final t in items.take(3))
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 2),
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: pw.BoxDecoration(color: _taskColor(t), borderRadius: pw.BorderRadius.circular(3)),
              child: pw.Text(pdfSafe(t.title), maxLines: 1, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.white)),
            ),
          if (items.length > 3) pw.Text('+${items.length - 3} more', style: const pw.TextStyle(fontSize: 6, color: _Pdf.muted)),
        ]),
      ),
    );
  }

  // ───────────────────────── Printable planners ─────────────────────────

  /// Lined / dotted / grid note paper with a margin and header fields.
  static Future<Uint8List> notePaper({required String style, int pages = 3, String module = ''}) async {
    final doc = pw.Document(title: 'Note paper', author: 'UOMPerApp');
    for (var i = 0; i < pages; i++) {
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 26),
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Row(children: [
            _field('Module', module, flex: 3),
            pw.SizedBox(width: 10),
            _field('Topic', '', flex: 3),
            pw.SizedBox(width: 10),
            _field('Date', '', flex: 2),
          ]),
          pw.SizedBox(height: 12),
          pw.Expanded(child: _paper(style)),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Text('UOMPerApp', style: const pw.TextStyle(fontSize: 7, color: _Pdf.muted)),
            pw.Spacer(),
            pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 7, color: _Pdf.muted)),
          ]),
        ]),
      ));
    }
    return doc.save();
  }

  static pw.Widget _field(String label, String value, {int flex = 1}) => pw.Expanded(
        flex: flex,
        child: pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 6),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _Pdf.line), borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label.toUpperCase(), style: pw.TextStyle(fontSize: 6, color: _Pdf.muted, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(pdfSafe(value.isEmpty ? ' ' : value), style: const pw.TextStyle(fontSize: 10, color: _Pdf.ink)),
          ]),
        ),
      );

  /// Lines every 8 mm with a coloured margin, or a 5 mm dot/square grid.
  static pw.Widget _paper(String style) {
    const spacing = 8 * PdfPageFormat.mm;
    const grid = 5 * PdfPageFormat.mm;
    return pw.CustomPaint(
      painter: (PdfGraphics canvas, PdfPoint size) {
        if (style == 'lined') {
          canvas
            ..setStrokeColor(_Pdf.line)
            ..setLineWidth(0.6);
          for (var y = size.y - spacing; y > 0; y -= spacing) {
            canvas.drawLine(0, y, size.x, y);
          }
          canvas.strokePath();
          canvas
            ..setStrokeColor(_Pdf.margin)
            ..setLineWidth(1)
            ..drawLine(22 * PdfPageFormat.mm, 0, 22 * PdfPageFormat.mm, size.y)
            ..strokePath();
        } else if (style == 'dotted') {
          canvas.setFillColor(const PdfColor.fromInt(0xFFB5B9C2));
          for (var x = grid; x < size.x; x += grid) {
            for (var y = grid; y < size.y; y += grid) {
              canvas.drawEllipse(x, y, 0.55, 0.55);
            }
          }
          canvas.fillPath();
        } else {
          canvas
            ..setStrokeColor(_Pdf.line)
            ..setLineWidth(0.4);
          for (var x = 0.0; x <= size.x; x += grid) {
            canvas.drawLine(x, 0, x, size.y);
          }
          for (var y = 0.0; y <= size.y; y += grid) {
            canvas.drawLine(0, y, size.x, y);
          }
          canvas.strokePath();
        }
      },
      child: pw.SizedBox.expand(),
    );
  }

  static pw.Widget _linedBox(String title, {int lines = 10}) => pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _Pdf.line), borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _Pdf.text2)),
          for (var i = 0; i < lines; i++)
            pw.Container(height: 16, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _Pdf.line, width: 0.6)))),
        ]),
      );

  /// Month planner pages (optionally pre-filled with deadlines) with a notes column.
  static Future<Uint8List> monthPlanner({required DateTime month, int months = 1, List<AcademicTask> tasks = const []}) async {
    final doc = pw.Document(title: 'Monthly planner', author: 'UOMPerApp');
    for (var i = 0; i < months; i++) {
      final m = DateTime(month.year, month.month + i);
      doc.addPage(_monthPage(m, tasks: tasks, title: DateFormat('MMMM yyyy').format(m), notesColumn: true));
    }
    return doc.save();
  }

  /// Week planner: one box per day with your classes pre-printed and lines to write on.
  static Future<Uint8List> weekPlanner({
    required DateTime weekStart,
    required List<ClassSession> Function(DateTime) classesFor,
    List<AcademicTask> tasks = const [],
    int weeks = 1,
  }) async {
    final doc = pw.Document(title: 'Weekly planner', author: 'UOMPerApp');
    for (var w = 0; w < weeks; w++) {
      final start = dateOnly(weekStart).add(Duration(days: 7 * w));
      final days = List.generate(7, (i) => start.add(Duration(days: i)));
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(26),
        build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Week of ${DateFormat('d MMM').format(start)}', style: const pw.TextStyle(fontSize: 22, color: _Pdf.ink)),
            pw.Spacer(),
            pw.Text('UOMPerApp', style: const pw.TextStyle(fontSize: 8, color: _Pdf.muted)),
          ]),
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: pw.Column(children: [
              for (var r = 0; r < 4; r++)
                pw.Expanded(
                  child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
                    for (var c = 0; c < 2; c++)
                      if (r * 2 + c < 7)
                        pw.Expanded(child: _weekDayBox(days[r * 2 + c], classesFor(days[r * 2 + c]), tasks))
                      else
                        pw.Expanded(child: _linedBox('Priorities this week', lines: 8)),
                  ]),
                ),
            ]),
          ),
        ]),
      ));
    }
    return doc.save();
  }

  static pw.Widget _weekDayBox(DateTime day, List<ClassSession> classes, List<AcademicTask> tasks) {
    final due = tasks.where((t) => t.occursOn(day)).toList();
    return pw.Container(
      margin: const pw.EdgeInsets.all(3),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _Pdf.line), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Row(children: [
          pw.Text(DateFormat('EEEE').format(day), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _Pdf.ink)),
          pw.SizedBox(width: 6),
          pw.Text(DateFormat('d MMM').format(day), style: const pw.TextStyle(fontSize: 9, color: _Pdf.muted)),
        ]),
        pw.SizedBox(height: 4),
        for (final c in classes.take(4))
          pw.Text(pdfSafe('${c.startTime}  ${c.subject}${c.room.isNotEmpty && c.room != 'TBD' ? ' - ${c.room}' : ''}'),
              maxLines: 1, style: const pw.TextStyle(fontSize: 8, color: _Pdf.accent)),
        for (final t in due.take(2))
          pw.Text(pdfSafe('Due: ${t.title}'), maxLines: 1, style: pw.TextStyle(fontSize: 8, color: _taskColor(t))),
        pw.Expanded(
          child: pw.LayoutBuilder(builder: (ctx, constraints) {
            final n = ((constraints?.maxHeight ?? 60) / 15).floor().clamp(0, 30);
            return pw.Column(children: [
              for (var i = 0; i < n; i++)
                pw.Container(height: 15, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _Pdf.line, width: 0.5)))),
            ]);
          }),
        ),
      ]),
    );
  }

  // ───────────────────────── Shared bits ─────────────────────────

  static pw.Widget _header(String title, String subtitle) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(color: _Pdf.accent, borderRadius: pw.BorderRadius.circular(12)),
              child: pw.Text(DateFormat('d MMM yyyy').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
            ),
            pw.Spacer(),
            pw.Text('UOMPerApp', style: const pw.TextStyle(fontSize: 9, color: _Pdf.muted)),
          ]),
          pw.SizedBox(height: 10),
          pw.Text(pdfSafe(title), style: const pw.TextStyle(fontSize: 30, color: _Pdf.ink)),
          pw.Text(pdfSafe(subtitle), style: const pw.TextStyle(fontSize: 11, color: _Pdf.text2)),
        ],
      );

  static pw.Widget _stat(String label, String value, PdfColor color) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: pw.BoxDecoration(color: _Pdf.canvas, borderRadius: pw.BorderRadius.circular(12)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(value, style: pw.TextStyle(fontSize: 20, color: color, fontWeight: pw.FontWeight.bold)),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _Pdf.text2)),
          ]),
        ),
      );

  static pw.Widget _footer(pw.Context ctx) => pw.Row(children: [
        pw.Text('Generated by UOMPerApp', style: const pw.TextStyle(fontSize: 7, color: _Pdf.muted)),
        pw.Spacer(),
        pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: _Pdf.muted)),
      ]);
}
