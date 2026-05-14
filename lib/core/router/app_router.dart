
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/register_user_screen.dart';
import '../../features/auth/presentation/screens/register_driver_screen.dart';
import '../../features/user/presentation/screens/user_home_screen.dart';
import '../../features/user/presentation/location_selection/location_selection_screen.dart';
import '../../features/user/presentation/location_selection/location_selection_args.dart';
import '../../features/user/presentation/pricing/pricing_screen.dart';
import '../../features/user/presentation/pricing/pricing_args.dart';
import '../../features/user/presentation/meeting_point/meeting_point_screen.dart';
import '../../features/user/presentation/meeting_point/meeting_point_args.dart';
import '../../features/user/presentation/searching/searching_screen.dart';
import '../../features/user/presentation/tracking/tracking_screen.dart';
import '../../features/user/presentation/trips/trips_screen.dart';
import '../../features/user/presentation/trip_details/trip_details_screen.dart';
import '../../features/user/presentation/profile/user_profile_screen.dart';
import '../../features/driver/presentation/home/driver_home_screen.dart';
import '../../features/driver/presentation/trip_details/trip_details_screen.dart';
import '../../features/driver/presentation/trips/driver_trips_screen.dart';
import '../../features/driver/presentation/profile/driver_profile_screen.dart';
import '../../features/shared/presentation/screens/pending_verification_screen.dart';
import '../../features/shared/presentation/messages/screens/conversations_screen.dart';
import '../../features/shared/presentation/messages/screens/messages_screen.dart';
import '../../features/shared/presentation/notifications/notifications_screen.dart';
import '../../features/shared/presentation/chatbot/chatbot_screen.dart';
import '../../features/shared/presentation/rating/rating_screen.dart';
import '../../features/shared/presentation/screens/complaints_screen.dart';
import '../../features/wallet/presentation/cubit/wallet_cubit.dart';
import '../../features/wallet/presentation/screens/driver_wallet_screen.dart';
import '../../features/wallet/presentation/screens/user_wallet_screen.dart';
import '../constants/app_routes.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/user/presentation/home/bloc/user_home_bloc.dart';
import '../../features/user/presentation/pricing/bloc/pricing_bloc.dart';
import '../../features/user/presentation/meeting_point/bloc/meeting_bloc.dart';
import '../../features/user/presentation/searching/bloc/searching_bloc.dart';
import '../../features/user/presentation/tracking/bloc/tracking_bloc.dart';
import '../../features/user/presentation/trips/bloc/trips_bloc.dart';
import '../../features/user/presentation/profile/bloc/profile_bloc.dart';
import '../../features/user/presentation/location_selection/bloc/location_bloc.dart';
import '../../features/driver/presentation/trip_details/bloc/trip_details_bloc.dart';
import '../../features/driver/presentation/trips/bloc/driver_trips_bloc.dart';
import '../../features/driver/presentation/profile/bloc/driver_profile_bloc.dart';
import '../../features/driver/presentation/home/bloc/driver_home_bloc.dart';
import '../../features/shared/presentation/rating/bloc/rating_bloc.dart';
import '../../core/bloc/location_permission_cubit.dart';


