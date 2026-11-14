import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Breakpoints + content width limits so layouts read well from small phones
/// (320dp) up to tablets/foldables, instead of stretching edge to edge.
class Breakpoints {
  Breakpoints._();
  static const double compact = 360; // below this: tighter gutters
  static const double content = 640; // max width for reading content
  static const double controls = 440; // max width for camera control rows
}

/// Centers [child] and caps its width; full width on phones.
class ResponsiveCenter extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const ResponsiveCenter({super.key, this.maxWidth = Breakpoints.content, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Side gutter that tightens on very narrow screens.
double pageGutter(BuildContext context) =>
    MediaQuery.sizeOf(context).width < Breakpoints.compact ? AppSpacing.lg : AppSpacing.gutter;

/// Small uppercase label that introduces a group of content.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: context.text.overline)),
          ?trailing,
        ],
      ),
    );
  }
}

/// A single rounded surface holding rows separated by hairlines
/// (one container instead of a stack of cards).
class GroupedSection extends StatelessWidget {
  final List<Widget> children;
  const GroupedSection({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) items.add(const Divider(indent: AppSpacing.lg));
      items.add(children[i]);
    }
    // A Material (not a decorated Container) so ink ripples of tappable rows
    // such as ExpansionTile render on the surface instead of underneath it.
    return Material(
      color: context.palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: context.palette.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: items),
    );
  }
}

/// Status dot; [pulse] gives a soft breathing animation (used for "live").
class StatusDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool pulse;
  const StatusDot({super.key, required this.color, this.size = 8, this.pulse = false});

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.pulse && _c.isAnimating) {
      _c.stop();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (!widget.pulse) return dot;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: dot,
    );
  }
}

/// Round translucent button for controls drawn on top of the camera.
class CameraChromeButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  const CameraChromeButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.38),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}

/// Translucent pill used for short status text over the camera.
class CameraPill extends StatelessWidget {
  final Widget child;
  final Color? color;
  const CameraPill({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: color ?? Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(15),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          fontFeatures: AppText.tabular,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [child]),
      ),
    );
  }
}

/// Vertical fade used behind camera chrome so controls stay legible.
class CameraScrim extends StatelessWidget {
  final bool top;
  final double height;
  const CameraScrim({super.key, this.top = true, this.height = 140});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
