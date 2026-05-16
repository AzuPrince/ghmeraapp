import 'package:flutter/material.dart';

enum SnackBarType { info, success, error, warning }

void showGhmeraSnackBar(
  BuildContext context, {
  required String message,
  IconData? icon,
  SnackBarType type = SnackBarType.info,
  Duration duration = const Duration(seconds: 4),
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  Color backgroundColor;
  IconData displayIcon;

  switch (type) {
    case SnackBarType.success:
      backgroundColor = const Color(0xFF0F6B5C);
      displayIcon = icon ?? Icons.check_circle_outline_rounded;
      break;
    case SnackBarType.error:
      backgroundColor = const Color(0xFFE76F51);
      displayIcon = icon ?? Icons.error_outline_rounded;
      break;
    case SnackBarType.warning:
      backgroundColor = const Color(0xFFF4A261);
      displayIcon = icon ?? Icons.warning_amber_rounded;
      break;
    case SnackBarType.info:
    default:
      backgroundColor = const Color(0xFF163C38);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
