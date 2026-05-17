import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'bloc/driver_profile_bloc.dart';
import 'bloc/driver_profile_state.dart';
import 'bloc/driver_profile_event.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../services/r2_storage_service.dart';
import '../../../../services/supabase_service.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();
  bool _populated = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    context.read<DriverProfileBloc>().add(const LoadDriverProfile());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  void _populate(Map<String, dynamic> driver) {
    if (_populated) return;
    _nameController.text =
        driver['name'] as String? ?? driver['full_name'] as String? ?? '';
    _phoneController.text = driver['phone'] as String? ?? '';
    _plateController.text = driver['plate_number'] as String? ??
        driver['vehicle_plate'] as String? ??
        '';
    _populated = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: BlocConsumer<DriverProfileBloc, DriverProfileState>(
        listener: (context, state) {
          if (state is DriverProfileLoaded) {
            final wasPopulated = _populated;
            _populate(state.driver);
            if (wasPopulated) {
              AppToast.success(AppLocalizations.of(context)!.changesSaved);
            }
          } else if (state is DriverProfileError) {
            AppToast.error(ErrorMapper.getErrorMessage(context, state.message));
          }
        },
        builder: (context, state) {
          if (state is DriverProfileLoading) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (state is DriverProfileError && !_populated) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message,
                      style: TextStyle(color: context.textPrimary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context
                        .read<DriverProfileBloc>()
                        .add(const LoadDriverProfile()),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    child: Text(AppLocalizations.of(context)!.retry),
                  ),
                ],
              ),
            );
          }

          final driver =
              state is DriverProfileLoaded ? state.driver : <String, dynamic>{};
          return _buildContent(context, driver, state);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> driver,
      DriverProfileState state) {
    final l = AppLocalizations.of(context)!;
    final avatarUrl = driver['avatar_url'] as String?;
    final rating = driver['rating'] as num?;
    final totalTrips = driver['total_trips'] as num?;
    final isVerified = driver['is_verified'] as bool? ?? false;
    final vehicleType = driver['vehicle_type'] as String?;
    final vehicleBrand = driver['vehicle_brand'] as String?;
    final vehicleModel = driver['vehicle_model'] as String?;
    final vehicleYear = driver['vehicle_year'];
    final vehicleColor = driver['vehicle_color'] as String?;
    final vehicleImageUrl = driver['vehicle_image_url'] as String?;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: context.bgColor,
          expandedHeight: 0,
          floating: true,
          pinned: true,
          title: Text(l.editProfile),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isVerified
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVerified
                          ? Icons.verified_rounded
                          : Icons.pending_rounded,
                      size: 14,
                      color: isVerified ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVerified ? l.verified : l.pending,
                      style: TextStyle(
                        color:
                            isVerified ? AppColors.success : AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Column(
                    children: [
                      // ── Avatar with functional edit button ────────────
                      GestureDetector(
                        onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  width: 3,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 52,
                                backgroundColor: context.primaryTint,
                                backgroundImage: avatarUrl != null
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: _uploadingAvatar
                                    ? const CircularProgressIndicator(
                                        color: AppColors.white, strokeWidth: 2)
                                    : avatarUrl == null
                                        ? const Icon(Icons.person_rounded,
                                            size: 52, color: AppColors.primary)
                                        : null,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: context.bgColor, width: 2),
                              ),
                              child: Icon(
                                _uploadingAvatar
                                    ? Icons.hourglass_top_rounded
                                    : Icons.edit,
                                size: 14,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (vehicleType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: context.primaryTint,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                vehicleType == 'motorcycle'
                                    ? Icons.two_wheeler_rounded
                                    : Icons.directions_car_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _vehicleLabel(vehicleType),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: l.trips,
                        value:
                            '${totalTrips ?? driver['completed_trips_wallet'] ?? 0}',
                        icon: Icons.directions_car_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: l.rating,
                        value: rating?.toStringAsFixed(1) ?? '0.0',
                        icon: Icons.star_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        label: l.earnings,
                        value:
                            '${(driver['total_earnings'] as num?)?.toStringAsFixed(0) ?? 0}',
                        icon: Icons.payments_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: l.vehicleInfo,
                  icon: Icons.directions_car_filled_rounded,
                ),
                const SizedBox(height: 12),
                if (vehicleImageUrl != null)
                  Container(
                    width: double.infinity,
                    height: 160,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.divColor, width: 1),
                      image: DecorationImage(
                        image: NetworkImage(vehicleImageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.elevatedColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.divColor),
                  ),
                  child: Column(
                    children: [
                      if (vehicleBrand != null)
                        _DetailRow(
                          icon: Icons.branding_watermark_outlined,
                          label: l.vehicleBrand,
                          value: vehicleBrand,
                        ),
                      if (vehicleModel != null) ...[
                        Divider(color: context.divColor, height: 20),
                        _DetailRow(
                          icon: Icons.car_rental_outlined,
                          label: l.vehicleModel,
                          value: vehicleModel,
                        ),
                      ],
                      if (vehicleYear != null) ...[
                        Divider(color: context.divColor, height: 20),
                        _DetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: l.vehicleYear,
                          value: '$vehicleYear',
                        ),
                      ],
                      if (vehicleColor != null) ...[
                        Divider(color: context.divColor, height: 20),
                        _DetailRow(
                          icon: Icons.color_lens_outlined,
                          label: l.vehicleColor,
                          value: vehicleColor,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: l.documents,
                  icon: Icons.folder_copy_rounded,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.elevatedColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.divColor),
                  ),
                  child: Column(
                    children: [
                      _DocumentRow(
                        icon: Icons.badge_outlined,
                        label: l.nationalId,
                        hasUrl: driver['national_id_image_url'] != null,
                      ),
                      Divider(color: context.divColor, height: 20),
                      _DocumentRow(
                        icon: Icons.card_membership_outlined,
                        label: l.driverLicense,
                        hasUrl: driver['license_image_url'] != null,
                      ),
                      Divider(color: context.divColor, height: 20),
                      _DocumentRow(
                        icon: Icons.description_outlined,
                        label: l.criminalRecord,
                        hasUrl: driver['criminal_record_url'] != null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: l.personalInfo,
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: l.fullName,
                    prefixIcon: const Icon(Icons.person_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: l.phone,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _plateController,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: l.plateNumber,
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: state is DriverProfileLoading
                      ? null
                      : () => context
                          .read<DriverProfileBloc>()
                          .add(UpdateDriverProfile({
                            'name': _nameController.text.trim(),
                            'phone': _phoneController.text.trim(),
                            'vehicle_plate': _plateController.text.trim(),
                          })),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: state is DriverProfileLoading
                      ? const CircularProgressIndicator(color: AppColors.white)
                      : Text(l.saveChanges,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
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
      if (uid == null) throw AuthException('errorNotLoggedIn');
      final r2 = R2StorageService();
      final url = await r2.uploadFile(
        file: File(image.path),
        path: 'avatars/driver_$uid.${image.path.split('.').last}',
      );
      // Persist via bloc (UpdateDriverProfile allows avatar_url)
      if (mounted) {
        context
            .read<DriverProfileBloc>()
            .add(UpdateDriverProfile({'avatar_url': url}));
      }
    } catch (e) {
      if (mounted) AppToast.error('فشل رفع الصورة: $e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  String _vehicleLabel(String type) {
    final l = AppLocalizations.of(context)!;
    final labels = {
      'sedan': l.sedan,
      'suv': l.suv,
      'van': l.van,
      'motorcycle': l.motorcycle,
      'car': l.sedan,
    };
    return labels[type] ?? type;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: context.primaryTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.textSecondary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DocumentRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasUrl;

  const _DocumentRow({
    required this.icon,
    required this.label,
    required this.hasUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.textSecondary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: hasUrl
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasUrl ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                size: 12,
                color: hasUrl ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 4),
              Text(
                hasUrl
                    ? AppLocalizations.of(context)!.uploaded
                    : AppLocalizations.of(context)!.notUploaded,
                style: TextStyle(
                  color: hasUrl ? AppColors.success : AppColors.warning,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
