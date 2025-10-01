import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:myapp/router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/config/env.dart';
import 'package:myapp/constants/app_theme.dart';
import 'package:myapp/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? initError;

  try {
    // Load environment variables
    await Env.load();

    // Validate env values early - be more permissive for web
    if (Env.supabaseUrl.isEmpty || Env.supabaseAnonKey.isEmpty) {
      if (kIsWeb) {
        debugPrint('Warning: Missing environment variables, using fallback values for web');
      } else {
        throw Exception('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
      }
    }

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    // Initialize Mapbox with access token
    MapboxOptions.setAccessToken('pk.eyJ1Ijoic3dpZnRkYXNoIiwiYSI6ImNtZzNiazczczEzZmQycnIwdno1Z2NtYW0ifQ.9zBJVXVCBLU3eN1jZQTJUA');
  } catch (e, st) {
    // Keep the error so we can show a useful UI instead of a white screen
    initError = e.toString();
    // Log to console for debugging
    debugPrint('App initialization error: $e');
    debugPrintStack(stackTrace: st);
  }

  // If initialization failed, MyApp will render an error screen with details.
  runApp(MyApp(initErrorMessage: initError));
}

class MyApp extends StatefulWidget {
  final String? initErrorMessage;

  const MyApp({this.initErrorMessage, super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    
    // Listen to auth state changes to refresh router
    if (widget.initErrorMessage == null) {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (mounted) {
          // Force router refresh when auth state changes
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initErrorMessage != null) {
      return MaterialApp(
        title: 'SwiftDash - Error',
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                    const SizedBox(height: 16),
                    const Text(
                      'The app failed to start.',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.initErrorMessage!,
                      style: const TextStyle(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => debugPrint('Please check .env and restart the app'),
                      child: const Text('Check .env and restart'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_showSplash) {
      return MaterialApp(
        title: 'SwiftDash',
        theme: AppTheme.lightTheme,
        home: SplashScreen(
          onComplete: () {
            setState(() {
              _showSplash = false;
            });
          },
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp.router(
      routerConfig: router,
      title: 'SwiftDash',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
    );
  }
}
