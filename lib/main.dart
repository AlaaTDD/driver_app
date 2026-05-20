import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'core/bloc_observer.dart';
import 'core/constants/app_constants.dart';
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
import 'services/fcm_service.dart';
import 'services/r2_storage_service.dart';
import 'core/services/connectivity_service.dart';
import 'firebase_options.dart';
import 'core/repositories/app_config_repository.dart';

final RegExp _terminalIconPattern = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]',
  unicode: true,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installPlainTerminalLogs();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: EnvConstants.supabaseUrl,
    anonKey: EnvConstants.supabaseAnonKey,
  );

  try {
    await Firebase.initializeApp(
      options: (kIsWeb || defaultTargetPlatform == TargetPlatform.windows)
          ? DefaultFirebaseOptions.currentPlatform
          : null,
    );
    await FCMService().initialize();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('⚠️ Firebase not configured — run: flutterfire configure');
  }

  await ConnectivityService().init().catchError((e) {
    debugPrint('⚠️ ConnectivityService init failed: $e');
  });

  final appConfigRepository = AppConfigRepository();
  final configuredMapCenter = await appConfigRepository
      .getDefaultMapCenter()
      .timeout(const Duration(seconds: 2), onTimeout: () => null)
      .catchError((e) {
    debugPrint('⚠️ Default map center load failed: $e');
    return null;
  });
  if (configuredMapCenter != null) {
    AppConstants.setDefaultMapCenter(configuredMapCenter);
  }

  // Activate AppConfigRepository — warms cache and checks maintenance mode.
  // Runs in background so it never blocks startup.
  appConfigRepository.getAll().then((config) {
    debugPrint('✅ AppConfig loaded: ${config.keys.join(', ')}');
  }).catchError((e) {
    debugPrint('⚠️ AppConfig load failed: $e');
  });

  final prefs = await SharedPreferences.getInstance();
  final isDarkOpt = prefs.getBool('app_theme_dark');
  final isSystemDark =
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
  final isDark = isDarkOpt ?? isSystemDark;
  final initialTheme = isDark ? ThemeDark() : ThemeLight();

  Bloc.observer = AppBlocObserver();

  final r2StorageService = R2StorageService();
  final authRepository = AuthRepositoryImpl(r2StorageService);
  final authBloc = AuthBloc(authRepository)..add(CheckAuthStatus());

  runApp(MyApp(
    prefs: prefs,
    r2StorageService: r2StorageService,
    authRepository: authRepository,
    authBloc: authBloc,
    initialTheme: initialTheme,
  ));
}

void _installPlainTerminalLogs() {
  final previousDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    previousDebugPrint(
      message == null ? null : _stripTerminalIcons(message),
      wrapWidth: wrapWidth,
    );
  };
}

String _stripTerminalIcons(String message) {
  return message.replaceAll(_terminalIconPattern, '').trimLeft();
}

class MyApp extends StatefulWidget {
  final SharedPreferences prefs;
  final R2StorageService r2StorageService;
  final AuthRepositoryImpl authRepository;
  final AuthBloc authBloc;
  final ThemeState initialTheme;

  const MyApp({
    super.key,
    required this.prefs,
    required this.r2StorageService,
    required this.authRepository,
    required this.authBloc,
    required this.initialTheme,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.router(widget.authBloc);
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<R2StorageService>.value(
          value: widget.r2StorageService,
        ),
        RepositoryProvider<AuthRepositoryImpl>.value(
          value: widget.authRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<LanguageBloc>(
            create: (_) => LanguageBloc(widget.prefs)..add(LoadSavedLanguage()),
          ),
          BlocProvider<ThemeBloc>(
            create: (_) =>
                ThemeBloc(widget.prefs, initialState: widget.initialTheme)
                  ..add(LoadSavedTheme()),
          ),
          BlocProvider<AuthBloc>.value(
            value: widget.authBloc,
          ),
        ],
        child: BlocBuilder<LanguageBloc, LanguageState>(
          builder: (context, langState) {
            final locale = langState is LanguageLoaded
                ? langState.locale
                : const Locale('ar');

            return BlocBuilder<ThemeBloc, ThemeState>(
              builder: (context, themeState) {
                return MaterialApp.router(
                  onGenerateTitle: (context) =>
                      AppLocalizations.of(context)!.appName,
                  debugShowCheckedModeBanner: false,
                  themeMode: themeState.themeMode,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  locale: locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  routerConfig: _router,
                  builder: (context, child) {
                    return child!;
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
