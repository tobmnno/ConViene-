import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/payment_method.dart';
import '../theme/app_theme.dart';

class PaymentMethodLogo extends StatelessWidget {
  const PaymentMethodLogo({super.key, required this.method, this.size = 40});

  final PaymentMethod method;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (method.logoAsset.isNotEmpty) {
      final isSvg = method.logoAsset.toLowerCase().endsWith('.svg');
      final logo = isSvg
          ? SvgPicture.asset(
              method.logoAsset,
              width: size * 1.35,
              height: size * 0.9,
              fit: BoxFit.contain,
              semanticsLabel: method.displayName,
            )
          : Image.asset(
              method.logoAsset,
              width: size * 1.35,
              height: size * 0.9,
              fit: BoxFit.contain,
              semanticLabel: method.displayName,
            );
      return SizedBox(
        width: size * 1.45,
        height: size,
        child: Center(
          child: Padding(padding: EdgeInsets.all(size * 0.05), child: logo),
        ),
      );
    }

    final label = method.displayName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part.substring(0, 1))
        .take(2)
        .join();
    final color = switch (method.type) {
      PaymentMethodType.card => AppColors.blue,
      PaymentMethodType.bank => AppColors.deepBlue,
      PaymentMethodType.wallet => AppColors.green,
    };
    return Container(
      width: size * 1.2,
      height: size * 0.75,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.25,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
