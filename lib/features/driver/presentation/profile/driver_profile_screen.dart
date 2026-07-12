import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'bloc/driver_profile_bloc.dart';
import 'bloc/driver_profile_state.dart';
import 'bloc/driver_profile_event.dart';
import '../../../../core/models/driver_profile_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/services/r2_storage_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/app_phone_field.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _nameController = TextEditingController();
  String _phoneValue = '';
  final _plateController = TextEditingController();
  // [إصلاح 2026-07-10 — الجزء ب] controllers للحقول النصية/الرقمية التسعة
  // الناقصة سابقًا. كانت الشاشة تدعم فقط name/phone/vehicle_plate رغم أن
  // السائق قد يُطلب منه (عبر driver_revision_requests) تعديل أيٍّ من
  // national_id/license_number/vehicle_category/brand/model/year/color.
  final _nationalIdController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  // القيم المسموحة مطابقة لـ chk_dp_vehicle_category (CHECK constraint فعلي
  // على drivers_profile — تم التحقق من قيمه الأربعة عشر عبر x-ray CSV قبل
  // البناء، وليست افتراضًا).
  static const _vehicleCategoryValues = [
    'car', 'suv', 'bike', 'van', 'pickup', 'truck', 'minivan', 'luxury',
    'electric', 'taxi', 'bus', 'bicycle', 'scooter', 'rickshaw',
  ];
  String? _selectedVehicleCategory;
  bool _populated = false;
  bool _uploadingAvatar = false;
  File? _localAvatarFile;
  // [الجزء ب.2] مفتاح رفع لكل مستند على حدة (بدل boolean واحد) لأن الأربعة
  // مستندات (هوية/رخصة/سجل جنائي/صورة مركبة) قابلة للرفع المستقل المتزامن.
  final Map<String, bool> _uploadingField = {};

  @override
  void initState() {
    super.initState();
    context.read<DriverProfileBloc>().add(const LoadDriverProfile());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    _nationalIdController.dispose();
    _licenseNumberController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }

  void _populate(DriverProfileModel driver) {
    if (_populated) return;
    _nameController.text = driver.name ?? '';
    _phoneValue = driver.phone ?? '';
    _plateController.text = driver.vehiclePlate;
    _nationalIdController.text = driver.nationalId;
    _licenseNumberController.text = driver.licenseNumber;
    _vehicleBrandController.text = driver.vehicleBrand;
    _vehicleModelController.text = driver.vehicleModel;
    _vehicleYearController.text =
        driver.vehicleYear != null ? '${driver.vehicleYear}' : '';
    _vehicleColorController.text = driver.vehicleColor;
    // vehicle_category قد تكون فارغة لسائق قديم لم يُهاجَر بعد — لا نجبر
    // قيمة افتراضية هنا حتى لا نرسلها للحفظ دون قصد السائق الفعلي.
    _selectedVehicleCategory = _vehicleCategoryValues.contains(driver.vehicleCategory)
        ? driver.vehicleCategory
        : null;
    _populated = true;
  }

  // [إصلاح 2026-07-10 — الجزء ب.3] كل أعمدة drivers_profile التي تعدّلها هذه
  // الشاشة هي NOT NULL في الداتابيز (مؤكد من x-ray CSV) — إرسال قيمة فارغة
  // لأي منها يفشل الـ UPDATE بخطأ constraint. لذلك: أي حقل نصي جديد يُترك
  // خارج الـ payload كليًا إذا كان فارغًا بعد trim (بدل إرسال ''), فتبقى
  // القيمة القديمة في الداتابيز كما هي دون تغيير — بالضبط سلوك "الإبقاء على
  // القيمة القديمة لو الحقل فارغ" الذي حددته الخطة. name/phone/vehicle_plate
  // ليست NOT NULL بنفس القيد فتبقى تُرسَل دائمًا كما كانت.
  Map<String, dynamic> _buildUpdatePayload() {
    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneValue.trim(),
      'vehicle_plate': _plateController.text.trim(),
    };

    void addIfNotEmpty(String key, String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) payload[key] = trimmed;
    }

    addIfNotEmpty('national_id', _nationalIdController.text);
    addIfNotEmpty('license_number', _licenseNumberController.text);
    addIfNotEmpty('vehicle_brand', _vehicleBrandController.text);
    addIfNotEmpty('vehicle_model', _vehicleModelController.text);
    addIfNotEmpty('vehicle_color', _vehicleColorController.text);

    final yearText = _vehicleYearController.text.trim();
    if (yearText.isNotEmpty) {
      final year = int.tryParse(yearText);
      if (year != null) payload['vehicle_year'] = year;
    }

    if (_selectedVehicleCategory != null) {
      payload['vehicle_category'] = _selectedVehicleCategory;
    }

    return payload;
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
            _localAvatarFile = null;
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
                  AppButton(
                    text: AppLocalizations.of(context)!.retry,
                    onPressed: () => context
                        .read<DriverProfileBloc>()
                        .add(const LoadDriverProfile()),
                    size: AppButtonSize.sm,
                  ),
                ],
              ),
            );
          }

          final driver =
              state is DriverProfileLoaded ? state.driver : const DriverProfileModel(id: '');
          return _buildContent(context, driver, state);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, DriverProfileModel driver,
      DriverProfileState state) {
    final l = AppLocalizations.of(context)!;
    final avatarUrl = driver.avatarUrl;
    final ImageProvider<Object>? avatarImage;
    if (_localAvatarFile != null) {
      avatarImage = FileImage(_localAvatarFile!);
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarImage = NetworkImage(avatarUrl);
    } else {
      avatarImage = null;
    }
    final rating = driver.rating;
    final totalTrips = driver.totalTrips;
    // [البند 17 — المراجعة النهائية] استُبدل driver.isVerified (العمود القديم)
    // بـ accountStatus الموحّد — الشاشة نفسها غير قابلة للوصول أصلاً لسائق
    // محظور (AppRouter.redirect يعترضه عبر AuthDriverBlocked قبل وصوله هنا،
    // البند 11)، لذا تبقى الشارة ثنائية (معتمد/قيد المراجعة) بنفس التصميم
    // الأصلي، لكن بمصدر بيانات صحيح بدلاً من is_verified القديم.
    final isVerified = driver.accountStatus == DriverAccountStatus.approved;
    // [إصلاح فئة↔نوع مركبة] drivers_profile.vehicle_type محذوف من الـ schema
    // (Phase 3) — العمود الحي الوحيد الذي يصف مركبة السائق هو vehicle_category
    // (تُحمَّل فعليًا من DriverProfileRepository.loadDriverProfile). كان هذا
    // السطر يقرأ حقل vehicleType الذي يبقى فارغًا دائمًا فيُخفي الشارة بأمان
    // لكن دون داعٍ. راجع _vehicleCategoryLabel أدناه، وهي مصممة أصلًا للقيم
    // الأربعة عشر الحقيقية في chk_dp_vehicle_category (بخلاف _vehicleLabel
    // القديمة المبنية على باقات تسعير قديمة مثل sedan/motorcycle).
    final vehicleCategory =
        driver.vehicleCategory != null && driver.vehicleCategory!.isNotEmpty
            ? driver.vehicleCategory
            : null;
    final vehicleImageUrl = driver.vehicleImageUrl.isNotEmpty ? driver.vehicleImageUrl : null;

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
                                backgroundImage: avatarImage,
                                child: _uploadingAvatar
                                    ? const CircularProgressIndicator(
                                        color: AppColors.white, strokeWidth: 2)
                                    : avatarImage == null
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

                      if (vehicleCategory != null)
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
                                // فئات ذات عجلتين ضمن الأربعة عشر الحقيقية
                                // (chk_dp_vehicle_category) — bike/scooter، بدل
                                // القيمة القديمة 'motorcycle' غير الموجودة أصلًا
                                // في القيم المسموحة الحالية.
                                vehicleCategory == 'bike' ||
                                        vehicleCategory == 'scooter'
                                    ? Icons.two_wheeler_rounded
                                    : Icons.directions_car_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _vehicleCategoryLabel(vehicleCategory),
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
                            '${totalTrips ?? driver.completedTripsWallet ?? 0}',
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
                        value: PriceFormatter.displayCompactWithCurrency(
                            context, driver.totalEarnings ?? 0),
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
                // [الجزء ب.2] كانت الصورة تُعرض فقط عند وجودها بدون أي إمكانية
                // للرفع الأول أو التغيير — أصبحت الآن دائمة الظهور (بمكان فارغ
                // قابل للضغط عند غيابها) بنفس نمط رفع الأفاتار.
                GestureDetector(
                  onTap: (_uploadingField['vehicle_image_url'] ?? false)
                      ? null
                      : () => _pickAndUploadDocument(
                          'vehicle', 'vehicle_image_url'),
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: context.elevatedColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.divColor, width: 1),
                      image: vehicleImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(vehicleImageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (_uploadingField['vehicle_image_url'] ?? false)
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary, strokeWidth: 2),
                          )
                        : vehicleImageUrl == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined,
                                      color: context.textSecondary, size: 28),
                                  const SizedBox(height: 8),
                                  Text(
                                    l.uploadDocument,
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              )
                            : Align(
                                alignment: AlignmentDirectional.bottomEnd,
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit,
                                      size: 14, color: AppColors.white),
                                ),
                              ),
                  ),
                ),
                // [إصلاح 2026-07-10 — الجزء ب.1] كانت هذه البطاقة عرضًا للقراءة
                // فقط (_DetailRow) لبيانات المركبة الأربعة — أصبحت الآن حقول
                // تعديل فعلية (dropdown لفئة المركبة + TextField لكل من
                // الماركة/الموديل/السنة/اللون)، لأن هذه بالضبط الحقول التي قد
                // يطلب الأدمن من السائق تصحيحها عبر driver_revision_requests.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.elevatedColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.divColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedVehicleCategory,
                        decoration: InputDecoration(
                          labelText: l.vehicleCategory,
                          prefixIcon:
                              const Icon(Icons.directions_car_filled_outlined),
                        ),
                        items: _vehicleCategoryValues
                            .map((v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(_vehicleCategoryLabel(v)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedVehicleCategory = v),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _vehicleBrandController,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          labelText: l.vehicleBrand,
                          prefixIcon:
                              const Icon(Icons.branding_watermark_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _vehicleModelController,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          labelText: l.vehicleModel,
                          prefixIcon: const Icon(Icons.car_rental_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _vehicleYearController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          labelText: l.vehicleYear,
                          prefixIcon:
                              const Icon(Icons.calendar_today_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _vehicleColorController,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          labelText: l.vehicleColor,
                          prefixIcon: const Icon(Icons.color_lens_outlined),
                        ),
                      ),
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
                      // [الجزء ب.2] الثلاثة صفوف أصبحوا قابلين للضغط لرفع/تغيير
                      // المستند عبر _pickAndUploadDocument، بدل عرض للقراءة فقط.
                      _DocumentRow(
                        icon: Icons.badge_outlined,
                        label: l.nationalId,
                        hasUrl: driver.nationalIdImageUrl.isNotEmpty,
                        isUploading:
                            _uploadingField['national_id_image_url'] ?? false,
                        onTap: () => _pickAndUploadDocument(
                            'national_id', 'national_id_image_url'),
                      ),
                      Divider(color: context.divColor, height: 20),
                      _DocumentRow(
                        icon: Icons.card_membership_outlined,
                        label: l.driverLicense,
                        hasUrl: driver.licenseImageUrl.isNotEmpty,
                        isUploading:
                            _uploadingField['license_image_url'] ?? false,
                        onTap: () => _pickAndUploadDocument(
                            'license', 'license_image_url'),
                      ),
                      Divider(color: context.divColor, height: 20),
                      _DocumentRow(
                        icon: Icons.description_outlined,
                        label: l.criminalRecord,
                        hasUrl: driver.criminalRecordUrl.isNotEmpty,
                        isUploading:
                            _uploadingField['criminal_record_url'] ?? false,
                        onTap: () => _pickAndUploadDocument(
                            'criminal_record', 'criminal_record_url'),
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
                // [الجزء ب.1] رقم الهوية ورقم الرخصة نصّان منفصلان عن صورهما
                // (national_id_image_url / license_image_url أعلاه) — كانا
                // مفقودين تمامًا من الشاشة رغم كونهما NOT NULL في الداتابيز.
                TextField(
                  controller: _nationalIdController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: l.nationalId,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _licenseNumberController,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: l.driverLicense,
                    prefixIcon: const Icon(Icons.card_membership_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                AppPhoneField(
                  key: ValueKey('driver_phone_field_${driver.phone ?? ''}'),
                  initialCountryCode: 'EG',
                  initialFullNumber: driver.phone,
                  onChanged: (number) {
                    _phoneValue = number;
                  },
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
                AppButton(
                  text: l.saveChanges,
                  isLoading: state is DriverProfileLoading,
                  onPressed: state is DriverProfileLoading
                      ? null
                      : () => context
                          .read<DriverProfileBloc>()
                          .add(UpdateDriverProfile(_buildUpdatePayload())),
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
        path: 'avatars/driver_${uid}_$stamp.$ext',
      );
      // Persist via bloc (UpdateDriverProfile allows avatar_url)
      if (mounted) {
        context
            .read<DriverProfileBloc>()
            .add(UpdateDriverProfile({'avatar_url': url}));
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

  // [الجزء ب.2] دالة موحّدة لرفع أي مستند من الأربعة (هوية/رخصة/سجل جنائي/
  // صورة مركبة) — نفس نمط _pickAndUploadAvatar لكن بمفتاح رفع خاص بكل حقل
  // في _uploadingField (بدل boolean واحد) لأن المستندات ترفع باستقلالية، ثم
  // تُحفظ فورًا عند نجاح الرفع (مثل الأفاتار) وليس عند الضغط على "حفظ".
  Future<void> _pickAndUploadDocument(
      String r2PathSegment, String updateFieldKey) async {
    final source = await _chooseAvatarSource();
    if (source == null) return;

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (image == null) return;

    setState(() => _uploadingField[updateFieldKey] = true);
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) throw AuthException('errorNotLoggedIn');
      final r2 = R2StorageService();
      final ext = _imageExtension(image.path);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final url = await r2.uploadFile(
        file: File(image.path),
        path: 'documents/driver_${uid}_${r2PathSegment}_$stamp.$ext',
      );
      if (mounted) {
        context
            .read<DriverProfileBloc>()
            .add(UpdateDriverProfile({updateFieldKey: url}));
      }
    } catch (e) {
      if (mounted) {
        final message = e is AppException ? e.message : 'errorUploadFailed';
        AppToast.error(ErrorMapper.getErrorMessage(context, message));
      }
    } finally {
      if (mounted) setState(() => _uploadingField[updateFieldKey] = false);
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

  // [إصلاح فئة↔نوع مركبة] حُذفت _vehicleLabel(القديمة، مبنية على باقات تسعير
  // قديمة مثل sedan/motorcycle لا وجود لها في drivers_profile.vehicle_category
  // الحقيقي) بعد أن حل _vehicleCategoryLabel محلها في الشارة أعلاه — لم يعد
  // لها أي استدعاء في هذا الملف.

  // [الجزء ب.1] تسمية عربية/إنجليزية لكل قيمة من قيم vehicle_category
  // الأربعة عشر المسموحة (chk_dp_vehicle_category)، تُستخدم في dropdown
  // تعديل فئة المركبة.
  String _vehicleCategoryLabel(String category) {
    final l = AppLocalizations.of(context)!;
    final labels = {
      'car': l.vehicleCategoryCar,
      'suv': l.vehicleCategorySuv,
      'bike': l.vehicleCategoryBike,
      'van': l.vehicleCategoryVan,
      'pickup': l.vehicleCategoryPickup,
      'truck': l.vehicleCategoryTruck,
      'minivan': l.vehicleCategoryMinivan,
      'luxury': l.vehicleCategoryLuxury,
      'electric': l.vehicleCategoryElectric,
      'taxi': l.vehicleCategoryTaxi,
      'bus': l.vehicleCategoryBus,
      'bicycle': l.vehicleCategoryBicycle,
      'scooter': l.vehicleCategoryScooter,
      'rickshaw': l.vehicleCategoryRickshaw,
    };
    return labels[category] ?? category;
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

// [الجزء ب.2] أصبح الصف قابلاً للضغط لرفع/تغيير المستند — نفس بيانات العرض
// الأصلية (hasUrl) بالإضافة إلى onTap اختياري وحالة isUploading خاصة بهذا
// الحقل فقط (من _uploadingField في الشاشة الأب).
class _DocumentRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasUrl;
  final VoidCallback? onTap;
  final bool isUploading;

  const _DocumentRow({
    required this.icon,
    required this.label,
    required this.hasUrl,
    this.onTap,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return InkWell(
      onTap: isUploading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
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
            if (isUploading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              )
            else ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      hasUrl
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      size: 12,
                      color: hasUrl ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasUrl ? l.uploaded : l.notUploaded,
                      style: TextStyle(
                        color: hasUrl ? AppColors.success : AppColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: context.textSecondary),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
