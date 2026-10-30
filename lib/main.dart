import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/setup/firebase_setup_screen.dart';
import 'services/media_upload_queue.dart';
import 'services/open_form_intent.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  MediaUploadQueue.instance.prepare();
  await initializeDateFormatting('tr_TR');

  var firebaseReady = DefaultFirebaseOptions.isConfigured;
  if (firebaseReady) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (_) {}
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
      title: 'İNÜ SKY',
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
        final inset = MediaQuery.viewPaddingOf(context).bottom;
        final media = MediaQuery.of(context);
        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: inset),
              child: MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(bottom: 0),
                  viewPadding: media.viewPadding.copyWith(bottom: 0),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 6 + inset,
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
          OpenFormIntent.consumeMediaAfterAuth();
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
            BrandLogo(size: 108),
            SizedBox(height: 16),
            Text(
              'İNÜ SKY',
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
