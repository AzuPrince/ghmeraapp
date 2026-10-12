import 'package:flutter/material.dart';

import 'ghmera_theme.dart';

TextStyle uniformHeadingTextStyle(BuildContext context, {Color? color}) {
  return Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: color ?? GhColors.ink,
      ) ??
      TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: color ?? GhColors.ink,
      );
}

Widget uniformAppBarTitle(
  BuildContext context, {
  required String title,
  String? subtitle,
  Color? titleColor,
  Color? subtitleColor,
  bool isDarkBackground = false,
}) {
  final effectiveTitleColor =
      titleColor ?? (isDarkBackground ? Colors.white : GhColors.ink);
  final effectiveSubtitleColor =
      subtitleColor ??
      (isDarkBackground
          ? Colors.white.withValues(alpha: 0.8)
          : GhColors.inkSoft);

  final trimmedSubtitle = subtitle?.trim();
  if (trimmedSubtitle == null || trimmedSubtitle.isEmpty) {
    return Text(
      title,
      style: uniformHeadingTextStyle(context, color: effectiveTitleColor),
    );
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: uniformHeadingTextStyle(context, color: effectiveTitleColor),
      ),
      Text(
        trimmedSubtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: effectiveSubtitleColor),
      ),
    ],
  );
}

IconButton uniformBackButton(
  BuildContext context, {
  VoidCallback? onPressed,
  Color? color,
  bool isDarkBackground = false,
}) {
  return IconButton(
    onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    icon: Icon(
      Icons.arrow_back_ios_new_rounded,
      size: 20,
      color: color ?? (isDarkBackground ? Colors.white : GhColors.ink),
    ),
    tooltip: 'Back',
  );
}
