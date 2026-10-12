import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class GhColors {
  static const Color brand = Color(0xFF0F6B5C);
  static const Color brandDark = Color(0xFF0A4A40);
  static const Color brandDeep = Color(0xFF062B25);
  static const Color brandSoft = Color(0xFFE1F1EC);
  static const Color mint = Color(0xFF7FD1B9);

  static const Color credit = Color(0xFFE29A2E);
  static const Color creditDeep = Color(0xFF9A5B08);
  static const Color creditSoft = Color(0xFFFDF0DA);

  static const Color coral = Color(0xFFD9573F);
  static const Color coralSoft = Color(0xFFFBE6E1);
  static const Color amber = Color(0xFFC98318);
  static const Color amberSoft = Color(0xFFFBEFD9);
  static const Color sky = Color(0xFF3170CF);
  static const Color skySoft = Color(0xFFE5EEFB);
  static const Color plum = Color(0xFF8A4FB8);
  static const Color plumSoft = Color(0xFFF1E8F8);
  static const Color rose = Color(0xFFC2456B);
  static const Color roseSoft = Color(0xFFFBE7EE);

  static const Color ink = Color(0xFF10201D);
  static const Color inkSoft = Color(0xFF52625F);
  static const Color inkFaint = Color(0xFF8B9996);
  static const Color line = Color(0xFFE3EAE7);
  static const Color canvas = Color(0xFFF3F6F5);
  static const Color field = Color(0xFFF5F8F7);
  static const Color surface = Colors.white;
}

abstract final class GhRadius {
  static const double card = 20;
  static const double control = 14;
  static const double sheet = 28;
}

const List<BoxShadow> ghCardShadow = <BoxShadow>[
  BoxShadow(color: Color(0x0D0B2620), blurRadius: 24, offset: Offset(0, 8)),
  BoxShadow(color: Color(0x080B2620), blurRadius: 4, offset: Offset(0, 1)),
];

const LinearGradient ghBrandGradient = LinearGradient(
  colors: <Color>[Color(0xFF138A74), GhColors.brand, GhColors.brandDeep],
  stops: <double>[0, 0.45, 1],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient ghCanvasGradient = LinearGradient(
  colors: <Color>[Color(0xFFE6F2EE), GhColors.canvas, GhColors.canvas],
  stops: <double>[0, 0.32, 1],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

// The status bar colour must be set explicitly: when it is null, Android
// before 15 keeps a translucent black scrim over the strip above the app bar.
final SystemUiOverlayStyle ghLightPageOverlayStyle = SystemUiOverlayStyle.dark
    .copyWith(statusBarColor: Colors.transparent);

final SystemUiOverlayStyle ghDarkPageOverlayStyle = SystemUiOverlayStyle.light
    .copyWith(statusBarColor: Colors.transparent);

ThemeData buildGhmeraTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: GhColors.brand,
        brightness: Brightness.light,
      ).copyWith(
        primary: GhColors.brand,
        onPrimary: Colors.white,
        primaryContainer: GhColors.brandSoft,
        onPrimaryContainer: GhColors.brandDeep,
        secondary: GhColors.credit,
        onSecondary: Colors.white,
        secondaryContainer: GhColors.creditSoft,
        onSecondaryContainer: GhColors.creditDeep,
        tertiary: GhColors.coral,
        onTertiary: Colors.white,
        error: GhColors.coral,
        surface: GhColors.surface,
        onSurface: GhColors.ink,
        onSurfaceVariant: GhColors.inkSoft,
        outline: GhColors.line,
        outlineVariant: GhColors.line,
        surfaceTint: Colors.transparent,
      );

  final baseText = Typography.material2021(
    platform: TargetPlatform.iOS,
  ).black.apply(bodyColor: GhColors.ink, displayColor: GhColors.ink);
  final textTheme = baseText.copyWith(
    displaySmall: baseText.displaySmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
    ),
    headlineMedium: baseText.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
    ),
    headlineSmall: baseText.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    titleLarge: baseText.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
    titleMedium: baseText.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
    ),
    titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: baseText.bodyLarge?.copyWith(height: 1.45),
    bodyMedium: baseText.bodyMedium?.copyWith(height: 1.4),
    bodySmall: baseText.bodySmall?.copyWith(color: GhColors.inkSoft),
    labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    labelMedium: baseText.labelMedium?.copyWith(fontWeight: FontWeight.w600),
  );

  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(GhRadius.control),
  );
  const buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
  );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(GhRadius.control),
    borderSide: const BorderSide(color: GhColors.line),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      foregroundColor: GhColors.ink,
      titleSpacing: 16,
      systemOverlayStyle: ghLightPageOverlayStyle,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: GhColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GhRadius.card),
        side: const BorderSide(color: GhColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: GhColors.brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFDCE4E2),
        disabledForegroundColor: GhColors.inkFaint,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: controlShape,
        textStyle: buttonText,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GhColors.ink,
        backgroundColor: GhColors.surface,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: GhColors.line, width: 1.2),
        shape: controlShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: GhColors.brand,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: controlShape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: GhColors.ink),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: GhColors.ink,
      foregroundColor: Colors.white,
      elevation: 2,
      highlightElevation: 4,
      extendedTextStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: GhColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 70,
      indicatorColor: GhColors.brandSoft,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? GhColors.brand : GhColors.inkSoft,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? GhColors.brand : GhColors.inkSoft,
        );
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: GhColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: GhColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GhRadius.sheet),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: GhColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: GhColors.inkSoft),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GhColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: GhColors.inkSoft),
      floatingLabelStyle: const TextStyle(
        color: GhColors.brand,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: GhColors.inkFaint),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      disabledBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: Color(0xFFEDF1F0)),
      ),
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: GhColors.brand, width: 1.6),
      ),
      errorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: GhColors.coral),
      ),
      focusedErrorBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(color: GhColors.coral, width: 1.6),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: GhColors.surface,
      selectedColor: GhColors.brandSoft,
      side: const BorderSide(color: GhColors.line),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: GhColors.ink,
      ),
      secondaryLabelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: GhColors.brandDark,
      ),
      checkmarkColor: GhColors.brand,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll<Color>(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? GhColors.brand
            : const Color(0xFFD5DEDB),
      ),
      trackOutlineColor: const WidgetStatePropertyAll<Color>(
        Colors.transparent,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: GhColors.inkSoft,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    dividerTheme: const DividerThemeData(
      color: GhColors.line,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: GhColors.brand,
      linearTrackColor: Color(0xFFE3EBE8),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: GhColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: GhColors.ink,
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );
}
