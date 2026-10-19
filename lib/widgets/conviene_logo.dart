import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ConvieneLogo extends StatelessWidget {
  const ConvieneLogo({super.key, this.compact = false, this.centered = false});

  final bool compact;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 86.0 : 190.0;
    final height = compact ? 44.0 : 126.0;

    return Align(
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/brand/conviene_logo.png',
              fit: BoxFit.contain,
              semanticLabel: 'Conviene',
            ),
            if (Theme.of(context).brightness == Brightness.dark)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: AppColors.background,
                  child: Text(
                    'conviene',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: compact ? 12 : 28,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
