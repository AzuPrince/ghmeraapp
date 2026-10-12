import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/services/help_credits.dart';
import '../../../../core/ui/ghmera_components.dart';
import '../../../../core/ui/ghmera_theme.dart';
import 'help_credits_sheet.dart';

class CreditWalletCard extends StatelessWidget {
  const CreditWalletCard({
    super.key,
    required this.summary,
    required this.message,
    this.action,
  });

  final HelpCreditSummary summary;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = summary.spendable;
    final postingNote = summary.shortfall > 0
        ? '${summary.shortfall} below zero · help someone to get back on track'
        : summary.canAffordRequest
        ? 'Each request uses $requestCreditCost: $askCreditCost to ask, $receiveCreditCost to receive'
        : 'Need ${summary.creditsNeededToPost} more to post · requests need $requestCreditCost';
    final coinSlots = math
        .max(startingHelpCredits, summary.balance)
        .clamp(0, 10);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: ghBrandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x330F6B5C),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'HELP CREDITS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => showHelpCreditsSheet(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      label: const Text('How it works'),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$available',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontSize: 48,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          available == 1
                              ? 'credit available'
                              : 'credits available',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: summary.canAffordRequest
                        ? Colors.white.withValues(alpha: 0.14)
                        : GhColors.coral.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    postingNote,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var index = 0; index < coinSlots; index++)
                      GhCoin(size: 26, dimmed: index >= available),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      _WalletStat(label: 'Earned', value: '+${summary.earned}'),
                      _WalletStat(label: 'Used', value: '${summary.spent}'),
                      _WalletStat(label: 'On hold', value: '${summary.held}'),
                    ],
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: action!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  const _WalletStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
