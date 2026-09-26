import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Big rounded white card from the design references.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BoxBorder? border;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.color,
    this.radius = 28,
    this.onTap,
    this.onLongPress,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final shape = BorderRadius.circular(radius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: shape,
        boxShadow: color == null ? p.softShadow : null,
        border: border,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Oversized, light-weight screen title ("Time Average", "All Classes").
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final Widget? badge;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  const ScreenHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.badge,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(eyebrow!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 34,
                          height: 1.1,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ),
                    if (badge != null) Padding(padding: const EdgeInsets.only(left: 6, top: 2), child: badge!),
                  ],
                ),
              ],
            ),
          ),
          ...actions.map((a) => Padding(padding: const EdgeInsets.only(left: 8), child: a)),
        ],
      ),
    );
  }
}

/// Small superscript count next to a big title, e.g. "Board (12)".
class CountBadge extends StatelessWidget {
  final int count;
  const CountBadge(this.count, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text('($count)',
        style: TextStyle(color: Palette.of(context).textPrimary, fontSize: 14, fontWeight: FontWeight.w500));
  }
}

/// White circular icon button (the design's round nav/action buttons).
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final bool filled;
  final int? badgeCount;

  const CircleIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 46,
    this.filled = false,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final bg = filled ? p.ink : p.surface;
    final fg = filled ? p.onInk : p.textPrimary;
    Widget button = Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(width: size, height: size, child: Icon(icon, size: size * 0.46, color: fg)),
      ),
    );
    if (badgeCount != null && badgeCount! > 0) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(10)),
              child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      );
    }
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Black stadium button with optional icon.
class InkPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool accent;
  final bool expand;

  const InkPillButton({super.key, required this.label, this.icon, this.onPressed, this.accent = false, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final bg = accent ? p.accent : p.ink;
    final fg = accent ? Colors.white : p.onInk;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ],
    );
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), child: child),
        ),
      ),
    );
  }
}

/// Pill-shaped segmented control. The selected segment is a black pill.
class PillSegmented<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final int? Function(T)? countOf;
  final bool scrollable;

  const PillSegmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.countOf,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget seg(T v) {
      final isSel = v == selected;
      final count = countOf?.call(v);
      final label = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(labelOf(v), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isSel ? p.onInk : p.textSecondary)),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSel ? p.onInk.withValues(alpha: 0.18) : p.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isSel ? p.onInk : p.textSecondary)),
            ),
          ],
        ],
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: isSel ? p.ink : Colors.transparent, borderRadius: BorderRadius.circular(40)),
          child: label,
        ),
      );
    }

    final container = BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(40), boxShadow: p.softShadow);
    if (scrollable) {
      return Container(
        decoration: container,
        padding: const EdgeInsets.all(4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: values.map(seg).toList()),
        ),
      );
    }
    return Container(
      decoration: container,
      padding: const EdgeInsets.all(4),
      child: Row(children: values.map((v) => Expanded(child: seg(v))).toList()),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  const SectionLabel(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 8, 4, 12)});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: p.textPrimary, letterSpacing: -0.4)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small rounded label, e.g. "In Progress", "2h 47min".
class TagPill extends StatelessWidget {
  final String text;
  final Color? color;
  final bool outlined;
  final IconData? icon;
  const TagPill(this.text, {super.key, this.color, this.outlined = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = color ?? p.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : c.withValues(alpha: 0.12),
        border: outlined ? Border.all(color: c, width: 1.2) : null,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
          Flexible(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    // Centred when there's room; scrolls when the keyboard leaves little space.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0),
          child: Center(child: _content(p)),
        ),
      ),
    );
  }

  Widget _content(Palette p) {
    return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle, boxShadow: p.softShadow),
              child: Icon(icon, size: 32, color: p.textMuted),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary)),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      );
  }
}

/// Rounded top sheet container with a drag handle; used by all bottom sheets.
class SheetScaffold extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;
  const SheetScaffold({super.key, required this.child, this.title, this.actions = const [], this.padding = const EdgeInsets.fromLTRB(22, 10, 22, 22)});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      decoration: BoxDecoration(color: p.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(4))),
              ),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: -0.6, color: p.textPrimary)),
                      ),
                      ...actions,
                    ],
                  ),
                ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmation dialog helper for destructive actions.
Future<bool> confirmDestructive(BuildContext context, {required String title, required String message, String action = 'Delete'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Shows a dialog whose [TextEditingController] lives exactly as long as the
/// dialog. Disposing a controller right after `await showDialog` crashes,
/// because the closing animation still rebuilds the TextField.
Future<T?> showControllerDialog<T>(
  BuildContext context, {
  String initial = '',
  required Widget Function(BuildContext context, TextEditingController controller) builder,
}) {
  return showDialog<T>(context: context, builder: (_) => _ControllerHost(initial: initial, builder: builder));
}

class _ControllerHost extends StatefulWidget {
  final String initial;
  final Widget Function(BuildContext, TextEditingController) builder;
  const _ControllerHost({required this.initial, required this.builder});

  @override
  State<_ControllerHost> createState() => _ControllerHostState();
}

class _ControllerHostState extends State<_ControllerHost> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