Page<dynamic> _buildSlideTransition({required Widget child}) {
  return CustomTransitionPage(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic;
      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      final offsetAnimation = animation.drive(tween);
      return SlideTransition(position: offsetAnimation, child: child);
    },
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen(
      (_) => notifyListeners(),
      onError: (e) => debugPrint('GoRouterRefreshStream error: $e'),
    );
  }
  late final StreamSubscription _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppRouter {
  static late GoRouter routerInstance;

  
  static final _uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static bool _isValidUuid(String? value) =>
      value != null && value.isNotEmpty && _uuidRegex.hasMatch(value);

  static String _safeId(GoRouterState state, String param) {
    final value = state.uri.queryParameters[param] ?? '';
    return _isValidUuid(value) ? value : '';
  }

  static bool _isAuthRoute(String location) {
    return location == AppRoutes.splash ||
        location == AppRoutes.onboarding ||
        location == AppRoutes.login ||
        location == AppRoutes.register ||
        location == AppRoutes.registerUser ||
        location == AppRoutes.registerDriver;
  }

  static GoRouter router(AuthBloc authBloc) {
    routerInstance = GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;
        final loc = state.matchedLocation;

        
        if (authState is AuthError || authState is AuthLoading) {
          return null;
        }

        
        if (authState is AuthInitial) {
          return loc == AppRoutes.splash ? null : AppRoutes.splash;
        }

        if (authState is AuthUnauthenticated) {
          if (_isAuthRoute(loc)) return null;
          return AppRoutes.login;
        }

        if (authState is AuthAuthenticated) {
          if (!_isAuthRoute(loc)) return null;
          return authState.user.role == 'driver'
              ? AppRoutes.driverHome
              : AppRoutes.userHome;
        }

        if (authState is AuthDriverPending) {
          if (loc == AppRoutes.pendingVerification) return null;
          return AppRoutes.pendingVerification;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          name: AppRoutes.splash,
          pageBuilder: (context, state) => CustomTransitionPage(
            child: const SplashScreen(),
            transitionDuration: Duration.zero,
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
          ),
        ),
        GoRoute(
          path: AppRoutes.onboarding,
          name: AppRoutes.onboarding,
          pageBuilder: (context, state) => _buildSlideTransition(child: const OnboardingScreen()),
        ),
        GoRoute(
          path: AppRoutes.login,
          name: AppRoutes.login,
          pageBuilder: (context, state) => const MaterialPage(child: LoginScreen()),
        ),
        GoRoute(
          path: AppRoutes.register,
          name: AppRoutes.register,
          pageBuilder: (context, state) => const MaterialPage(child: RegisterScreen()),
        ),
        GoRoute(
          path: AppRoutes.registerUser,
          name: AppRoutes.registerUser,
          pageBuilder: (context, state) => const MaterialPage(child: RegisterUserScreen()),
        ),
        GoRoute(
          path: AppRoutes.registerDriver,
          name: AppRoutes.registerDriver,
          pageBuilder: (context, state) => const MaterialPage(child: RegisterDriverScreen()),
        ),
        GoRoute(
          path: AppRoutes.pendingVerification,
          name: AppRoutes.pendingVerification,
          pageBuilder: (context, state) => const MaterialPage(child: PendingVerificationScreen()),
        ),
        GoRoute(
          path: AppRoutes.userHome,
          name: AppRoutes.userHome,
          pageBuilder: (context, state) => _buildSlideTransition(
            child: MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => UserHomeBloc()),
                BlocProvider(create: (_) => LocationPermissionCubit()),
              ],
              child: const UserHomeScreen(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.userProfile,
          name: AppRoutes.userProfile,
          pageBuilder: (context, state) => MaterialPage(
            child: BlocProvider(create: (_) => ProfileBloc(), child: const UserProfileScreen()),
          ),
        ),
        GoRoute(
          path: AppRoutes.userTrips,
          name: AppRoutes.userTrips,
          pageBuilder: (context, state) => MaterialPage(
            child: BlocProvider(create: (_) => TripsBloc(), child: const UserTripsScreen()),
          ),
        ),
        GoRoute(
          path: AppRoutes.userMessages,
          name: AppRoutes.userMessages,
          pageBuilder: (context, state) {
            final tripId = state.uri.queryParameters['tripId'];
            final otherUserId = state.uri.queryParameters['otherUserId'];
            final otherUserName = state.uri.queryParameters['otherUserName'];
            if ((tripId != null && tripId.isNotEmpty) || (otherUserId != null && otherUserId.isNotEmpty)) {
              return MaterialPage(child: MessagesScreen(
                tripId: tripId,
                otherUserId: otherUserId,
                otherUserName: otherUserName,
              ));
            }
            return const MaterialPage(child: ConversationsScreen());
          },
        ),
        GoRoute(
          path: AppRoutes.userChatbot,
          name: AppRoutes.userChatbot,
          pageBuilder: (context, state) => const MaterialPage(child: ChatbotScreen()),
        ),
        GoRoute(
          path: AppRoutes.userNotifications,
          name: AppRoutes.userNotifications,
          pageBuilder: (context, state) => const MaterialPage(child: NotificationsScreen()),
        ),
        GoRoute(
          path: AppRoutes.userLocationSelect,
          name: AppRoutes.userLocationSelect,
          pageBuilder: (context, state) => MaterialPage(
            child: BlocProvider(create: (_) => LocationBloc(), child: LocationSelectionScreen(
              extra: state.extra as LocationSelectionArgs?,
            )),
          ),
        ),
        GoRoute(
          path: AppRoutes.userPricing,
          name: AppRoutes.userPricing,
          pageBuilder: (context, state) => MaterialPage(
            child: BlocProvider(create: (_) => PricingBloc(), child: PricingScreen(
              extra: state.extra as PricingArgs?,
            )),
          ),
        ),
        GoRoute(
          path: AppRoutes.userMeetingPoint,
          name: AppRoutes.userMeetingPoint,
          pageBuilder: (context, state) => MaterialPage(
            child: BlocProvider(create: (_) => MeetingBloc(), child: MeetingPointScreen(
              extra: state.extra as MeetingPointArgs?,
            )),
          ),
        ),
        GoRoute(
          path: AppRoutes.userSearching,
          name: AppRoutes.userSearching,
          pageBuilder: (context, state) {
            final q = state.uri.queryParameters;
            final tripId = q['tripId'] ?? '';
            final oLat = double.tryParse(q['oLat'] ?? '');
            final oLng = double.tryParse(q['oLng'] ?? '');
            final dLat = double.tryParse(q['dLat'] ?? '');
            final dLng = double.tryParse(q['dLng'] ?? '');
            return MaterialPage(
              child: BlocProvider(create: (_) => SearchingBloc(), child: SearchingScreen(
                tripId: tripId,
                originLat: oLat,
                originLng: oLng,
                destLat: dLat,
                destLng: dLng,
              )),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.userTracking,
          name: AppRoutes.userTracking,
          pageBuilder: (context, state) {
            final tripId = _safeId(state, 'tripId');
            if (tripId.isEmpty) return const MaterialPage(child: Scaffold(body: Center(child: Text('Invalid trip ID'))));
            return MaterialPage(child: BlocProvider(create: (_) => TrackingBloc(), child: TripTrackingScreen(tripId: tripId)));
          },
        ),
        GoRoute(
          path: AppRoutes.userRating,
          name: AppRoutes.userRating,
          pageBuilder: (context, state) {
            final tripId = _safeId(state, 'tripId');
            if (tripId.isEmpty) return const MaterialPage(child: Scaffold(body: Center(child: Text('Invalid trip ID'))));
            return MaterialPage(child: BlocProvider(create: (_) => RatingBloc(), child: RatingScreen(tripId: tripId)));
          },
        ),
        GoRoute(
          path: AppRoutes.userTripDetails,
          name: AppRoutes.userTripDetails,
          pageBuilder: (context, state) {
            final tripId = _safeId(state, 'tripId');
            if (tripId.isEmpty) return const MaterialPage(child: Scaffold(body: Center(child: Text('Invalid trip ID'))));
            return MaterialPage(child: BlocProvider(create: (_) => TripsBloc(), child: UserTripDetailsScreen(tripId: tripId)));
          },
        ),
        GoRoute(
          path: AppRoutes.userComplaints,
          name: AppRoutes.userComplaints,
          pageBuilder: (context, state) => const MaterialPage(child: ComplaintsScreen()),
        ),
        GoRoute(
          path: AppRoutes.userWallet,
          name: AppRoutes.userWallet,
          pageBuilder: (context, state) => const MaterialPage(child: UserWalletScreen()),
        ),
        GoRoute(
          path: AppRoutes.driverHome,
          name: AppRoutes.driverHome,
          pageBuilder: (context, state) => _buildSlideTransition(
            child: MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => DriverHomeBloc()),
                BlocProvider(create: (_) => LocationPermissionCubit()),
              ],
              child: const DriverHomeScreen(),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.driverProfile,
          name: AppRoutes.driverProfile,
          pageBuilder: (context, state) => MaterialPage(
            child: BlocProvider(create: (_) => DriverProfileBloc(), child: const DriverProfileScreen()),
          ),
        ),
        GoRoute(
          path: AppRoutes.driverTrips,
          name: AppRoutes.driverTrips,
          pageBuilder: (context, state) => MaterialPage(
            child: BlocProvider(create: (_) => DriverTripsBloc(), child: const DriverTripsScreen()),
          ),
        ),
        GoRoute(
          path: AppRoutes.driverMessages,
          name: AppRoutes.driverMessages,
          pageBuilder: (context, state) {
            final tripId = state.uri.queryParameters['tripId'];
            final otherUserId = state.uri.queryParameters['otherUserId'];
            final otherUserName = state.uri.queryParameters['otherUserName'];
            if ((tripId != null && tripId.isNotEmpty) || (otherUserId != null && otherUserId.isNotEmpty)) {
              return MaterialPage(child: MessagesScreen(
                tripId: tripId,
                otherUserId: otherUserId,
                otherUserName: otherUserName,
              ));
            }
            return const MaterialPage(child: ConversationsScreen());
          },
        ),
        GoRoute(
          path: AppRoutes.driverChatbot,
          name: AppRoutes.driverChatbot,
          pageBuilder: (context, state) => const MaterialPage(child: ChatbotScreen()),
        ),
        GoRoute(
          path: AppRoutes.driverNotifications,
          name: AppRoutes.driverNotifications,
          pageBuilder: (context, state) => const MaterialPage(child: NotificationsScreen()),
        ),
        GoRoute(
          path: AppRoutes.driverTripDetails,
          name: AppRoutes.driverTripDetails,
          pageBuilder: (context, state) {
            final tripId = _safeId(state, 'tripId');
            if (tripId.isEmpty) return const MaterialPage(child: Scaffold(body: Center(child: Text('Invalid trip ID'))));
            return MaterialPage(child: BlocProvider(create: (_) => TripDetailsBloc(), child: DriverTripDetailsScreen(tripId: tripId)));
          },
        ),
        GoRoute(
          path: AppRoutes.driverRating,
          name: AppRoutes.driverRating,
          pageBuilder: (context, state) {
            final tripId = _safeId(state, 'tripId');
            if (tripId.isEmpty) return const MaterialPage(child: Scaffold(body: Center(child: Text('Invalid trip ID'))));
            return MaterialPage(child: BlocProvider(create: (_) => RatingBloc(), child: RatingScreen(tripId: tripId)));
          },
        ),
        GoRoute(
          path: AppRoutes.driverComplaints,
          name: AppRoutes.driverComplaints,
          pageBuilder: (context, state) => const MaterialPage(child: ComplaintsScreen()),
        ),
        GoRoute(
          path: AppRoutes.driverWallet,
          name: AppRoutes.driverWallet,
          pageBuilder: (context, state) => MaterialPage(
            child: BlocProvider(
              create: (_) => WalletCubit(),
              child: const DriverWalletScreen(),
            ),
          ),
        ),
      ],
    );
    return routerInstance;
  }
}
