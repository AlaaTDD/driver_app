// lib/features/user/presentation/profile/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/profile_bloc.dart';
import 'bloc/profile_state.dart';
import 'bloc/profile_event.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/localization/generated/app_localizations.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _populated = false;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(const LoadUserProfile());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _populate(Map<String, dynamic> user) {
    if (_populated) return;
    _userData = user;
    _nameController.text = user['name'] as String? ?? '';
    _phoneController.text = user['phone'] as String? ?? '';
    _emailController.text = user['email'] as String? ?? '';
    _populated = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        title: Text(AppLocalizations.of(context)!.editProfile),
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoaded) {
            final wasPopulated = _populated;
            _populate(state.user);
            if (wasPopulated) AppToast.success(AppLocalizations.of(context)!.changesSaved);
          } else if (state is ProfileError) {
            AppToast.error(ErrorMapper.getErrorMessage(context, state.message));
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (state is ProfileError && !_populated) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message,
                      style: TextStyle(color: context.textPrimary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context
                        .read<ProfileBloc>()
                        .add(const LoadUserProfile()),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    child: Text(AppLocalizations.of(context)!.retry),
                  ),
                ],
              ),
            );
          }
          return _buildForm(context, state);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, ProfileState state) {
    final l = AppLocalizations.of(context)!;
    final avatarUrl = _userData['avatar_url'] as String?;
    final rating = _userData['rating'] as num?;
    final totalTrips = _userData['total_trips'] as num?;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          CircleAvatar(
            radius: 50,
            backgroundColor: context.primaryTint,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person_rounded,
                    size: 50, color: AppColors.primary)
                : null,
          ),
          if (rating != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${rating.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.directions_car_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${totalTrips ?? 0} ${l.totalTrips}',
                  style: TextStyle(color: context.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          TextField(
            controller: _nameController,
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              labelText: l.fullName,
              prefixIcon: const Icon(Icons.person_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              labelText: l.phone,
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            readOnly: true,
            style: TextStyle(color: context.textSecondary),
            decoration: InputDecoration(
              labelText: l.email,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: state is ProfileLoading
                ? null
                : () => context.read<ProfileBloc>().add(UpdateProfile({
                      'name': _nameController.text.trim(),
                      'phone': _phoneController.text.trim(),
                    })),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: state is ProfileLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(l.saveChanges,
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
