// lib/features/driver/presentation/shells/driver_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class DriverShell extends StatelessWidget {
  final Widget child;

  const DriverShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticated ? authState.user : null;
        return Scaffold(
          backgroundColor: context.bgColor,
          drawer: AppDrawer(
            user: user,
            onTripsTap: () { Navigator.pop(context); context.push(AppRoutes.driverTrips); },
            onMessagesTap: () { Navigator.pop(context); context.push(AppRoutes.driverMessages); },
            onChatbotTap: () { Navigator.pop(context); context.push(AppRoutes.driverChatbot); },
            onProfileTap: () { Navigator.pop(context); context.push(AppRoutes.driverProfile); },
            onLogout: () { Navigator.pop(context); context.read<AuthBloc>().add(SignOutRequested()); },
          ),
          body: child,
        );
      },
    );
  }

}
