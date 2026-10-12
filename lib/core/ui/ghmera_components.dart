import 'package:flutter/material.dart';

import '../../app/models/ghmera_models.dart';
import '../../app/services/help_credits.dart';
import 'ghmera_theme.dart';

class GhCard extends StatelessWidget {
  const GhCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.onLongPress,
    this.color = GhColors.surface,
    this.borderColor = GhColors.line,
    this.gradient,
    this.radius = GhRadius.card,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color color;
  final Color? borderColor;
  final Gradient? gradient;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: gradient == null ? color : null,
          gradient: gradient,
          borderRadius: borderRadius,
          border: borderColor == null ? null : Border.all(color: borderColor!),
          boxShadow: shadow ? ghCardShadow : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: borderRadius,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class GhSectionHeader extends StatelessWidget {
  const GhSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.count,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 8, 4, 12),
  });

  final String title;
  final String? subtitle;
  final int? count;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title, style: theme.textTheme.titleLarge),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: GhColors.brandSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: GhColors.brandDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: GhColors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class GhTag extends StatelessWidget {
  const GhTag({
    super.key,
    required this.label,
    this.icon,
    this.foreground = GhColors.inkSoft,
    this.background = GhColors.field,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final Color foreground;
  final Color background;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: dense ? 11.5 : 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GhIconBadge extends StatelessWidget {
  const GhIconBadge({
    super.key,
    required this.icon,
    this.color = GhColors.brand,
    this.background,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class GhAvatar extends StatelessWidget {
  const GhAvatar({
    super.key,
    required this.name,
    this.photo,
    this.size = 44,
    this.showVerified = false,
  });

  final String name;
  final String? photo;
  final double size;
  final bool showVerified;

  static const List<List<Color>> _palettes = <List<Color>>[
    <Color>[Color(0xFF16A085), Color(0xFF0F6B5C)],
    <Color>[Color(0xFFF2A65A), Color(0xFFD9722E)],
    <Color>[Color(0xFF5B8DEF), Color(0xFF3164C8)],
    <Color>[Color(0xFFB57EDC), Color(0xFF8A4FB8)],
    <Color>[Color(0xFFEF7A8B), Color(0xFFC2456B)],
    <Color>[Color(0xFF4DB6AC), Color(0xFF00796B)],
  ];

  @override
  Widget build(BuildContext context) {
    final trimmedPhoto = photo?.trim() ?? '';
    final initials = initialsFor(name);
    final palette = _palettes[name.hashCode.abs() % _palettes.length];
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
          letterSpacing: 0.3,
        ),
      ),
    );

    Widget avatar = fallback;
    if (trimmedPhoto.isNotEmpty) {
      final isNetwork =
          trimmedPhoto.startsWith('http://') ||
          trimmedPhoto.startsWith('https://');
      avatar = ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: isNetwork
              ? Image.network(
                  trimmedPhoto,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                )
              : Image.asset(
                  trimmedPhoto,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      );
    }

    if (!showVerified) {
      return avatar;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_rounded,
                size: size * 0.32,
                color: GhColors.sky,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String initialsFor(String fullName) {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    final first = parts.first.characters.first.toUpperCase();
    final second = parts.length > 1
        ? parts[1].characters.first.toUpperCase()
        : '';
    return '$first$second';
  }
}

class GhEmptyState extends StatelessWidget {
  const GhEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.color = GhColors.brand,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GhCard(
      shadow: false,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      child: Column(
        children: [
          GhIconBadge(icon: icon, color: color, size: 52),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: GhColors.inkSoft,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: GhColors.brandSoft,
                foregroundColor: GhColors.brandDark,
                minimumSize: const Size(0, 44),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class GhRatingStars extends StatelessWidget {
  const GhRatingStars({super.key, required this.rating, this.size = 14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (index) {
        final fill = (rating - index).clamp(0.0, 1.0);
        final icon = fill >= 0.75
            ? Icons.star_rounded
            : fill >= 0.25
            ? Icons.star_half_rounded
            : Icons.star_outline_rounded;
        return Icon(
          icon,
          size: size,
          color: fill >= 0.25 ? GhColors.credit : const Color(0xFFCBD5D2),
        );
      }),
    );
  }
}

class GhCreditChip extends StatelessWidget {
  const GhCreditChip({
    super.key,
    required this.credits,
    this.onTap,
    this.onDark = false,
  });

  final int credits;
  final VoidCallback? onTap;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final shown = credits < 0 ? 0 : credits;
    final label = shown == 1 ? '1 credit' : '$shown credits';
    return Semantics(
      button: onTap != null,
      label: '$label available',
      child: Material(
        color: onDark
            ? Colors.white.withValues(alpha: 0.14)
            : GhColors.creditSoft,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GhCoin(size: 22),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: onDark ? Colors.white : GhColors.creditDeep,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GhCoin extends StatelessWidget {
  const GhCoin({super.key, this.size = 24, this.dimmed = false});

  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: dimmed
              ? const <Color>[Color(0xFFE6E0D6), Color(0xFFD3CBBE)]
              : const <Color>[Color(0xFFFFD27A), GhColors.credit],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: dimmed ? const Color(0xFFC9C0B2) : const Color(0xFFF7B955),
          width: size * 0.06,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.volunteer_activism_rounded,
        size: size * 0.55,
        color: dimmed ? Colors.white : const Color(0xFF8A4F05),
      ),
    );
  }
}

/// Compact track record shown next to a requester so helpers know who they
/// are helping.
class GhHelpStatsStrip extends StatelessWidget {
  const GhHelpStatsStrip({super.key, required this.stats, this.compact = true});

  final UserHelpStats stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          GhTag(
            dense: true,
            icon: Icons.volunteer_activism_rounded,
            label: 'Helped ${stats.helpsGiven}',
            foreground: GhColors.brandDark,
            background: GhColors.brandSoft,
          ),
          GhTag(
            dense: true,
            icon: Icons.inventory_2_outlined,
            label: 'Received ${stats.helpsReceived}',
            foreground: GhColors.sky,
            background: GhColors.skySoft,
          ),
          GhTag(
            dense: true,
            icon: Icons.star_rounded,
            label: stats.reviewCount == 0
                ? 'No ratings yet'
                : '${stats.averageRating.toStringAsFixed(1)} (${stats.reviewCount})',
            foreground: GhColors.creditDeep,
            background: GhColors.creditSoft,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _StatCell(
            value: '${stats.helpsGiven}',
            label: 'Helped others',
            color: GhColors.brand,
          ),
        ),
        const _StatDivider(),
        Expanded(
          child: _StatCell(
            value: '${stats.helpsReceived}',
            label: 'Help received',
            color: GhColors.sky,
          ),
        ),
        const _StatDivider(),
        Expanded(
          child: _StatCell(
            value: stats.reviewCount == 0
                ? '–'
                : stats.averageRating.toStringAsFixed(1),
            label: stats.reviewCount == 1
                ? '1 rating'
                : '${stats.reviewCount} ratings',
            color: GhColors.creditDeep,
            leading: stats.reviewCount == 0
                ? null
                : const Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: GhColors.credit,
                  ),
          ),
        ),
      ],
    );
  }
}

class GhStatTile extends StatelessWidget {
  const GhStatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color = GhColors.brand,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 10),
          ],
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: GhColors.ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: GhColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
    this.leading,
  });

  final String value;
  final String label;
  final Color color;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 3)],
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: GhColors.inkSoft),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: GhColors.line);
  }
}

