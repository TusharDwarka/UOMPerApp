import 'package:flutter/gestures.dart';
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
    // Desktop: calmer, tighter corners (phone keeps the big pebble cards).
    final shape = BorderRadius.circular(isDesktopPlatform ? (radius > 16 ? 16 : radius) : radius);
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
    final desk = isDesktopPlatform;
    return Padding(
      padding: desk ? padding.add(const EdgeInsets.only(top: 14, bottom: 6)) : padding,
      child: Row(
        crossAxisAlignment: desk ? CrossAxisAlignment.center : CrossAxisAlignment.end,
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
                        style: isDesktopPlatform
                            ? desktopSerif.copyWith(
                                color: p.textPrimary, fontSize: 28, height: 1.15, fontWeight: FontWeight.w400, letterSpacing: -0.4)
                            : TextStyle(
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
          ...actions.map((a) => Padding(padding: EdgeInsets.only(left: desk ? 4 : 8), child: a)),
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
    if (isDesktopPlatform) return _desktop(p);
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

  /// PC: a quiet 34px square ghost button (hover tint); the filled primary
  /// action becomes a compact ink button that spells out its tooltip.
  Widget _desktop(Palette p) {
    final s = size >= 40 ? 34.0 : size;
    final r = BorderRadius.circular(8);
    final enabled = onPressed != null;
    Widget button;
    if (filled && tooltip != null && size >= 40) {
      button = Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: p.ink,
          borderRadius: r,
          child: InkWell(
            borderRadius: r,
            hoverColor: p.onInk.withValues(alpha: 0.08),
            onTap: onPressed,
            child: SizedBox(
              height: s,
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 17, color: p.onInk),
                  const SizedBox(width: 6),
                  Text(tooltip!, style: TextStyle(color: p.onInk, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ),
      );
    } else {
      button = Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: filled ? p.ink : Colors.transparent,
          borderRadius: r,
          child: InkWell(
            borderRadius: r,
            onTap: onPressed,
            child: SizedBox(
              width: s,
              height: s,
              child: Icon(icon, size: s * 0.53, color: filled ? p.onInk : p.textSecondary),
            ),
          ),
        ),
      );
      if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    }
    if (badgeCount != null && badgeCount! > 0) {
      button = Stack(clipBehavior: Clip.none, children: [
        button,
        Positioned(
          right: -3,
          top: -3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(6)),
            child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ]);
    }
    return button;
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
    final desk = isDesktopPlatform;
    final OutlinedBorder shape = desk ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) : const StadiumBorder();
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: desk ? 16 : 18, color: fg), SizedBox(width: desk ? 6 : 8)],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: desk ? FontWeight.w600 : FontWeight.w700, fontSize: desk ? 13.5 : 15)),
        ),
      ],
    );
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          hoverColor: desk ? fg.withValues(alpha: 0.08) : null,
          onTap: onPressed,
          child: Padding(
              padding: desk
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                  : const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: child),
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
    if (isDesktopPlatform) return _desktop(p);
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

  /// PC: a compact, content-width tab strip (grey track, raised white
  /// selected tab) instead of a full-width black pill bar.
  Widget _desktop(Palette p) {
    Widget seg(T v) {
      final isSel = v == selected;
      final count = countOf?.call(v);
      return HoverTap(
        onTap: () => onChanged(v),
        builder: (hover) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSel ? p.surface : (hover ? p.textPrimary.withValues(alpha: 0.05) : p.surface.withValues(alpha: 0)),
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSel
                ? [
                    BoxShadow(color: p.border, spreadRadius: 0.5),
                    if (!p.isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 1)),
                  ]
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(labelOf(v),
                maxLines: 1,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                    color: isSel ? p.textPrimary : p.textSecondary)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: p.textMuted)),
            ],
          ]),
        ),
      );
    }

    final strip = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(9)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < values.length; i++)
          Padding(padding: EdgeInsets.only(left: i == 0 ? 0 : 2), child: seg(values[i])),
      ]),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: strip),
    );
  }
}

