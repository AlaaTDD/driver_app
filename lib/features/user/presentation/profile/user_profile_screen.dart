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
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../services/r2_storage_service.dart';
import '../../../../services/supabase_service.dart';
import 'package:snapix/core/widgets/app_button.dart';

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
  File? _localAvatarFile;

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
    _userData = {..._userData, ...user};
    _localAvatarFile = null;
    if (_populated) return;
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
            if (wasPopulated) {
              AppToast.success(AppLocalizations.of(context)!.changesSaved);
            }
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
                  AppButton(
                    text: AppLocalizations.of(context)!.retry,
                    onPressed: () => context
                        .read<ProfileBloc>()
                        .add(const LoadUserProfile()),
                    size: AppButtonSize.sm,
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
    final ImageProvider<Object>? avatarImage;
    if (_localAvatarFile != null) {
      avatarImage = FileImage(_localAvatarFile!);
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarImage = NetworkImage(avatarUrl);
    } else {
      avatarImage = null;
    }
    final rating = _userData['rating'] as num?;
    final totalTrips = _userData['total_trips'] as num?;

    // Fix #20: trip stats from user_trip_stats view
    final statsCompleted = _userData['stats_completed_trips'] as int?;
    final statsCancelled = _userData['stats_cancelled_trips'] as int?;
    final statsKm = _userData['stats_total_km'] as num?;
    final statsRating = _userData['stats_avg_rating'] as num?;
    final hasStats =
        statsCompleted != null || statsCancelled != null || statsKm != null;

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
                  backgroundImage: avatarImage,
                  child: _uploadingAvatar
                      ? const CircularProgressIndicator(
                          color: AppColors.white, strokeWidth: 2)
                      : avatarImage == null
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
                    _uploadingAvatar ? Icons.hourglass_top_rounded : Icons.edit,
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
                const Icon(Icons.star_rounded,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 4),
                Text(
                  rating.toStringAsFixed(1),
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.directions_car_outlined,
                    color: AppColors.primary, size: 20),
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
            _buildTripStatsCard(
              context,
              l,
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
          AppButton(
            text: l.saveChanges,
            onPressed: state is ProfileLoading
                ? null
                : () => context.read<ProfileBloc>().add(UpdateProfile({
                      'name': _nameController.text.trim(),
                      'phone': _phoneController.text.trim(),
                    })),
            isLoading: state is ProfileLoading,
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
            const Icon(Icons.bar_chart_rounded,
                color: AppColors.primary, size: 15),
            const SizedBox(width: 6),
            Text(l.tripStats,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cells = [
                _StatCell(
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                  label: l.totalTripsCompleted,
                  value: '$completed',
                ),
                _StatCell(
                  icon: Icons.cancel_outlined,
                  color: AppColors.error,
                  label: l.cancelledTrips,
                  value: '$cancelled',
                ),
                if (totalKm != null)
                  _StatCell(
                    icon: Icons.route_rounded,
                    color: AppColors.info,
                    label: l.totalKmTravelled,
                    value: totalKm.toStringAsFixed(0),
                  ),
                if (avgRating != null)
                  _StatCell(
                    icon: Icons.star_rounded,
                    color: AppColors.warning,
                    label: l.avgTripRating,
                    value: avgRating.toStringAsFixed(1),
                  ),
              ];
              final columns = constraints.maxWidth >= 360 ? cells.length : 2;
              final itemWidth =
                  (constraints.maxWidth - ((columns - 1) * 8)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cells
                    .map((cell) => SizedBox(width: itemWidth, child: cell))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final source = await _chooseAvatarSource();
    if (source == null) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null) return;

    setState(() {
      _localAvatarFile = File(image.path);
      _uploadingAvatar = true;
    });
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) throw AuthException('errorNotLoggedIn');
      final r2 = R2StorageService();
      final ext = _imageExtension(image.path);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final url = await r2.uploadFile(
        file: File(image.path),
        path: 'avatars/user_${uid}_$stamp.$ext',
      );
      if (mounted) {
        context.read<ProfileBloc>().add(UpdateProfile({'avatar_url': url}));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _localAvatarFile = null);
        final message = e is AppException ? e.message : 'errorUploadFailed';
        AppToast.error(ErrorMapper.getErrorMessage(context, message));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  String _imageExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpg',
    };
  }

  Future<ImageSource?> _chooseAvatarSource() {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: Text(isAr ? 'المعرض' : 'Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded,
                    color: AppColors.primary),
                title: Text(isAr ? 'الكاميرا' : 'Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
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
    return Container(
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
    );
  }
}
