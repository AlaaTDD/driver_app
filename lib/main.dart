import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'core/bloc_observer.dart';
import 'core/constants/env_constants.dart';
import 'core/localization/bloc/language_bloc.dart';
import 'core/localization/generated/app_localizations.dart';
import 'core/localization/bloc/language_event.dart';
import 'core/localization/bloc/language_state.dart';
import 'core/theme/bloc/theme_bloc.dart';
import 'core/theme/bloc/theme_event.dart';
import 'core/theme/bloc/theme_state.dart';
import 'core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'core/router/app_router.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';

import 'features/driver/presentation/home/bloc/driver_home_bloc.dart';
import 'features/ride_offer/bloc/ride_offer_bloc.dart';
import 'features/ride_offer/overlay/ride_offer_overlay.dart';
import 'services/fcm_service.dart';
import 'services/r2_storage_service.dart';
import 'core/services/connectivity_service.dart';
import 'firebase_options.dart';






@pragma('vm:entry-point')
void overlayMain() {
  rideOfferOverlayMain();
}




Future<void> _cleanupStaleTrips() async {
  try {
    final result = await Supabase.instance.client.rpc('cleanup_stuck_trips');
    
    if (result is int && result > 0) {
      debugPrint('Stale trip cleanup completed: $result trip(s) cleaned');
    }
  } catch (e) {
    debugPrint('Stale trip cleanup failed (RPC may not exist yet): $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FCMService().initialize();
    registerMainAppPort();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('⚠️ Firebase not configured — run: flutterfire configure');
  }

  await Supabase.initialize(
    url: EnvConstants.supabaseUrl,
    anonKey: EnvConstants.supabaseAnonKey,
  );

  
  ConnectivityService().init();

  
  _cleanupStaleTrips();

  final prefs = await SharedPreferences.getInstance();
  Bloc.observer = AppBlocObserver();

  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatefulWidget {
  final SharedPreferences prefs;

  const MyApp({super.key, required this.prefs});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;
  bool _routerReady = false;

  @override
  void initState() {
    super.initState();
    
  }

  void _initRouter(AuthBloc authBloc) {
    
    if (!mounted || _routerReady) return;
    _router = AppRouter.router(authBloc);
    _routerReady = true;
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<R2StorageService>(
          create: (_) => R2StorageService(),
        ),
        RepositoryProvider<AuthRepositoryImpl>(
          create: (context) => AuthRepositoryImpl(
            context.read<R2StorageService>(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        
        
        
        
        
        providers: [
          
          BlocProvider<LanguageBloc>(
            create: (_) => LanguageBloc(widget.prefs)..add(LoadSavedLanguage()),
          ),
          BlocProvider<ThemeBloc>(
            create: (_) => ThemeBloc(widget.prefs)..add(LoadSavedTheme()),
          ),
          
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              context.read<AuthRepositoryImpl>(),
            )..add(CheckAuthStatus()),
          ),
        ],
        child: BlocBuilder<LanguageBloc, LanguageState>(
          builder: (context, langState) {
            final locale = langState is LanguageLoaded
                ? langState.locale
                : const Locale('ar');
            final authBloc = context.read<AuthBloc>();
            
            _initRouter(authBloc);
            return BlocBuilder<ThemeBloc, ThemeState>(
              builder: (context, themeState) {
                return MaterialApp.router(
                  title: 'Taxi',
                  debugShowCheckedModeBanner: false,
                  themeMode: themeState.themeMode,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  locale: locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: AppLocalizations.localizationsDelegates,
                  routerConfig: _router,
                  builder: (context, child) {
                    return BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, authState) {
                        if (authState is AuthAuthenticated && authState.user.role == 'driver') {
                          return MultiBlocProvider(
                            providers: [
                              BlocProvider(
                                create: (_) => RideOfferBloc(),
                              ),
                            ],
                            child: RideOfferInAppOverlay(
                              child: child!,
                            ),
                          );
                        }
                        return child!;
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
