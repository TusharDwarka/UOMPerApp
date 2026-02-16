import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/academic_task.dart';
import '../providers/timetable_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TodoBoardTab extends StatefulWidget {
  const TodoBoardTab({super.key});

  @override
  State<TodoBoardTab> createState() => _TodoBoardTabState();
}

class _TodoBoardTabState extends State<TodoBoardTab> {

  void _showAddEditSheet({AcademicTask? taskToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEditTaskSheet(taskToEdit: taskToEdit),
    );
  }

  void _showPrintMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(4)))),
                  Text("Share / Print Tasks", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 6),
                  Text("Choose format and filter", style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.blue.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.picture_as_pdf, color: Colors.red[400], size: 18),
                          const SizedBox(width: 8),
                          Text("PDF (Print-Ready)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                        ]),
                        const SizedBox(height: 12),
                        _buildPrintOption(ctx, Icons.select_all, "All Tasks", null, isDark, isPdf: true),
                        _buildPrintOption(ctx, Icons.local_fire_department, "Exams & Tests", (t) => t.type == 'Exam' || t.type == 'Test', isDark, isPdf: true),
                        _buildPrintOption(ctx, Icons.assignment, "Assignments", (t) => t.type == 'Assignment', isDark, isPdf: true),
                        _buildPrintOption(ctx, Icons.pending_actions, "Pending Only", (t) => !t.isCompleted, isDark, isPdf: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.green.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.green.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.text_snippet, color: Colors.green[400], size: 18),
                          const SizedBox(width: 8),
                          Flexible(child: Text("Text (Share via WhatsApp, etc.)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87))),
                        ]),
                        const SizedBox(height: 12),
                        _buildPrintOption(ctx, Icons.select_all, "All Tasks", null, isDark, isPdf: false),
                        _buildPrintOption(ctx, Icons.local_fire_department, "Exams & Tests", (t) => t.type == 'Exam' || t.type == 'Test', isDark, isPdf: false),
                        _buildPrintOption(ctx, Icons.pending_actions, "Pending Only", (t) => !t.isCompleted, isDark, isPdf: false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildPrintOption(BuildContext ctx, IconData icon, String label, bool Function(AcademicTask)? filter, bool isDark, {required bool isPdf}) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        if (isPdf) {
          _generatePdf(filter, label);
        } else {
          _shareTasks(filter, label);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDark ? Colors.blueAccent : Colors.indigo, size: 18),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
            const Spacer(),
            Icon(isPdf ? Icons.print : Icons.share, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // TEXT SHARE
  // ═══════════════════════════════════════════
  void _shareTasks(bool Function(AcademicTask)? filter, String label) {
    final timetable = Provider.of<TimetableProvider>(context, listen: false);
    var tasks = timetable.tasks.toList();
    if (filter != null) tasks = tasks.where(filter).toList();
    
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No tasks to share!")));
      return;
    }

    tasks.sort((a, b) {
      if (a.type == 'Exam' && b.type != 'Exam') return -1;
      if (b.type == 'Exam' && a.type != 'Exam') return 1;
      return a.dueDate.compareTo(b.dueDate);
    });

    final buffer = StringBuffer();
    buffer.writeln("📋 UOMPer — $label");
    buffer.writeln("━" * 30);
    buffer.writeln();

    String? lastType;
    for (final t in tasks) {
      if (t.type != lastType) {
        lastType = t.type;
        String emoji;
        switch(t.type) {
          case 'Exam': emoji = '🔴'; break;
          case 'Test': emoji = '🟠'; break;
          case 'Assignment': emoji = '🔵'; break;
          case 'Homework': emoji = '📗'; break;
          case 'Project': emoji = '🟣'; break;
          default: emoji = '⚪';
        }
        buffer.writeln("$emoji ${t.type.toUpperCase()}S");
        buffer.writeln("─" * 20);
      }
      final status = t.isCompleted ? "✅" : "⬜";
      final date = DateFormat('MMM d, h:mm a').format(t.dueDate);
      buffer.writeln("$status ${t.title}");
      buffer.writeln("   📚 ${t.subject} • 📅 $date");
      if (t.description.isNotEmpty) {
        final parts = t.description.split('\n---ROOM---\n');
        if (parts[0].isNotEmpty) buffer.writeln("   📝 ${parts[0]}");
        if (parts.length > 1 && parts[1].isNotEmpty) buffer.writeln("   📍 Room: ${parts[1]}");
      }
      buffer.writeln();
    }
    
    buffer.writeln("━" * 30);
    buffer.writeln("Shared from UOMPer App");
    
    Share.share(buffer.toString(), subject: "UOMPer — $label");
  }

  // ═══════════════════════════════════════════
  // PDF GENERATION
  // ═══════════════════════════════════════════
  Future<void> _generatePdf(bool Function(AcademicTask)? filter, String label) async {
    final timetable = Provider.of<TimetableProvider>(context, listen: false);
    var tasks = timetable.tasks.toList();
    if (filter != null) tasks = tasks.where(filter).toList();
    
    if (tasks.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No tasks to print!")));
      return;
    }

    // Sort: high stakes first, then by date
    tasks.sort((a, b) {
      const priority = {'Exam': 0, 'Test': 1, 'Assignment': 2, 'Homework': 3, 'Project': 4, 'Other': 5};
      final pa = priority[a.type] ?? 5;
      final pb = priority[b.type] ?? 5;
      if (pa != pb) return pa.compareTo(pb);
      return a.dueDate.compareTo(b.dueDate);
    });

    // Helper: Sanitize string to remove unsupported characters (emojis, etc.) for PDF
    String sanitize(String input) {
      // Remove characters outside standard Latin/Latin-1 range (keep only basic text + basic punctuation)
      // This regex keeps ASCII + common accented characters (Latin-1 Supplement 0x80-0xFF roughly)
      // But PDF default font usually only reliably supports Windows-1252 or ASCII.
      // Easiest is to strip non-ascii for stability, or replace.
      return input.replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), '?'); // Replace non-ascii with ?
    }
    
    final pdf = pw.Document();
    final now = DateFormat('MMMM d, yyyy').format(DateTime.now());

    // Helper: blend a PdfColor towards white (lighten)
    PdfColor lighten(PdfColor c, double amount) {
      return PdfColor(c.red + (1.0 - c.red) * amount, c.green + (1.0 - c.green) * amount, c.blue + (1.0 - c.blue) * amount);
    }

    // Color mapping for PDF
    PdfColor typeColor(String type) {
      switch(type) {
        case 'Exam': return PdfColors.red;
        case 'Test': return PdfColors.orange;
        case 'Assignment': return PdfColors.indigo;
        case 'Homework': return PdfColors.teal;
        case 'Project': return PdfColors.purple;
        default: return PdfColors.blueGrey;
      }
    }

    PdfColor typeBg(String type) {
      return lighten(typeColor(type), 0.9);
    }

    // Count by type
    final examCount = tasks.where((t) => t.type == 'Exam' || t.type == 'Test').length;
    final assignCount = tasks.where((t) => t.type == 'Assignment').length;
    final hwCount = tasks.where((t) => t.type == 'Homework').length;
    final doneCount = tasks.where((t) => t.isCompleted).length;
    final pendingCount = tasks.where((t) => !t.isCompleted).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("UOMPer", style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
                    pw.SizedBox(height: 4),
                    pw.Text(label, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(now, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
                    pw.SizedBox(height: 2),
                    pw.Text("${tasks.length} tasks total", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
                  ],
                )
              ],
            ),
            pw.SizedBox(height: 12),
            // Stats bar
            pw.Row(
              children: [
                _buildPdfStat("Exams/Tests", "$examCount", PdfColors.red),
                pw.SizedBox(width: 8),
                _buildPdfStat("Assignments", "$assignCount", PdfColors.indigo),
                pw.SizedBox(width: 8),
                _buildPdfStat("Homework", "$hwCount", PdfColors.teal),
                pw.SizedBox(width: 8),
                _buildPdfStat("Pending", "$pendingCount", PdfColors.orange),
                pw.SizedBox(width: 8),
                _buildPdfStat("Done", "$doneCount", PdfColors.green),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(height: 2, color: PdfColors.indigo),
            pw.SizedBox(height: 16),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("Generated by UOMPer App", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
            pw.Text("Page ${context.pageNumber} of ${context.pagesCount}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          ],
        ),
        build: (context) {
          final widgets = <pw.Widget>[];
          String? lastType;

          for (final task in tasks) {
            // Section Header when type changes
            if (task.type != lastType) {
              lastType = task.type;
              if (widgets.isNotEmpty) widgets.add(pw.SizedBox(height: 16));
              
              widgets.add(
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: typeColor(task.type),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        "${task.type.toUpperCase()}S",
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      ),
                    ],
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 8));
            }

            // Parse note & room
            String note = '';
            String room = '';
            if (task.description.isNotEmpty) {
              final parts = task.description.split('\n---ROOM---\n');
              note = sanitize(parts[0]);
              if (parts.length > 1) room = sanitize(parts[1]);
            }
            final displayTitle = sanitize(task.title);
            final displaySubject = sanitize(task.subject);

            final daysUntil = task.dueDate.difference(DateTime.now()).inDays;
            String urgency = '';
            PdfColor urgencyColor = PdfColors.grey;
            if (!task.isCompleted && daysUntil < 0) {
              urgency = 'OVERDUE';
              urgencyColor = PdfColors.red;
            } else if (!task.isCompleted && daysUntil == 0) {
              urgency = 'TODAY';
              urgencyColor = PdfColors.red;
            } else if (!task.isCompleted && daysUntil == 1) {
              urgency = 'TOMORROW';
              urgencyColor = PdfColors.orange;
            } else if (!task.isCompleted && daysUntil <= 3) {
              urgency = '${daysUntil}d LEFT';
              urgencyColor = PdfColors.amber;
            }

            // Task Card
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: task.isCompleted ? PdfColor.fromHex('#F0F0F0') : typeBg(task.type),
                  // borderRadius: pw.BorderRadius.circular(8), // REMOVED: Cannot mix borderRadius with non-uniform Border
                  border: pw.Border(
                    left: pw.BorderSide(color: typeColor(task.type), width: 3),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            displayTitle,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: task.isCompleted ? PdfColors.grey : PdfColors.black,
                              decoration: task.isCompleted ? pw.TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (task.isCompleted)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: pw.BoxDecoration(color: PdfColors.green, borderRadius: pw.BorderRadius.circular(4)),
                            child: pw.Text("DONE", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          ),
                        if (!task.isCompleted && urgency.isNotEmpty)
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: pw.BoxDecoration(color: urgencyColor, borderRadius: pw.BorderRadius.circular(4)),
                            child: pw.Text(urgency, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(color: lighten(typeColor(task.type), 0.85), borderRadius: pw.BorderRadius.circular(4)),
                          child: pw.Text(displaySubject, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: typeColor(task.type))),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          DateFormat('EEE, MMM d @ h:mm a').format(task.dueDate),
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                        ),
                        if (room.isNotEmpty) ...[
                          pw.SizedBox(width: 10),
                          pw.Text("Room: $room", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                        ],
                      ],
                    ),
                    if (note.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#FAFAFA'),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(note, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          return widgets;
        },
      ),
    );

    // Show print/share dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: "UOMPer_${label.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}",
    );
  }

  static PdfColor _lightenStatic(PdfColor c, double amount) {
    return PdfColor(c.red + (1.0 - c.red) * amount, c.green + (1.0 - c.green) * amount, c.blue + (1.0 - c.blue) * amount);
  }

  pw.Widget _buildPdfStat(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: pw.BoxDecoration(
          color: _lightenStatic(color, 0.9),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _lightenStatic(color, 0.6)),
        ),
        child: pw.Column(
          children: [
            pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
            pw.SizedBox(height: 2),
            pw.Text(label, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, timetable, child) {
        final pending = timetable.pendingTasks;
        final completed = timetable.completedTasks;

        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Split pending into 3 tiers
        final highStakes = pending.where((t) => t.type == 'Exam' || t.type == 'Test').toList();
        final assignments = pending.where((t) => t.type == 'Assignment').toList();
        final regular = pending.where((t) => t.type != 'Exam' && t.type != 'Test' && t.type != 'Assignment').toList();

        // Sort by due date
        highStakes.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        regular.sort((a, b) => a.dueDate.compareTo(b.dueDate));

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            title: Text("To-Do Board", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w900, fontSize: 26)),
            actions: [
              IconButton(
                onPressed: _showPrintMenu, 
                icon: Icon(Icons.ios_share, color: isDark ? Colors.white70 : Colors.black54, size: 24),
                tooltip: "Share / Print",
              ),
              IconButton(onPressed: () => _showAddEditSheet(), icon: Icon(Icons.add_circle, color: isDark ? Colors.white : Colors.black, size: 30))
            ],
          ),
          body: timetable.tasks.isEmpty 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.checklist_rounded, size: 80, color: isDark ? Colors.white10 : Colors.grey[200]),
                    const SizedBox(height: 10),
                    Text("No tasks yet", style: TextStyle(color: Colors.grey[400], fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("Tap + to add one", style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  // HIGH STAKES SECTION
                  if (highStakes.isNotEmpty) ...[
                    _buildSectionHeader(
                      icon: Icons.local_fire_department_rounded,
                      title: "HIGH STAKES",
                      subtitle: "${highStakes.length} exam${highStakes.length > 1 ? 's' : ''} / test${highStakes.length > 1 ? 's' : ''}",
                      color: Colors.redAccent,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: Colors.redAccent.withOpacity(0.6), width: 3)),
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                      ),
                      child: Column(children: highStakes.map((t) => _buildTaskCard(t, isDark: isDark, isHighStakes: true)).toList()),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ASSIGNMENTS SECTION
                  if (assignments.isNotEmpty) ...[
                    _buildSectionHeader(
                      icon: Icons.assignment_rounded,
                      title: "ASSIGNMENTS",
                      subtitle: "${assignments.length} due",
                      color: Colors.indigoAccent,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: Colors.indigoAccent.withOpacity(0.4), width: 3)),
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                      ),
                      child: Column(children: assignments.map((t) => _buildTaskCard(t, isDark: isDark, isAssignment: true)).toList()),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // TASKS SECTION
                  if (regular.isNotEmpty) ...[
                    _buildSectionHeader(
                      icon: Icons.checklist_rounded,
                      title: "TASKS",
                      subtitle: "${regular.length} item${regular.length > 1 ? 's' : ''}",
                      color: Colors.teal,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    ...regular.map((t) => _buildTaskCard(t, isDark: isDark)),
                    const SizedBox(height: 20),
                  ],
                  
                  // COMPLETED SECTION
                  if (completed.isNotEmpty) ...[
                    _buildSectionHeader(
                      icon: Icons.check_circle_outline,
                      title: "COMPLETED",
                      subtitle: "${completed.length} done",
                      color: Colors.green,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    ...completed.map((t) => _buildTaskCard(t, isDark: isDark)),
                  ]
                ],
              ),
        );
      }
    );
  }

  Widget _buildSectionHeader({
    required IconData icon, required String title, required String subtitle,
    required Color color, required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
        const SizedBox(width: 8),
        Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 11)),
      ],
    );
  }

  Widget _buildTaskCard(AcademicTask task, {bool isDark = false, bool isHighStakes = false, bool isAssignment = false}) {
    Color typeColor;
    IconData typeIcon;
    switch(task.type) {
      case 'Exam': typeColor = Colors.redAccent; typeIcon = Icons.warning_rounded; break;
      case 'Test': typeColor = Colors.orangeAccent; typeIcon = Icons.priority_high_rounded; break;
      case 'Assignment': typeColor = Colors.indigoAccent; typeIcon = Icons.assignment_rounded; break;
      case 'Project': typeColor = Colors.purpleAccent; typeIcon = Icons.group_work_rounded; break;
      case 'Homework': typeColor = Colors.teal; typeIcon = Icons.menu_book_rounded; break;
      default: typeColor = Colors.blueAccent; typeIcon = Icons.task_alt_rounded;
    }

    // Parse note & room from description
    String note = '';
    String room = '';
    if (task.description.isNotEmpty) {
      final parts = task.description.split('\n---ROOM---\n');
      note = parts[0];
      if (parts.length > 1) room = parts[1];
    }

    // Urgency
    final daysUntil = task.dueDate.difference(DateTime.now()).inDays;
    Color? urgencyColor;
    String? urgencyLabel;
    if (!task.isCompleted && daysUntil < 0) {
      urgencyColor = Colors.red; urgencyLabel = "OVERDUE";
    } else if (!task.isCompleted && daysUntil == 0) {
      urgencyColor = Colors.redAccent; urgencyLabel = "TODAY";
    } else if (!task.isCompleted && daysUntil == 1) {
      urgencyColor = Colors.orange; urgencyLabel = "TOMORROW";
    } else if (!task.isCompleted && daysUntil <= 3) {
      urgencyColor = Colors.amber; urgencyLabel = "${daysUntil}d left";
    }

    return Dismissible(
      key: Key(task.title + task.id.toString()),
      background: Container(
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(18)),
        alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (dir) {
        Provider.of<TimetableProvider>(context, listen: false).deleteTask(task.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: task.isCompleted 
             ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50]) 
             : isHighStakes
               ? (isDark ? const Color(0xFF2A1A1A) : const Color(0xFFFFF8F6))
               : isAssignment
                 ? (isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F5FF))
                 : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isHighStakes 
              ? (isDark ? Colors.redAccent.withOpacity(0.2) : Colors.red.withOpacity(0.1))
              : isAssignment
                ? (isDark ? Colors.indigoAccent.withOpacity(0.2) : Colors.indigo.withOpacity(0.1))
                : (isDark ? Colors.white10 : (task.isCompleted ? Colors.grey[200]! : Colors.grey[100]!))
          ),
          boxShadow: (task.isCompleted || isDark) ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                 task.isCompleted = !task.isCompleted;
                 Provider.of<TimetableProvider>(context, listen: false).updateTask(
                   task.id, task.title, task.subject, task.type, task.dueDate, task.isCompleted,
                   description: task.description,
                 );
              },
              child: Container(
                width: 28, height: 28,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: task.isCompleted ? Colors.green[400] : Colors.transparent,
                  border: Border.all(
                    color: task.isCompleted 
                      ? Colors.green[400]! 
                      : isHighStakes ? Colors.redAccent.withOpacity(0.5) : Colors.grey[300]!, 
                    width: 2
                  ),
                  shape: BoxShape.circle
                ),
                child: task.isCompleted ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => _showAddEditSheet(taskToEdit: task),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(typeIcon, size: 10, color: typeColor),
                              const SizedBox(width: 4),
                              Text(task.type.toUpperCase(), style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: Text(task.subject, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        const Spacer(),
                        if (urgencyColor != null && urgencyLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: urgencyColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                            child: Text(urgencyLabel, style: TextStyle(color: urgencyColor, fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(task.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, decoration: task.isCompleted ? TextDecoration.lineThrough : null, color: task.isCompleted ? Colors.grey : (isDark ? Colors.white : Colors.black87))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(DateFormat('MMM d, h:mm a').format(task.dueDate), style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500)),
                        if (room.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.location_on, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 2),
                          Text(room, style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ],
                    ),
                    // Show note preview
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.sticky_note_2, size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 6),
                            Expanded(child: Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Separate StatefulWidget for Add/Edit sheet — fixes keyboard lag
// ═══════════════════════════════════════════════════════════════════
class _AddEditTaskSheet extends StatefulWidget {
  final AcademicTask? taskToEdit;
  const _AddEditTaskSheet({this.taskToEdit});

  @override
  State<_AddEditTaskSheet> createState() => _AddEditTaskSheetState();
}

class _AddEditTaskSheetState extends State<_AddEditTaskSheet> {
  late TextEditingController _titleController;
  late TextEditingController _subjectController;
  late TextEditingController _noteController;
  late TextEditingController _roomController;
  late String type;
  late DateTime selectedDate;
  late TimeOfDay selectedTime;
  bool _showSubjectSuggestions = false;

  @override
  void initState() {
    super.initState();
    final task = widget.taskToEdit;
    _titleController = TextEditingController(text: task?.title ?? '');
    _subjectController = TextEditingController(text: task?.subject ?? '');
    type = task?.type ?? 'Assignment';
    selectedDate = task?.dueDate ?? DateTime.now();
    selectedTime = task != null
        ? TimeOfDay.fromDateTime(task.dueDate)
        : const TimeOfDay(hour: 23, minute: 59);
    
    // Parse note and room from description
    String note = '';
    String room = '';
    if (task != null && task.description.isNotEmpty) {
      final parts = task.description.split('\n---ROOM---\n');
      note = parts[0];
      if (parts.length > 1) room = parts[1];
    }
    _noteController = TextEditingController(text: note);
    _roomController = TextEditingController(text: room);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _noteController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  String _buildDescription() {
    final note = _noteController.text.trim();
    final room = _roomController.text.trim();
    if (note.isEmpty && room.isEmpty) return '';
    if (room.isEmpty) return note;
    return '$note\n---ROOM---\n$room';
  }

  bool get _showRoomField => type == 'Exam' || type == 'Test';

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.taskToEdit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timetable = Provider.of<TimetableProvider>(context, listen: false);
    final savedSubjects = timetable.savedSubjects;
    
    // Filter subjects based on current input
    final subjectText = _subjectController.text.trim().toLowerCase();
    final filteredSubjects = savedSubjects.where((s) => 
      s.toLowerCase().contains(subjectText) && s.toLowerCase() != subjectText
    ).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 25, left: 20, right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEditing ? "Edit Task" : "Quick Add Task", 
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)
                  ),
                  if (isEditing)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                         Provider.of<TimetableProvider>(context, listen: false).deleteTask(widget.taskToEdit!.id);
                         Navigator.pop(context);
                      },
                    )
                ],
              ),
              const SizedBox(height: 20),
              
              // Task Title
              TextField(
                controller: _titleController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "What needs to be done?",
                  hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
                  filled: true, 
                  fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.edit_note, color: Colors.blueAccent),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 15),
              
              // Type Selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ["Assignment", "Homework", "Test", "Exam", "Project", "Other"].map((t) {
                    final isSelected = type == t;
                    Color chipColor = isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]!;
                    Color textColor = isDark ? Colors.white70 : Colors.black87;
                    
                    if (isSelected) {
                      if (t == 'Exam' || t == 'Test') chipColor = Colors.redAccent;
                      else if (t == 'Assignment') chipColor = Colors.indigoAccent;
                      else if (t == 'Homework') chipColor = Colors.teal;
                      else chipColor = Colors.blueAccent;
                      textColor = Colors.white;
                    }

                    String label = t;
                    if (t == 'Homework') label = 'H/W';

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        selectedColor: chipColor,
                        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                        labelStyle: TextStyle(color: textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                        onSelected: (bool selected) {
                          if (selected) setState(() => type = t);
                        },
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 15),

              // Subject Input with Autocomplete
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _subjectController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    onChanged: (val) => setState(() {
                      _showSubjectSuggestions = val.isNotEmpty;
                    }),
                    onTap: () => setState(() => _showSubjectSuggestions = true),
                    decoration: InputDecoration(
                      labelText: "Subject",
                      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      filled: true, 
                      fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      hintText: "e.g. Stats, Mobile Computing",
                      hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: savedSubjects.isNotEmpty 
                        ? IconButton(
                            icon: Icon(_showSubjectSuggestions ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                                 color: Colors.grey[400], size: 20),
                            onPressed: () => setState(() => _showSubjectSuggestions = !_showSubjectSuggestions),
                          )
                        : null,
                    ),
                  ),
                  if (_showSubjectSuggestions && filteredSubjects.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: filteredSubjects.length,
                        itemBuilder: (ctx, i) => InkWell(
                          onTap: () {
                            _subjectController.text = filteredSubjects[i];
                            setState(() => _showSubjectSuggestions = false);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Icon(Icons.history, size: 14, color: Colors.grey[400]),
                                const SizedBox(width: 10),
                                Text(filteredSubjects[i], style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 15),

              // Optional Room Field (Exams/Tests only)
              if (_showRoomField) ...[
                TextField(
                  controller: _roomController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: "Room (optional)",
                    labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    filled: true, 
                    fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    hintText: "e.g. NAC 2.12, LT1",
                    hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    prefixIcon: Icon(Icons.location_on_outlined, color: Colors.redAccent.withOpacity(0.7)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 15),
              ],

              // Note Field
              TextField(
                controller: _noteController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: "Note (optional)",
                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  filled: true, 
                  fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  hintText: "Add a note about this task...",
                  hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Icon(Icons.sticky_note_2_outlined, color: Colors.amber.withOpacity(0.7)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),

              const SizedBox(height: 15),

              // Date & Time Picker
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if(d != null) setState(() => selectedDate = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(DateFormat('MMM dd').format(selectedDate), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: selectedTime);
                        if(t != null) setState(() => selectedTime = t);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(selectedTime.format(context), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    final title = _titleController.text.trim();
                    final subject = _subjectController.text.trim().isEmpty 
                        ? 'General' 
                        : _subjectController.text.trim();
                    if(title.isNotEmpty) {
                      final dueDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                      final description = _buildDescription();
                      final provider = Provider.of<TimetableProvider>(context, listen: false);
                      
                      if (isEditing) {
                         provider.updateTask(
                           widget.taskToEdit!.id, title, subject, type, dueDateTime, widget.taskToEdit!.isCompleted,
                           description: description,
                         );
                      } else {
                         provider.addTask(title, subject, type, dueDateTime, description: description);
                      }
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF5C6BC0) : Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  child: Text(isEditing ? "Save Changes" : "Add to Board", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