/// Click target with a hover flag and a pointer cursor (desktop controls).
class HoverTap extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget Function(bool hover) builder;
  const HoverTap({super.key, required this.onTap, required this.builder});

  @override
  State<HoverTap> createState() => _HoverTapState();
}

class _HoverTapState extends State<HoverTap> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: widget.builder(_hover)),
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
                style: isDesktopPlatform
                    ? TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.textPrimary, letterSpacing: -0.1)
                    : TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: p.textPrimary, letterSpacing: -0.4)),
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
        borderRadius: BorderRadius.circular(isDesktopPlatform ? 6 : 40),
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
              decoration: isDesktopPlatform
                  ? BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16), boxShadow: p.softShadow)
                  : BoxDecoration(color: p.surface, shape: BoxShape.circle, boxShadow: p.softShadow),
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
    if (isDesktopPlatform) return _desktop(context, p);
    return Container(
      decoration: BoxDecoration(color: p.surface, borderRadius: sheetRadius),
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

  Widget _desktop(BuildContext context, Palette p) {
    final pad = padding.resolve(Directionality.of(context));
    return Container(
      decoration: BoxDecoration(color: p.surface, borderRadius: sheetRadius),
      padding: EdgeInsets.fromLTRB(pad.left, 18, pad.right, pad.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: desktopSerif.copyWith(fontSize: 21, color: p.textPrimary, letterSpacing: -0.2)),
                ),
                ...actions,
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Close (Esc)',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: SizedBox(width: 30, height: 30, child: Icon(Icons.close_rounded, size: 18, color: p.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// Drop-in for [showModalBottomSheet]. Phones get the exact same bottom
/// sheet; desktop gets a centred dialog card (fade + slight scale) sized for
/// a mouse-and-keyboard window instead of a slab rising from the bottom.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  double desktopWidth = 560,
}) {
  if (!isDesktopPlatform) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      builder: builder,
    );
  }
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, a1, a2) {
      final size = MediaQuery.sizeOf(ctx);
      final maxH = (size.height - 64).clamp(240.0, 820.0);
      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: desktopWidth.clamp(0, size.width - 48), maxHeight: maxH),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: sheetRadius,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 32, offset: const Offset(0, 10)),
                ],
              ),
              child: ClipRRect(
                borderRadius: sheetRadius,
                child: Material(type: MaterialType.transparency, child: Builder(builder: builder)),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: const Cubic(0.23, 1, 0.32, 1), reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(curved), child: child),
      );
    },
  );
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