class GhSheetHandle extends StatelessWidget {
  const GhSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        margin: const EdgeInsets.only(top: 10, bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFD3DCDA),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class GhInfoBanner extends StatelessWidget {
  const GhInfoBanner({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.info_outline_rounded,
    this.foreground = GhColors.brandDark,
    this.background = GhColors.brandSoft,
    this.action,
  });

  final String? title;
  final String message;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground.withValues(alpha: 0.9),
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GhCategoryStyle {
  const GhCategoryStyle(this.icon, this.color);

  final IconData icon;
  final Color color;

  static GhCategoryStyle of(RequestCategory category) {
    switch (category) {
      case RequestCategory.errands:
        return const GhCategoryStyle(
          Icons.shopping_bag_outlined,
          GhColors.brand,
        );
      case RequestCategory.transportation:
        return const GhCategoryStyle(
          Icons.directions_car_outlined,
          GhColors.sky,
        );
      case RequestCategory.studyHelp:
        return const GhCategoryStyle(Icons.menu_book_rounded, GhColors.plum);
      case RequestCategory.technicalSupport:
        return const GhCategoryStyle(Icons.computer_rounded, GhColors.sky);
      case RequestCategory.emotionalSupport:
        return const GhCategoryStyle(Icons.favorite_rounded, GhColors.rose);
      case RequestCategory.prayerSupport:
        return const GhCategoryStyle(
          Icons.self_improvement_rounded,
          GhColors.plum,
        );
      case RequestCategory.childcare:
        return const GhCategoryStyle(Icons.child_care_rounded, GhColors.amber);
      case RequestCategory.elderlySupport:
        return const GhCategoryStyle(Icons.elderly_rounded, GhColors.amber);
      case RequestCategory.movingHelp:
        return const GhCategoryStyle(
          Icons.local_shipping_outlined,
          GhColors.brand,
        );
      case RequestCategory.informationAdvice:
        return const GhCategoryStyle(
          Icons.lightbulb_outline_rounded,
          GhColors.credit,
        );
      case RequestCategory.foodSupport:
        return const GhCategoryStyle(Icons.restaurant_rounded, GhColors.coral);
      case RequestCategory.emergencySupport:
        return const GhCategoryStyle(Icons.emergency_outlined, GhColors.coral);
    }
  }
}

Color ghUrgencyColor(UrgencyLevel urgency) {
  switch (urgency) {
    case UrgencyLevel.low:
      return GhColors.brand;
    case UrgencyLevel.medium:
      return GhColors.amber;
    case UrgencyLevel.high:
      return GhColors.coral;
  }
}

Color ghStatusColor(HelpRequestStatus status) {
  switch (status) {
    case HelpRequestStatus.open:
      return GhColors.inkSoft;
    case HelpRequestStatus.matching:
      return GhColors.sky;
    case HelpRequestStatus.matched:
    case HelpRequestStatus.accepted:
      return GhColors.brand;
    case HelpRequestStatus.inProgress:
      return GhColors.amber;
    case HelpRequestStatus.completed:
      return const Color(0xFF2E7D4F);
    case HelpRequestStatus.canceled:
      return GhColors.inkFaint;
    case HelpRequestStatus.reported:
    case HelpRequestStatus.disputed:
      return GhColors.coral;
  }
}

String ghRelativeTime(DateTime timestamp) {
  final difference = DateTime.now().difference(timestamp);
  if (difference.inMinutes < 1) {
    return 'just now';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }
  return '${difference.inDays ~/ 7}w ago';
}
