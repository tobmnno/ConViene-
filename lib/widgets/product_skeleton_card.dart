import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_card.dart';

class ProductSkeletonCard extends StatefulWidget {
  const ProductSkeletonCard({super.key});

  @override
  State<ProductSkeletonCard> createState() => _ProductSkeletonCardState();
}

class _ProductSkeletonCardState extends State<ProductSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!active && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    return Semantics(
      label: 'Cargando producto',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final color = Color.lerp(
              AppColors.line,
              AppColors.softBlue,
              still ? 0.3 : _pulse.value,
            )!;
            Widget bone(double width, double height) => Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            );
            return AppCard(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: SizedBox(
                height: 104,
                child: Row(
                  children: [
                    bone(74, 74),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          bone(70, 12),
                          const SizedBox(height: 12),
                          FractionallySizedBox(
                            widthFactor: 0.84,
                            alignment: Alignment.centerLeft,
                            child: bone(double.infinity, 14),
                          ),
                          const SizedBox(height: 8),
                          FractionallySizedBox(
                            widthFactor: 0.58,
                            alignment: Alignment.centerLeft,
                            child: bone(double.infinity, 12),
                          ),
                          const SizedBox(height: 12),
                          bone(92, 17),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
