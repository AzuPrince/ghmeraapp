import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'app/providers/app_theme_provider.dart';
import 'app/providers/ghmera_app_state.dart';
import 'core/ui/apple_like_gradient.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/help_request/presentation/screens/home_screen.dart';
import 'app/providers/connectivity_provider.dart';
import 'core/ui/app_snack_bar.dart';

const LinearGradient _darkAppGradient = LinearGradient(
  colors: <Color>[Color(0xFF0C131A), Color(0xFF16212D), Color(0xFF1C2834)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
  }
  runApp(const GhmeraApp());
}

class GhmeraApp extends StatelessWidget {
  const GhmeraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F6B5C),
          brightness: Brightness.light,
        ).copyWith(
          secondary: const Color(0xFFF4A261),
          tertiary: const Color(0xFFE76F51),
        );
    final darkColorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F6B5C),
          brightness: Brightness.dark,
        ).copyWith(
          secondary: const Color(0xFFF4A261),
          tertiary: const Color(0xFFE76F51),
        );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GhmeraAppState()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: Consumer<AppThemeProvider>(
        builder: (context, appTheme, _) => MaterialApp(
          title: 'Ghmera',
          debugShowCheckedModeBanner: false,
          themeMode: appTheme.themeMode,
          theme: ThemeData(
            colorScheme: colorScheme,
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.transparent,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Color(0xFF132B27),
              titleSpacing: 10,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFD8E4E0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFD8E4E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: const Color(0xFF163C38),
              contentTextStyle: const TextStyle(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              behavior: SnackBarBehavior.floating,
            ),
            chipTheme: ChipThemeData(
              backgroundColor: Colors.white,
              selectedColor: colorScheme.primary.withValues(alpha: 0.14),
              side: const BorderSide(color: Color(0xFFD9E5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.transparent,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Color(0xFFE6F1EE),
              titleSpacing: 10,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF1F2A35),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFF2D3A46)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFF2D3A46)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: darkColorScheme.primary,
                  width: 1.4,
                ),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: const Color(0xFF1A2933),
              contentTextStyle: const TextStyle(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              behavior: SnackBarBehavior.floating,
            ),
            chipTheme: ChipThemeData(
              backgroundColor: const Color(0xFF1B2831),
              selectedColor: darkColorScheme.primary.withValues(alpha: 0.24),
              side: const BorderSide(color: Color(0xFF32424D)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return ConnectivityListener(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isDark ? _darkAppGradient : appleLikeScreenGradient,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const _LaunchSequenceScreen(),
        ),
      ),
    );
  }
}

class ConnectivityListener extends StatefulWidget {
  const ConnectivityListener({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectivityListener> createState() => _ConnectivityListenerState();
}

class _ConnectivityListenerState extends State<ConnectivityListener> {
  bool _wasOffline = false;

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;

    if (!isOnline && !_wasOffline) {
      _wasOffline = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOfflineSnackBar(context);
      });
    } else if (isOnline && _wasOffline) {
      _wasOffline = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOnlineSnackBar(context);
      });
    }

    return widget.child;
  }

  void _showOfflineSnackBar(BuildContext context) {
    showGhmeraSnackBar(
      context,
      message: 'You are offline. Some features may be limited.',
      type: SnackBarType.error,
      icon: Icons.wifi_off_rounded,
      duration: const Duration(seconds: 5),
    );
  }

  void _showOnlineSnackBar(BuildContext context) {
    showGhmeraSnackBar(
      context,
      message: 'Back online!',
      type: SnackBarType.success,
      icon: Icons.wifi_rounded,
      duration: const Duration(seconds: 2),
    );
  }
}

class _LaunchSequenceScreen extends StatefulWidget {
  const _LaunchSequenceScreen();

  @override
  State<_LaunchSequenceScreen> createState() => _LaunchSequenceScreenState();
}

class _LaunchSequenceScreenState extends State<_LaunchSequenceScreen> {
  static const Duration _nameRevealDelay = Duration(seconds: 3);
  static const Duration _routeDelay = Duration(seconds: 4);

  bool _showName = false;
  bool _goToHome = false;

  @override
  void initState() {
    super.initState();

    Future<void>.delayed(_nameRevealDelay, () {
      if (!mounted) {
        return;
      }

      setState(() {
        _showName = true;
      });
    });

    Future<void>.delayed(_routeDelay, () {
      if (!mounted) {
        return;
      }

      setState(() {
        _goToHome = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = context.watch<AuthProvider>().isSignedIn;

    if (_goToHome) {
      return isSignedIn ? const HomeScreen() : const LoginScreen();
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: appleLikeScreenGradient),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF103B36),
                borderRadius: BorderRadius.circular(5),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x330F6B5C),
                    blurRadius: 24,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: const Icon(
                Icons.volunteer_activism_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
            const SizedBox(height: 22),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 320),
              opacity: _showName ? 1 : 0,
              child: const Text(
                'Ghmera',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Color(0xFF103B36),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
