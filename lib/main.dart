import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/setup/firebase_setup_screen.dart';
import 'services/open_form_intent.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');

  var firebaseReady = DefaultFirebaseOptions.isConfigured;
  if (firebaseReady) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {
      firebaseReady = false;
    }
  }

  runApp(NuansApp(firebaseReady: firebaseReady));
}

class NuansApp extends StatefulWidget {
  const NuansApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  State<NuansApp> createState() => _NuansAppState();
}

class _NuansAppState extends State<NuansApp> {
  final _nav = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (widget.firebaseReady) {
      OpenFormIntent.start(_nav);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nüans',
      navigatorKey: _nav,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: widget.firebaseReady ? const AuthGate() : const FirebaseSetupScreen(),
      builder: (context, child) {
        final bottom = MediaQuery.paddingOf(context).bottom;
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            Positioned(
              left: 10,
              bottom: 6 + bottom,
              child: const IgnorePointer(
                child: Text(
                  'made by posni',
                  style: TextStyle(
                    fontSize: 9,
                    height: 1,
                    color: Color(0x4A5A6B6B),
                    letterSpacing: 0.15,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LaunchScreen();
        }
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        if (!user.emailVerified) {
          return const VerifyEmailScreen();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          OpenFormIntent.consumeAfterAuth();
        });
        return const HomeScreen();
      },
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, color: Colors.white, size: 48),
            SizedBox(height: 16),
            Text(
              'Nüans',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
