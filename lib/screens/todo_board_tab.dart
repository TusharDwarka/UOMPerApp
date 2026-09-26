import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/academic_task.dart';
import '../providers/timetable_provider.dart';
import '../theme/app_theme.dart';
import '../utils/meeting_links.dart';
import '../utils/time_utils.dart';
import '../widgets/add_edit_task_sheet.dart';
import '../widgets/ui.dart';

/// Kanban board: To Do → In Progress → Done.
///
/// There is deliberately no swipe-to-delete (it was far too easy to trigger
/// while scrolling). On phones, swiping moves between columns; deleting is
/// in the card menu and always offers Undo.
class TodoBoardTab extends StatefulWidget {
  const TodoBoardTab({super.key});

  @override
  State<TodoBoardTab> createState() => _TodoBoardTabState();
}

enum _Filter { all, exams, assignments, highPriority }

class _TodoBoardTabState extends State<TodoBoardTab> {
  final _pageController = PageController();
  int _column = 0;
  _Filter _filter = _Filter.all;
  String? _hoverColumn;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _matches(AcademicTask t) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.exams:
        return t.type == 'Exam' || t.type == 'Test';
      case _Filter.assignments:
        return t.type == 'Assignment' || t.type == 'Project' || t.type == 'Homework';
      case _Filter.highPriority:
        return (t.priority ?? 1) >= 2;
    }
  }

  List<AcademicTask> _columnTasks(TimetableProvider tp, String status) {
    final list = tp.tasksWithStatus(status).where(_matches).toList();
    if (status == TaskStatus.done) {
      list.sort((a, b) => (b.updatedAt ?? b.dueDate).compareTo(a.updatedAt ?? a.dueDate));
    } else {
      list.sort((a, b) {
        final p = (b.priority ?? 1).compareTo(a.priority ?? 1);
        return p != 0 ? p : a.dueDate.compareTo(b.dueDate);
      });
    }
    return list;
  }

  void _goToColumn(int i) {
    setState(() => _column = i);
    if (_pageController.hasClients) {
      _pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _move(AcademicTask t, String status) async {
    if (t.effectiveStatus == status) return;
    final tp = context.read<TimetableProvider>();
    final previous = t.effectiveStatus;
    await tp.setTaskStatus(t, status);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Moved to ${TaskStatus.label(status)}'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(label: 'Undo', onPressed: () => tp.setTaskStatus(t, previous)),
      ));
  }

  Future<void> _clearDone(List<AcademicTask> done) async {
    if (done.isEmpty) return;
    final ok = await confirmDestructive(context,
        title: 'Clear completed?', message: 'Delete ${done.length} completed item${done.length == 1 ? '' : 's'}?', action: 'Clear');
    if (!ok || !mounted) return;
    final tp = context.read<TimetableProvider>();
    final removed = <AcademicTask>[];
    for (final t in done) {
      final r = await tp.deleteTask(t.id);
      if (r != null) removed.add(r);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Cleared ${removed.length} items'),
      action: SnackBarAction(label: 'Undo', onPressed: () async {
        for (final r in removed) {
          await tp.restoreTask(r);
        }
      }),
    ));
  }

  void _showCardMenu(AcademicTask t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SheetScaffold(
        title: t.title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in TaskStatus.all)
              if (s != t.effectiveStatus)
                ListTile(
                  leading: Icon(_statusIcon(s)),
                  title: Text('Move to ${TaskStatus.label(s)}'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _move(t, s);
                  },
                ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                showTaskSheet(context, task: t);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await confirmDestructive(context, title: 'Delete?', message: 'Delete "${t.title}"?');
                if (ok && mounted) await deleteTaskWithUndo(context, t);
              },
            ),
          ],
        ),
      ),
    );
  }

  static IconData _statusIcon(String s) {
    switch (s) {
      case TaskStatus.doing:
        return Icons.timelapse_rounded;
      case TaskStatus.done:
        return Icons.check_circle_rounded;
      default:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final tp = context.watch<TimetableProvider>();
    final columns = {for (final s in TaskStatus.all) s: _columnTasks(tp, s)};
    final wide = MediaQuery.of(context).size.width >= 720;
    final openCount = columns[TaskStatus.todo]!.length + columns[TaskStatus.doing]!.length;

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Board',
              badge: CountBadge(openCount),
              eyebrow: 'Your to-dos, deadlines & exams',
              actions: [
                CircleIconButton(icon: Icons.ios_share_rounded, tooltip: 'Share / print', onPressed: _showPrintMenu),
                CircleIconButton(
                  icon: Icons.add_rounded,
                  filled: true,
                  tooltip: 'Add',
                  onPressed: () => showTaskSheet(context, initialStatus: TaskStatus.all[_column]),
                ),
              ],
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final f in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Text(const {
                          _Filter.all: 'All',
                          _Filter.exams: 'Exams & tests',
                          _Filter.assignments: 'Coursework',
                          _Filter.highPriority: 'High priority',
                        }[f]!),
                        selected: _filter == f,
                        selectedColor: p.ink,
                        backgroundColor: p.surface,
                        labelStyle: TextStyle(color: _filter == f ? p.onInk : p.textPrimary, fontWeight: FontWeight.w600),
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: tp.tasks.isEmpty
                  ? EmptyState(
                      icon: Icons.view_kanban_rounded,
                      title: 'Nothing on the board',
                      subtitle: 'Add assignments, exams and to-dos, then drag them across as you go.',
                      action: InkPillButton(label: 'Add first task', icon: Icons.add, onPressed: () => showTaskSheet(context)),
                    )
                  : wide
                      ? _buildWide(p, columns)
                      : _buildNarrow(p, columns),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWide(Palette p, Map<String, List<AcademicTask>> columns) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in TaskStatus.all)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _dropTarget(
                  s,
                  Container(
                    decoration: BoxDecoration(
                      color: _hoverColumn == s ? p.accentSoft : p.surfaceAlt.withValues(alpha: p.isDark ? 0.5 : 0.7),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        _columnHeader(p, s, columns[s]!),
                        const SizedBox(height: 8),
                        Expanded(child: _cardList(columns[s]!, draggable: true)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNarrow(Palette p, Map<String, List<AcademicTask>> columns) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: _dropTarget(
                    TaskStatus.all[i],
                    GestureDetector(
                      onTap: () => _goToColumn(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: _hoverColumn == TaskStatus.all[i]
                              ? p.accent
                              : (_column == i ? p.ink : p.surface),
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: _column == i ? null : p.softShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                TaskStatus.label(TaskStatus.all[i]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _column == i || _hoverColumn == TaskStatus.all[i] ? p.onInk : p.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text('${columns[TaskStatus.all[i]]!.length}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: _column == i ? p.onInk.withValues(alpha: 0.7) : p.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 2),
          child: Row(
            children: [
              Icon(Icons.swipe_rounded, size: 14, color: p.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Swipe to switch columns · hold a card to drag it onto a column',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: p.textMuted)),
              ),
              if (_column == 2 && columns[TaskStatus.done]!.isNotEmpty)
                TextButton(onPressed: () => _clearDone(columns[TaskStatus.done]!), child: const Text('Clear')),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _column = i),
            children: [
              for (final s in TaskStatus.all)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _cardList(columns[s]!, draggable: true, emptyStatus: s),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _columnHeader(Palette p, String status, List<AcademicTask> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
      child: Row(
        children: [
          Icon(_statusIcon(status), size: 18, color: p.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(TaskStatus.label(status),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.textPrimary)),
          ),
          Text('${items.length}', style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w700)),
          if (status == TaskStatus.done && items.isNotEmpty)
            IconButton(
                tooltip: 'Clear completed', icon: const Icon(Icons.clear_all_rounded, size: 20), onPressed: () => _clearDone(items))
          else
            IconButton(
              tooltip: 'Add here',
              icon: const Icon(Icons.add_rounded, size: 20),
              onPressed: () => showTaskSheet(context, initialStatus: status),
            ),
        ],
      ),
    );
  }

  Widget _dropTarget(String status, Widget child) {
    return DragTarget<AcademicTask>(
      onWillAcceptWithDetails: (d) {
        final ok = d.data.effectiveStatus != status;
        if (ok) setState(() => _hoverColumn = status);
        return ok;
      },
      onLeave: (_) => setState(() => _hoverColumn = null),
      onAcceptWithDetails: (d) {
        setState(() => _hoverColumn = null);
        _move(d.data, status);
      },
      builder: (context, _, __) => child,
    );
  }

  Widget _cardList(List<AcademicTask> items, {required bool draggable, String? emptyStatus}) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyStatus == TaskStatus.done ? 'Finished items land here' : 'Nothing here',
            style: TextStyle(color: Palette.of(context).textMuted),
          ),
        ),
      );
    }
    final desktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final t = items[i];
        final card = _TaskCard(
          task: t,
          onTap: () => showTaskSheet(context, task: t),
          onMenu: () => _showCardMenu(t),
          onAdvance: t.effectiveStatus == TaskStatus.done
              ? null
              : () => _move(t, t.effectiveStatus == TaskStatus.todo ? TaskStatus.doing : TaskStatus.done),
        );
        if (!draggable) return card;
        final feedback = Material(
          color: Colors.transparent,
          child: SizedBox(width: 300, child: Opacity(opacity: 0.9, child: card)),
        );
        return desktop
            ? Draggable<AcademicTask>(data: t, feedback: feedback, childWhenDragging: Opacity(opacity: 0.3, child: card), child: card)
            : LongPressDraggable<AcademicTask>(
                data: t, feedback: feedback, childWhenDragging: Opacity(opacity: 0.3, child: card), child: card);
      },
    );
  }

  // ═══════════════════════════════════════════
  // SHARE / PRINT (unchanged export logic)
  // ═══════════════════════════════════════════
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
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.blue.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.1)),
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
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.green.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.green.withValues(alpha: 0.1)),
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
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
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

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final taskDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
            final daysUntil = taskDate.difference(today).inDays;
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
}