/// Rounded option sheet used instead of dropdown menus (which rendered as
/// square boxes). The selected option is a black pill with a tick.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required T? selected,
  required String Function(T) labelOf,
  String? Function(T)? subtitleOf,
  IconData? Function(T)? iconOf,
  BuildContext? anchor,
}) {
  if (isDesktopPlatform && anchor != null) {
    return _showChoiceMenu<T>(context, anchor,
        options: options, selected: selected, labelOf: labelOf, subtitleOf: subtitleOf, iconOf: iconOf);
  }
  if (isDesktopPlatform) {
    // No control to drop down from: a small titled picker dialog.
    return showAppSheet<T>(
      context: context,
      desktopWidth: 440,
      builder: (ctx) {
        final p = Palette.of(ctx);
        return SheetScaffold(
          title: title,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final o in options)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.pop(ctx, o),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Row(
                      children: [
                        if (iconOf?.call(o) != null) ...[
                          Icon(iconOf!(o), size: 18, color: p.textSecondary),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(labelOf(o),
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: o == selected ? FontWeight.w600 : FontWeight.w500,
                                      color: p.textPrimary)),
                              if (subtitleOf?.call(o) != null)
                                Text(subtitleOf!(o)!, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                            ],
                          ),
                        ),
                        if (o == selected) Icon(Icons.check_rounded, size: 18, color: p.textPrimary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final p = Palette.of(ctx);
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        child: SheetScaffold(
          title: title,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final o in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: o == selected ? p.ink : p.surfaceAlt,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => Navigator.pop(ctx, o),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        child: Row(
                          children: [
                            if (iconOf?.call(o) != null) ...[
                              Icon(iconOf!(o), size: 20, color: o == selected ? p.onInk : p.textSecondary),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(labelOf(o),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 15, color: o == selected ? p.onInk : p.textPrimary)),
                                  if (subtitleOf?.call(o) != null)
                                    Text(subtitleOf!(o)!,
                                        style: TextStyle(
                                            fontSize: 12, color: (o == selected ? p.onInk : p.textSecondary).withValues(alpha: 0.75))),
                                ],
                              ),
                            ),
                            if (o == selected) Icon(Icons.check_rounded, color: p.onInk, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Desktop dropdown: a rounded popup menu under the control that opened it
/// (or centred on it when nothing anchors it).
Future<T?> _showChoiceMenu<T>(
  BuildContext context,
  BuildContext? anchor, {
  required List<T> options,
  required T? selected,
  required String Function(T) labelOf,
  String? Function(T)? subtitleOf,
  IconData? Function(T)? iconOf,
}) {
  final p = Palette.of(context);
  final box = anchor?.findRenderObject() as RenderBox?;
  final overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
  final RelativeRect position;
  double minWidth = 200;
  if (box != null && box.hasSize) {
    final topLeft = box.localToGlobal(Offset(0, box.size.height + 4), ancestor: overlay);
    final bottomRight = box.localToGlobal(box.size.bottomRight(const Offset(0, 4)), ancestor: overlay);
    position = RelativeRect.fromRect(Rect.fromPoints(topLeft, bottomRight), Offset.zero & overlay.size);
    if (box.size.width > minWidth && box.size.width < 420) minWidth = box.size.width;
  } else {
    final c = overlay.size.center(Offset.zero);
    position = RelativeRect.fromRect(Rect.fromCenter(center: c, width: 1, height: 1), Offset.zero & overlay.size);
  }
  return showMenu<T>(
    context: context,
    position: position,
    constraints: BoxConstraints(minWidth: minWidth, maxWidth: 420),
    menuPadding: const EdgeInsets.symmetric(vertical: 4),
    popUpAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 140)),
    items: [
      for (final o in options)
        PopupMenuItem<T>(
          value: o,
          height: subtitleOf?.call(o) != null ? 48 : 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (iconOf?.call(o) != null) ...[
                Icon(iconOf!(o), size: 17, color: p.textSecondary),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(labelOf(o),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: o == selected ? FontWeight.w600 : FontWeight.w400,
                            color: p.textPrimary)),
                    if (subtitleOf?.call(o) != null)
                      Text(subtitleOf!(o)!,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
                  ],
                ),
              ),
              if (o == selected) ...[const SizedBox(width: 8), Icon(Icons.check_rounded, size: 16, color: p.textPrimary)],
            ],
          ),
        ),
    ],
  );
}

