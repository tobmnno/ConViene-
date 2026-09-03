import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            onTap: () => onChanged(quantity - 1),
          ),
          SizedBox(
            width: 34,
            child: Center(
              child: Text(
                '$quantity',
                style: const TextStyle(
                  color: AppColors.deepBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          _StepperButton(icon: Icons.add, onTap: () => onChanged(quantity + 1)),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
      tooltip: icon == Icons.add ? 'Sumar' : 'Restar',
      onPressed: onTap,
      icon: Icon(icon, size: 17, color: AppColors.blue),
    );
  }
}
