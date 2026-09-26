import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/academic_task.dart';
import '../providers/focus_provider.dart';
import '../providers/timetable_provider.dart';
import '../theme/app_theme.dart';
import '../utils/meeting_links.dart';
import '../utils/time_utils.dart';
import '../widgets/add_edit_task_sheet.dart';
import '../widgets/ui.dart';
import 'home_screen.dart' show HomeNavigation, AppPage;
import 'print_center_screen.dart';

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
        persist: false, // Flutter keeps action snackbars forever by default
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
      persist: false, // Flutter keeps action snackbars forever by default
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
            if (t.effectiveStatus != TaskStatus.done && t.syncId != null)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Focus on this'),
                subtitle: const Text('Start a focus session linked to this task'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<FocusProvider>().setTask(t.syncId, t.title, subject: t.subject);
                  if (t.effectiveStatus == TaskStatus.todo) _move(t, TaskStatus.doing);
                  HomeNavigation.of(context, AppPage.focus);
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
                CircleIconButton(
                  icon: Icons.print_rounded,
                  tooltip: 'Print & export',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrintCenterScreen())),
                ),
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
                  Builder(builder: (context) {
                    final spent = context.select<FocusProvider, int>((f) => f.minutesForTask(t.syncId));
                    if (spent == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text('⏱ ${spent >= 60 ? '${spent ~/ 60}h ${spent % 60}m' : '${spent}m'}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.textSecondary)),
                    );
                  }),
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