class _TaskCard extends StatelessWidget {
  final AcademicTask task;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final VoidCallback? onAdvance;

  const _TaskCard({required this.task, required this.onTap, required this.onMenu, this.onAdvance});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = task;
    final color = t.colorValue != null ? Color(t.colorValue!) : AppColors.forType(t.type);
    final done = t.effectiveStatus == TaskStatus.done;

    var room = '';
    if (t.description.contains('\n---ROOM---\n')) room = t.description.split('\n---ROOM---\n')[1];

    final today = dateOnly(DateTime.now());
    final daysUntil = dateOnly(t.dueDate).difference(today).inDays;
    String? urgency;
    Color? urgencyColor;
    if (!done) {
      if (daysUntil < 0) {
        urgency = 'Overdue';
        urgencyColor = Colors.red;
      } else if (daysUntil == 0) {
        urgency = 'Today';
        urgencyColor = Colors.redAccent;
      } else if (daysUntil == 1) {
        urgency = 'Tomorrow';
        urgencyColor = Colors.orange;
      } else if (daysUntil <= 3) {
        urgency = '${daysUntil}d left';
        urgencyColor = Colors.amber[800];
      }
    }

    final dateText = t.isSpanning
        ? '${DateFormat('d MMM').format(t.startDate!)} – ${DateFormat('d MMM').format(t.dueDate)}'
        : DateFormat('EEE d MMM, HH:mm').format(t.dueDate);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 14, 6, 12),
        onTap: onTap,
        onLongPress: null,
        child: Opacity(
          opacity: done ? 0.6 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(flex: 0, child: TagPill(t.type, color: color)),
                  if ((t.priority ?? 1) >= 2) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.flag_rounded, size: 16, color: Colors.redAccent),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.subject == 'General' ? '' : t.subject,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                  if (urgency != null) Flexible(child: TagPill(urgency, color: urgencyColor)),
                  SizedBox(
                    width: 36,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'More',
                      icon: Icon(Icons.more_vert_rounded, size: 20, color: p.textSecondary),
                      onPressed: onMenu,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  t.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(t.isSpanning ? Icons.date_range_rounded : Icons.schedule_rounded, size: 14, color: p.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(dateText, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.textSecondary)),
                  ),
                  if (room.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.location_on_outlined, size: 14, color: p.textSecondary),
                    Flexible(
                      child: Text(room, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: p.textSecondary)),
                    ),
                  ],
                  const Spacer(),
                  if (onAdvance != null)
                    Tooltip(
                      message: t.effectiveStatus == TaskStatus.todo ? 'Start' : 'Mark done',
                      child: Material(
                        color: p.ink,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onAdvance,
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: Icon(
                              t.effectiveStatus == TaskStatus.todo ? Icons.play_arrow_rounded : Icons.check_rounded,
                              size: 18,
                              color: p.onInk,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
              if (t.meetingLink != null && !done) ...[
                const SizedBox(height: 10),
                JoinMeetingButton(url: t.meetingLink!, dense: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
