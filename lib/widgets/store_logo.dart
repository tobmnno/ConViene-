import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/supermarket.dart';

class StoreLogo extends StatelessWidget {
  const StoreLogo({super.key, required this.supermarket, this.size = 44});

  final Supermarket supermarket;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (supermarket.logoAsset.isNotEmpty) {
      final isSvg = supermarket.logoAsset.toLowerCase().endsWith('.svg');
      final logo = isSvg
          ? SvgPicture.asset(
              supermarket.logoAsset,
              fit: BoxFit.contain,
              semanticsLabel: supermarket.name,
            )
          : Image.asset(
              supermarket.logoAsset,
              fit: BoxFit.contain,
              semanticLabel: supermarket.name,
            );
      final width = supermarket.id == 'carrefour' ? size : size * 1.7;

      return SizedBox(
        width: width,
        height: size,
        child: Center(
          child: Padding(padding: EdgeInsets.all(size * 0.04), child: logo),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(supermarket.brandColor).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        supermarket.shortName,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(supermarket.brandColor),
          fontSize: size * 0.24,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
