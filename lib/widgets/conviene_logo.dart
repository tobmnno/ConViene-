import 'package:flutter/material.dart';

class ConvieneLogo extends StatelessWidget {
  const ConvieneLogo({super.key, this.compact = false, this.centered = false});

  final bool compact;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 86.0 : 190.0;
    final height = compact ? 52.0 : 126.0;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            dark
                ? 'assets/brand/conviene_logo.png'
                : 'assets/brand/conviene_logo_source.png',
            fit: BoxFit.cover,
            semanticLabel: 'Conviene',
          ),
        ),
      ),
    );
  }
}