/// Compact rounded "value ⌄" pill that opens [showChoiceSheet].
class ChoicePill<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final IconData? Function(T)? iconOf;

  const ChoicePill({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final desk = isDesktopPlatform;
    final OutlinedBorder shape = desk ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) : const StadiumBorder();
    return Material(
      color: p.surfaceAlt,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: () async {
          final picked = await showChoiceSheet<T>(context,
              title: title, options: options, selected: value, labelOf: labelOf, iconOf: iconOf, anchor: context);
          if (picked != null && picked != value) onChanged(picked);
        },
        child: Padding(
          padding: desk ? const EdgeInsets.fromLTRB(12, 6, 6, 6) : const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(labelOf(value), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: desk ? FontWeight.w600 : FontWeight.w700, fontSize: desk ? 13.5 : null, color: p.textPrimary)),
              ),
              Icon(desk ? Icons.unfold_more_rounded : Icons.expand_more_rounded, size: desk ? 16 : 20, color: p.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mon–Sun selector: seven round day buttons, selected one is black.
class WeekdayPicker extends StatelessWidget {
  final String selected; // "Monday"…"Sunday"
  final ValueChanged<String> onChanged;
  const WeekdayPicker({super.key, required this.selected, required this.onChanged});

  static const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Semantics(
                button: true,
                selected: d == selected,
                label: d,
                child: GestureDetector(
                  onTap: () => onChanged(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: d == selected ? p.ink : p.surfaceAlt, shape: BoxShape.circle),
                    child: Text(d.substring(0, 2),
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: d == selected ? p.onInk : p.textPrimary)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Wide desktop pages: show panes side by side instead of one long phone
/// scroll. True only on Windows/macOS/Linux with room for two columns.
bool wideDesktop(BoxConstraints c) => isDesktopPlatform && c.maxWidth >= 900;

/// Desktop two-pane body: a main pane and a side pane, each scrolling on
/// its own so every control stays reachable without scrolling the page.
class SplitPanes extends StatelessWidget {
  final Widget main;
  final Widget side;
  final String? sideTitle;
  final Widget? sideTrailing;
  final int mainFlex;
  final int sideFlex;

  /// Draw the side pane as a quiet bordered panel.
  final bool sidePanel;
  final EdgeInsetsGeometry padding;

  const SplitPanes({
    super.key,
    required this.main,
    required this.side,
    this.sideTitle,
    this.sideTrailing,
    this.mainFlex = 3,
    this.sideFlex = 2,
    this.sidePanel = true,
    this.padding = const EdgeInsets.fromLTRB(8, 4, 20, 16),
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget right = side;
    if (sideTitle != null) {
      right = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 4),
            child: Row(children: [
              Expanded(
                child: Text(sideTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.textPrimary)),
              ),
              if (sideTrailing != null) sideTrailing!,
            ]),
          ),
          Expanded(child: side),
        ],
      );
    }
    if (sidePanel) {
      right = Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: p.isDark ? p.surface : p.sidebar,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border),
        ),
        child: right,
      );
    }
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: mainFlex, child: main),
          const SizedBox(width: 16),
          Expanded(flex: sideFlex, child: right),
        ],
      ),
    );
  }
}

/// App scroll behaviour. On PC a plain mouse wheel over a sideways row
/// (chips, route pills, cards) scrolls that row; without this only
/// Shift+wheel could. Phones get the stock Material behaviour.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    final base = super.buildOverscrollIndicator(context, child, details);
    if (!isDesktopPlatform || axisDirectionToAxis(details.direction) != Axis.horizontal) return base;
    final controller = details.controller;
    if (controller == null) return base;
    return _WheelScrollsSideways(controller: controller, child: base);
  }
}

class _WheelScrollsSideways extends StatelessWidget {
  final ScrollController controller;
  final Widget child;
  const _WheelScrollsSideways({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        final d = event.scrollDelta;
        if (d.dy.abs() <= d.dx.abs()) return; // real sideways scroll: Scrollable handles it
        // This wraps the row's Scrollable from outside, so use its own
        // controller (Scrollable.maybeOf here would find a parent list).
        if (!controller.hasClients || controller.positions.length != 1) return;
        final pos = controller.position;
        if (!pos.hasContentDimensions) return;
        final target = (pos.pixels + d.dy).clamp(pos.minScrollExtent, pos.maxScrollExtent);
        if (target == pos.pixels) return; // at an end: let the page scroll instead
        GestureBinding.instance.pointerSignalResolver.register(event, (_) => pos.jumpTo(target));
      },
      child: child,
    );
  }
}
