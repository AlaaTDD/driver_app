
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'bloc/profile_bloc.dart';
import 'bloc/profile_state.dart';
import 'bloc/profile_event.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../services/r2_storage_service.dart';
import '../../../../services/supabase_service.dart';

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
  bool _uploadingAvatar = false;

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

    // Fix #20: trip stats from user_trip_stats view
    final statsCompleted = _userData['stats_completed_trips'] as int?;
    final statsCancelled = _userData['stats_cancelled_trips'] as int?;
    final statsKm        = _userData['stats_total_km'] as num?;
    final statsRating    = _userData['stats_avg_rating'] as num?;
    final hasStats = statsCompleted != null || statsCancelled != null || statsKm != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // ── Avatar with functional edit overlay ────────────────────
          GestureDetector(
            onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: context.primaryTint,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: _uploadingAvatar
                      ? const CircularProgressIndicator(
                          color: AppColors.white, strokeWidth: 2)
                      : avatarUrl == null
                          ? const Icon(Icons.person_rounded,
                              size: 50, color: AppColors.primary)
                          : null,
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.bgColor, width: 2),
                  ),
                  child: Icon(
                    _uploadingAvatar
                        ? Icons.hourglass_top_rounded
                        : Icons.edit,
                    size: 12,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
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
          // ── Fix #20: Trip Stats Card ────────────────────────────────
          if (hasStats) ...[
            const SizedBox(height: 16),
            _buildTripStatsCard(context, l,
              completed: statsCompleted ?? 0,
              cancelled: statsCancelled ?? 0,
              totalKm: statsKm,
              avgRating: statsRating,
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
              foregroundColor: AppColors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: state is ProfileLoading
                ? const CircularProgressIndicator(color: AppColors.white)
                : Text(l.saveChanges,
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStatsCard(
    BuildContext context,
    AppLocalizations l, {
    required int completed,
    required int cancelled,
    num? totalKm,
    num? avgRating,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.10),
            AppColors.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 15),
            const SizedBox(width: 6),
            Text(l.tripStats,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _StatCell(
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.success,
              label: l.totalTripsCompleted,
              value: '$completed',
            ),
            const SizedBox(width: 8),
            _StatCell(
              icon: Icons.cancel_outlined,
              color: AppColors.error,
              label: l.cancelledTrips,
              value: '$cancelled',
            ),
            if (totalKm != null) ...[
              const SizedBox(width: 8),
              _StatCell(
                icon: Icons.route_rounded,
                color: AppColors.info,
                label: l.totalKmTravelled,
                value: totalKm.toStringAsFixed(0),
              ),
            ],
            if (avgRating != null) ...[
              const SizedBox(width: 8),
              _StatCell(
                icon: Icons.star_rounded,
                color: AppColors.warning,
                label: l.avgTripRating,
                value: avgRating.toStringAsFixed(1),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) throw Exception('Not logged in');
      final r2 = R2StorageService();
      final url = await r2.uploadFile(
        file: File(image.path),
        path: 'avatars/user_$uid.${image.path.split('.').last}',
      );
      if (mounted) {
        context.read<ProfileBloc>().add(UpdateProfile({'avatar_url': url}));
      }
    } catch (e) {
      if (mounted) AppToast.error('فشل رفع الصورة: $e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }
}

// ── Compact stat cell used in the trip stats card ─────────────────────────
class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatCell({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
