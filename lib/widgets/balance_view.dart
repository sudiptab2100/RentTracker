import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/money.dart';

/// Displays a monetary balance, coloured red when money is outstanding and
/// green when settled (zero or in advance). [balance] is in minor units.
class BalanceText extends StatelessWidget {
  const BalanceText({super.key, required this.balance, this.style});

  final int balance;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final outstanding = balance > 0;
    final color = outstanding ? AppTheme.due : AppTheme.settled;
    final label = outstanding ? Money.format(balance) : Money.format(0);
    return Text(
      label,
      style: (style ?? const TextStyle()).copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// A compact coloured pill summarizing a balance, e.g. "Due ₹1,200" / "Settled".
class BalanceChip extends StatelessWidget {
  const BalanceChip({super.key, required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final outstanding = balance > 0;
    final advance = balance < 0;
    final color = outstanding ? AppTheme.due : AppTheme.settled;
    final String text;
    if (outstanding) {
      text = 'Due ${Money.format(balance)}';
    } else if (advance) {
      text = 'Advance ${Money.format(-balance)}';
    } else {
      text = 'Settled';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5),
      ),
    );
  }
}
