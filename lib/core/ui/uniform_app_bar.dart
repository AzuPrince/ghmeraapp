import 'package:flutter/material.dart';

const double _uniformBackIconSize = 22;
const double _uniformBackIconWeight = 700;
const Color _uniformHeadingColor = Color(0xFF132B27);

TextStyle uniformHeadingTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        color: _uniformHeadingColor,
      ) ??
      const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: _uniformHeadingColor,
      );
}

Widget uniformAppBarTitle(
  BuildContext context, {
  required String title,
  String? subtitle,
}) {
  final trimmedSubtitle = subtitle?.trim();
  if (trimmedSubtitle == null || trimmedSubtitle.isEmpty) {
    return Text(title, style: uniformHeadingTextStyle(context));
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: uniformHeadingTextStyle(context)),
      Text(
        trimmedSubtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: const Color(0xFF596865)),
      ),
    ],
  );
}

IconButton uniformBackButton(BuildContext context, {VoidCallback? onPressed}) {
  return IconButton(
    onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    icon: const Icon(
      Icons.arrow_back_ios_new_rounded,
      size: _uniformBackIconSize,
      weight: _uniformBackIconWeight,
    ),
    tooltip: 'Back',
  );
}
