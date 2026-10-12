import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'app/providers/app_theme_provider.dart';
import 'app/providers/ghmera_app_state.dart';
import 'core/ui/ghmera_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/help_request/presentation/screens/home_screen.dart';
import 'app/providers/connectivity_provider.dart';
import 'core/ui/app_snack_bar.dart';

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
    final theme = buildGhmeraTheme();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GhmeraAppState()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: MaterialApp(
        title: 'Ghmera',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        theme: theme,
        builder: (context, child) {
          return ConnectivityListener(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: ghCanvasGradient),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: const _LaunchSequenceScreen(),
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
  static const Duration _nameRevealDelay = Duration(milliseconds: 250);
  static const Duration _routeDelay = Duration(milliseconds: 1600);

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ghDarkPageOverlayStyle,
      child: Scaffold(
        backgroundColor: const Color(0xFF081F1C),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  gradient: ghBrandGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x5526A69A),
                      blurRadius: 40,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 22),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 420),
                opacity: _showName ? 1 : 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  offset: _showName ? Offset.zero : const Offset(0, 0.25),
                  child: Column(
                    children: [
                      const Text(
                        'Ghmera',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Give help. Get help. Stay safe.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
