import 'package:flutter/material.dart';

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
        child: Image.asset(
          'assets/brand/conviene_logo.png',
          fit: BoxFit.contain,
          semanticLabel: 'Conviene',
        ),
      ),
    );
  }
}
