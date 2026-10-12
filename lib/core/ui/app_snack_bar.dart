import 'package:flutter/material.dart';

import 'ghmera_theme.dart';

enum SnackBarType { info, success, error, warning }

void showGhmeraSnackBar(
  BuildContext context, {
  required String message,
  IconData? icon,
  SnackBarType type = SnackBarType.info,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  assert(
    (actionLabel == null) == (onAction == null),
    'actionLabel and onAction must be provided together.',
  );
  Color backgroundColor;
  IconData displayIcon;

  switch (type) {
    case SnackBarType.success:
      backgroundColor = GhColors.brand;
      displayIcon = icon ?? Icons.check_circle_outline_rounded;
      break;
    case SnackBarType.error:
      backgroundColor = GhColors.coral;
      displayIcon = icon ?? Icons.error_outline_rounded;
      break;
    case SnackBarType.warning:
      backgroundColor = GhColors.amber;
      displayIcon = icon ?? Icons.warning_amber_rounded;
      break;
    case SnackBarType.info:
      backgroundColor = GhColors.ink;
      displayIcon = icon ?? Icons.info_outline_rounded;
      break;
  }

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(displayIcon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: onAction,
            )
          : null,
    ),
  );
}
