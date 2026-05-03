
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../home/widgets/user_drawer.dart';
import '../../../../core/localization/generated/app_localizations.dart';

class UserShell extends StatelessWidget {
  final Widget child;

  const UserShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;
        return Scaffold(
          backgroundColor: context.bgColor,
          drawer: UserDrawer(
            userName: user?.name ?? AppLocalizations.of(context)!.userDefault,
            userAvatar: user?.avatarUrl,
            userRating: user?.rating ?? 0.0,
            onTripsTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.userTrips);
            },
            onMessagesTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.userMessages);
            },
            onChatbotTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.userChatbot);
            },
            onNotificationsTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.userNotifications);
            },
            onProfileTap: () {
              Navigator.pop(context);
              context.push(AppRoutes.userProfile);
            },
            onLogoutTap: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(SignOutRequested());
            },
          ),
          body: child,
        );
      },
    );
  }
}
