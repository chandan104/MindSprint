import 'package:flutter/material.dart';

/// Shrinking time bar (prototype's exposure countdown). Purely visual —
/// gameplay timing comes from the module's timers, never from this widget.
class CountdownBar extends StatefulWidget {
  final Duration duration;
  final Color color;

  const CountdownBar({super.key, required this.duration, required this.color});

  @override
  State<CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<CountdownBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 192,
      height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: 1 - _controller.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}
