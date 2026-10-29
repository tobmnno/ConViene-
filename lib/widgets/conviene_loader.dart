import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'conviene_logo.dart';

class ConvieneLoader extends StatefulWidget {
  const ConvieneLoader({
    super.key,
    this.compact = false,
    this.message = 'Cargando',
    this.active = true,
  });
  final bool compact;
  final bool active;
  final String message;
  @override
  State<ConvieneLoader> createState() => _ConvieneLoaderState();
}

class _ConvieneLoaderState extends State<ConvieneLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _delay;
  bool _visible = false;
  bool _motion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _schedule();
  }

  void _schedule() {
    _delay?.cancel();
    _visible = false;
    if (!widget.active) return;
    _delay = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _visible = true);
      _sync();
    });
  }

  void _sync() {
    if (_visible && widget.active && _motion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(ConvieneLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _schedule();
      _sync();
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.compact ? 48 : 166,
    child: Visibility(
      visible: _visible && widget.active,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Semantics(
        label: widget.message,
        liveRegion: true,
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final phase = _motion
                  ? math.sin(_controller.value * math.pi * 2)
                  : 0.0;
              final mark = Transform.translate(
                offset: Offset(0, phase * 2),
                child: SizedBox(
                  width: widget.compact ? 58 : 100,
                  height: widget.compact ? 36 : 70,
                  child: const FittedBox(
                    child: ConvieneLogo(compact: true, centered: true),
                  ),
                ),
              );
              final accent = SizedBox(
                width: widget.compact ? 32 : 96,
                height: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .15),
                    child: Align(
                      alignment: Alignment(phase * .8, 0),
                      child: FractionallySizedBox(
                        widthFactor: .35,
                        child: ColoredBox(
                          color: Color.lerp(
                            const Color(0xFF0057FF),
                            const Color(0xFF13C878),
                            (phase + 1) / 2,
                          )!,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              if (widget.compact)
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    mark,
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    accent,
                  ],
                );
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  mark,
                  const SizedBox(height: 8),
                  accent,
                  const SizedBox(height: 14),
                  Text(widget.message, textAlign: TextAlign.center),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
