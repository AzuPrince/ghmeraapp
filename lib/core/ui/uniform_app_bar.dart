import 'package:flutter/material.dart';

const double _uniformBackIconSize = 22;
const double _uniformBackIconWeight = 700;
const Color _uniformHeadingColor = Color(0xFF132B27);

TextStyle uniformHeadingTextStyle(BuildContext context, {Color? color}) {
  return Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        color: color ?? _uniformHeadingColor,
      ) ??
      TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: color ?? _uniformHeadingColor,
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
      titleColor ?? (isDarkBackground ? Colors.white : _uniformHeadingColor);
  final effectiveSubtitleColor = subtitleColor ??
      (isDarkBackground
          ? Colors.white.withValues(alpha: 0.8)
          : const Color(0xFF596865));

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
        style: uniformHeadingTextStyle(context, color: effectiveTitleColor),
      ),
      Text(
        trimmedSubtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: effectiveSubtitleColor,
            ),
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
      size: _uniformBackIconSize,
      weight: _uniformBackIconWeight,
      color: color ?? (isDarkBackground ? Colors.white : null),
    ),
    tooltip: 'Back',
  );
}
