import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:swiftdash/router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swiftdash/config/env.dart';
import 'package:swiftdash/constants/app_theme.dart';
import 'package:swiftdash/screens/splash_screen.dart';
import 'package:swiftdash/services/payment_service.dart';
import 'package:swiftdash/providers/app_state_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

    // Initialize PaymentService with Maya credentials from environment
    try {
      await PaymentService.initialize(
        publicKey: Env.mayaPublicKey,
        isSandbox: Env.mayaIsSandbox,
      );
      debugPrint('Payment service initialized successfully - Environment: ${Env.mayaIsSandbox ? 'SANDBOX' : 'PRODUCTION'}');
    } catch (e) {
      debugPrint('Payment service initialization failed: $e');
      // Don't fail the entire app if payment service fails to initialize
    }

    // Background execution will be handled by app lifecycle
    debugPrint('App initialization completed successfully');
  } catch (e, st) {
    // Keep the error so we can show a useful UI instead of a white screen
    initError = e.toString();
    // Log to console for debugging
    debugPrint('App initialization error: $e');
    debugPrintStack(stackTrace: st);
  }

  // If initialization failed, MyApp will render an error screen with details.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) => HomeStateProvider()),
      ],
      child: MyApp(initErrorMessage: initError),
    ),
  );
}

class MyApp extends StatefulWidget {
  final String? initErrorMessage;

  const MyApp({this.initErrorMessage, super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer to handle app state changes
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize app state provider
    if (widget.initErrorMessage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AppStateProvider>().initialize();
      });

      // Listen to auth state changes to refresh router
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (mounted) {
          // Enable wakelock when user logs in to keep app active
          if (data.event == AuthChangeEvent.signedIn && !kIsWeb) {
            _enableWakelock();
          }
          // Disable wakelock when user logs out
          else if (data.event == AuthChangeEvent.signedOut && !kIsWeb) {
            _disableWakelock();
          }
          
          // Force router refresh when auth state changes
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disableWakelock();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Handle app lifecycle changes
    if (!kIsWeb && Supabase.instance.client.auth.currentUser != null) {
      switch (state) {
        case AppLifecycleState.resumed:
          debugPrint('📱 App resumed - ensuring wakelock is active');
          _enableWakelock();
          break;
        case AppLifecycleState.paused:
          debugPrint('📱 App paused - keeping connections alive');
          // Keep wakelock enabled to maintain connections
          break;
        case AppLifecycleState.detached:
          debugPrint('📱 App detached - background execution active');
          break;
        default:
          break;
      }
    }
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
      debugPrint('✅ Wakelock enabled - app will stay active in background');
    } catch (e) {
      debugPrint('❌ Failed to enable wakelock: $e');
    }
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
      debugPrint('🛑 Wakelock disabled');
    } catch (e) {
      debugPrint('❌ Failed to disable wakelock: $e');
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
