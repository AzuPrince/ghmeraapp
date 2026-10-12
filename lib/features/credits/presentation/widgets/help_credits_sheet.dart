import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/providers/ghmera_app_state.dart';
import '../../../../app/services/help_credits.dart';
import '../../../../core/ui/ghmera_components.dart';
import '../../../../core/ui/ghmera_theme.dart';

Future<void> showHelpCreditsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) =>
          _HelpCreditsSheet(scrollController: scrollController),
    ),
  );
}

Future<void> showCreditsWelcomeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _CreditsWelcomeSheet(),
  );
}

class _CreditsWelcomeSheet extends StatelessWidget {
  const _CreditsWelcomeSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = context
        .watch<GhmeraAppState>()
        .currentUserCredits
        .available;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GhSheetHandle(),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GhCoin(size: 40),
                SizedBox(width: 6),
                GhCoin(size: 52),
                SizedBox(width: 6),
                GhCoin(size: 40),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Meet help credits',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Every member starts with $startingHelpCredits, and there is no limit to how many you can earn. Everyone gives a little and gets a little, so Ghmera stays fair.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: GhColors.inkSoft,
              ),
            ),
            const SizedBox(height: 12),
            GhCreditChip(credits: available < 0 ? 0 : available),
            const SizedBox(height: 20),
            const _Rule(
              icon: Icons.campaign_outlined,
              color: GhColors.sky,
              title: 'Each request uses $requestCreditCost credit',
              text:
                  'Posting puts $requestCreditCost credit on hold. It is only used once you confirm the help is done.',
            ),
            const _Rule(
              icon: Icons.volunteer_activism_rounded,
              color: GhColors.brand,
              title: 'Earn $helpEarnedCredits credit for every help you give',
              text:
                  'No limit: every help you complete earns $helpEarnedCredits more credit. Browse Give Help to find people near you.',
            ),
            const _Rule(
              icon: Icons.emergency_outlined,
              color: GhColors.coral,
              title: 'Emergencies are always free',
              text: 'Emergency non-medical support never uses credits.',
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpCreditsSheet extends StatelessWidget {
  const _HelpCreditsSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<GhmeraAppState>();
    final summary = appState.currentUserCredits;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const GhSheetHandle(),
        const SizedBox(height: 8),
        Row(
          children: [
            const GhCoin(size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Help credits', style: theme.textTheme.headlineSmall),
                  Text(
                    summary.shortfall > 0
                        ? '0 available · ${summary.shortfall} below zero'
                        : '${summary.available} available · ${summary.held} on hold',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: GhColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('How credits work', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        const _Rule(
          icon: Icons.card_giftcard_rounded,
          color: GhColors.credit,
          title: 'Start with $startingHelpCredits credits',
          text:
              'Every new member receives $startingHelpCredits welcome credits. That is where you start, not a limit.',
        ),
        const _Rule(
          icon: Icons.campaign_outlined,
          color: GhColors.sky,
          title: 'Each request uses $requestCreditCost credit',
          text:
              'You need $requestCreditCost available to post. It stays on hold while people respond, and is used once you and your helper both confirm the help is done.',
        ),
        const _Rule(
          icon: Icons.volunteer_activism_rounded,
          color: GhColors.brand,
          title: 'Helping earns $helpEarnedCredits credit, with no limit',
          text:
              'No limit: every help you complete earns $helpEarnedCredits more credit. The more you help, the more you earn.',
        ),
        const _Rule(
          icon: Icons.undo_rounded,
          color: GhColors.inkSoft,
          title: 'Canceled requests are refunded',
          text:
              'Deleting an open request or canceling before completion returns the held credit.',
        ),
        const _Rule(
          icon: Icons.emergency_outlined,
          color: GhColors.coral,
          title: 'Emergencies are always free',
          text: 'Emergency non-medical support requests never use credits.',
        ),
        const SizedBox(height: 12),
        Text('Activity', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        GhCard(
          shadow: false,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var index = 0; index < summary.entries.length; index++) ...[
                if (index > 0) const Divider(indent: 64),
                _LedgerRow(entry: summary.entries[index]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GhIconBadge(icon: icon, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: GhColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final HelpCreditEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, caption) = switch (entry.kind) {
      HelpCreditEntryKind.starting => (
        Icons.card_giftcard_rounded,
        GhColors.credit,
        'When you joined',
      ),
      HelpCreditEntryKind.earned => (
        Icons.volunteer_activism_rounded,
        GhColors.brand,
        'Earned',
      ),
      HelpCreditEntryKind.received => (
        Icons.inventory_2_outlined,
        GhColors.plum,
        'Used for your request',
      ),
      HelpCreditEntryKind.held => (
        Icons.hourglass_top_rounded,
        GhColors.sky,
        'On hold until completed or canceled',
      ),
    };
    final at = entry.at;
    final amountLabel = entry.amount > 0
        ? '+${entry.amount}'
        : '${entry.amount}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          GhIconBadge(icon: icon, color: color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  at == null ? caption : '$caption · ${ghRelativeTime(at)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amountLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              color: entry.kind == HelpCreditEntryKind.held
                  ? GhColors.inkFaint
                  : entry.amount > 0
                  ? GhColors.brand
                  : GhColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
