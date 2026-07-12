import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/email_utils.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/form_validators.dart';
import '../../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../bloc/vehicle_categories_cubit.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/uuid_helper.dart';

class RegisterDriverScreen extends StatefulWidget {
  const RegisterDriverScreen({super.key});

  @override
  State<RegisterDriverScreen> createState() => _RegisterDriverScreenState();
}

class _RegisterDriverScreenState extends State<RegisterDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _nationalIdController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _nationalIdFocus = FocusNode();
  final _licenseNumberFocus = FocusNode();
  final _vehicleBrandFocus = FocusNode();
  final _vehicleModelFocus = FocusNode();
  final _vehicleColorFocus = FocusNode();
  final _vehiclePlateFocus = FocusNode();

  File? _nationalIdImage;
  File? _licenseImage;
  File? _criminalRecordImage;
  File? _vehicleImage;

  final ImagePicker _picker = ImagePicker();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isUploading = false;
  bool _isSubmitting = false; // guard ضد Double-Submit
  String _fullPhone = ''; // رقم التليفون الكامل مع كود البلد
  String? _vehicleCategory;
  // يُفعّل بعد محاولة إرسال فاشلة، لعرض رسائل خطأ دائمة تحت كل حقل فشل
  // في validate()، بنفس نمط register_user_screen.dart / login_screen.dart:
  // لا يظهر أي validation قبل أول ضغطة على زر إنشاء الحساب.
  bool _showErrors = false;

  VehicleCategoriesCubit? _vehicleCategoriesCubit;

  @override
  void initState() {
    super.initState();
    _vehicleCategoriesCubit = VehicleCategoriesCubit()..fetchVehicleCategories();
    // لو المستخدم يعدّل كلمة المرور الأصلية بعد فشل أول محاولة، رسالة
    // خطأ تأكيد المرور لازم تُعاد حسابها فورًا (لأن confirmPassword validator
    // يعتمد على _passwordController.text كمرجع للمطابقة).
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (_showErrors) setState(() {});
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _nationalIdController.dispose();
    _licenseNumberController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _vehiclePlateController.dispose();
    _nationalIdFocus.dispose();
    _licenseNumberFocus.dispose();
    _vehicleBrandFocus.dispose();
    _vehicleModelFocus.dispose();
    _vehicleColorFocus.dispose();
    _vehiclePlateFocus.dispose();
    _vehicleCategoriesCubit?.close();
    super.dispose();
  }

  // نفس الحد المستخدم في R2StorageService.uploadFile (10 ميجابايت) — لكن هنا
  // يُفحص فور اختيار الصورة، قبل الرفع الفعلي، لإعطاء المستخدم رسالة خطأ فورية
  // بدل انتظار فشل عام لاحقًا في مرحلة الرفع أثناء _submit().
  static const int _maxImageSizeBytes = 10 * 1024 * 1024;

  Future<void> _pickImage(String type) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final pickedFile = File(image.path);
      final sizeBytes = await pickedFile.length();
      if (sizeBytes > _maxImageSizeBytes) {
        if (mounted) {
          AppToast.error(AppLocalizations.of(context)!.errorFileTooLarge);
        }
        return;
      }
      setState(() {
        switch (type) {
          case 'national_id':
            _nationalIdImage = pickedFile;
            break;
          case 'license':
            _licenseImage = pickedFile;
            break;
          case 'criminal_record':
            _criminalRecordImage = pickedFile;
            break;
          case 'vehicle':
            _vehicleImage = pickedFile;
            break;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return; // مهمة 2: منع Double-Submit
    final isValid = _formKey.currentState!.validate();
    setState(() => _showErrors = !isValid);
    if (!isValid) {
      _focusFirstInvalidField();
      return;
    }
    if (_nationalIdImage == null ||
        _licenseImage == null ||
        _criminalRecordImage == null ||
        _vehicleImage == null) {
      AppToast.error(AppLocalizations.of(context)!.uploadAllDocuments);
      return;
    }

    setState(() {
      _isUploading = true;
      _isSubmitting = true; // مهمة 2: قفل الـ submit
    });
    final repo = context.read<AuthRepository>(); // مهمة 14: abstract interface
    final tempId = UuidHelper.generateV4(); // [AUTH-08 FIX] UUID not timestamp

    final results = await Future.wait([
      repo.uploadDocument(
          file: _nationalIdImage!, path: 'drivers/$tempId/national_id.jpg'),
      repo.uploadDocument(
          file: _licenseImage!, path: 'drivers/$tempId/license.jpg'),
      repo.uploadDocument(
          file: _criminalRecordImage!,
          path: 'drivers/$tempId/criminal_record.jpg'),
      repo.uploadDocument(
          file: _vehicleImage!, path: 'drivers/$tempId/vehicle.jpg'),
    ]);

    if (!mounted) return;

    String? nationalIdUrl, licenseUrl, criminalRecordUrl, vehicleUrl;
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      final url = result.fold((_) => null, (u) => u);
      if (url == null) {
        if (mounted) {
          setState(() {
            _isUploading = false;
            _isSubmitting = false; // مهمة 2: رفع القفل عند الفشل
          });
          AppToast.error(AppLocalizations.of(context)!.errorUploadFailed); // مهمة 3
        }
        return;
      }
      if (i == 0) nationalIdUrl = url;
      if (i == 1) licenseUrl = url;
      if (i == 2) criminalRecordUrl = url;
      if (i == 3) vehicleUrl = url;
    }

    setState(() => _isUploading = false);
    // _isSubmitting يبقى true حتى يرد الـ BLoC بـ AuthError أو AuthDriverPending

    if (!mounted) return;
    context.read<AuthBloc>().add(SignUpDriverRequested(
          name: _nameController.text.trim(),
          phone: _fullPhone,
          email: normalizeEmailInput(_emailController.text),
          password: _passwordController.text,
          nationalId: _nationalIdController.text.trim(),
          nationalIdImageUrl: nationalIdUrl!,
          licenseNumber: _licenseNumberController.text.trim(),
          licenseImageUrl: licenseUrl!,
          criminalRecordUrl: criminalRecordUrl!,
          vehicleCategory: _vehicleCategory ?? 'car',
          vehicleBrand: _vehicleBrandController.text.trim(),
          vehicleModel: _vehicleModelController.text.trim(),
          vehicleYear: int.tryParse(_vehicleYearController.text) ?? 2020,
          vehicleColor: _vehicleColorController.text.trim(),
          vehiclePlate: _vehiclePlateController.text.trim(),
          vehicleImageUrl: vehicleUrl!,
        ));
  }

  // يُركّز تلقائيًا على أول حقل فشل التحقق منه (الهاتف مستثنى: AppPhoneField
  // لا يعرض FocusNode خارجياً حالياً؛ التركيز عليه يبقى تحسينًا مستقبليًا).
  void _focusFirstInvalidField() {
    if (FormValidators.name(context, _nameController.text) != null) {
      _nameFocus.requestFocus();
    } else if (FormValidators.email(context, _emailController.text) != null) {
      _emailFocus.requestFocus();
    } else if (FormValidators.password(context, _passwordController.text) !=
        null) {
      _passwordFocus.requestFocus();
    } else if (FormValidators.confirmPassword(
          context,
          _confirmPasswordController.text,
          _passwordController.text,
        ) !=
        null) {
      _confirmPasswordFocus.requestFocus();
    } else if (FormValidators.nationalId(
            context, _nationalIdController.text) !=
        null) {
      _nationalIdFocus.requestFocus();
    } else if (FormValidators.licenseNumber(
            context, _licenseNumberController.text) !=
        null) {
      _licenseNumberFocus.requestFocus();
    } else if (FormValidators.vehicleBrand(
            context, _vehicleBrandController.text) !=
        null) {
      _vehicleBrandFocus.requestFocus();
    } else if (FormValidators.vehicleModel(
            context, _vehicleModelController.text) !=
        null) {
      _vehicleModelFocus.requestFocus();
    } else if (FormValidators.vehicleColor(
            context, _vehicleColorController.text) !=
        null) {
      _vehicleColorFocus.requestFocus();
    } else if (FormValidators.vehiclePlate(
            context, _vehiclePlateController.text) !=
        null) {
      _vehiclePlateFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        title: Text(AppLocalizations.of(context)!.createDriverAccount),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthDriverPending) {
            AppToast.success(
                AppLocalizations.of(context)!.accountCreatedSuccessfully);
            context.go(AppRoutes.pendingVerification);
          } else if (state is AuthError) {
            setState(() => _isSubmitting = false); // مهمة 2: السماح بإعادة المحاولة
            AppToast.error(ErrorMapper.getErrorMessage(context, state.message));
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.disabled,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fullName,
                      prefixIcon: const Icon(Icons.person_outlined),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (value) => FormValidators.name(context, value),
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                  ),
                  if (_showErrors &&
                      FormValidators.name(context, _nameController.text) !=
                          null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        key: const ValueKey('name_error_text'),
                        FormValidators.name(context, _nameController.text)!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppPhoneField(
                    initialCountryCode: 'EG',
                    onChanged: (number) {
                      setState(() => _fullPhone = number);
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  if (_showErrors && _fullPhone.isEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        key: const ValueKey('phone_error_text'),
                        AppLocalizations.of(context)!.enterPhone,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (value) => FormValidators.email(context, value),
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                  ),
                  if (_showErrors &&
                      FormValidators.email(context, _emailController.text) !=
                          null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        key: const ValueKey('email_error_text'),
                        FormValidators.email(context, _emailController.text)!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.password,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (value) =>
                        FormValidators.password(context, value),
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                  ),
                  if (_showErrors &&
                      FormValidators.password(context, _passwordController.text) !=
                          null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        key: const ValueKey('password_error_text'),
                        FormValidators.password(
                            context, _passwordController.text)!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocus,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.confirmPassword,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (value) => FormValidators.confirmPassword(
                      context,
                      value,
                      _passwordController.text,
                    ),
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                  ),
                  if (_showErrors &&
                      FormValidators.confirmPassword(
                            context,
                            _confirmPasswordController.text,
                            _passwordController.text,
                          ) !=
                          null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        key: const ValueKey('confirm_password_error_text'),
                        FormValidators.confirmPassword(
                          context,
                          _confirmPasswordController.text,
                          _passwordController.text,
                        )!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Divider(color: context.divColor),
                  const SizedBox(height: 24),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      AppLocalizations.of(context)!.personalInformation,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nationalIdController,
                    focusNode: _nationalIdFocus,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.nationalId,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (value) =>
                        FormValidators.nationalId(context, value),
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                  ),
                  if (_showErrors &&
                      FormValidators.nationalId(
                              context, _nationalIdController.text) !=
                          null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        key: const ValueKey('national_id_error_text'),
                        FormValidators.nationalId(
                            context, _nationalIdController.text)!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ImagePickerTile(
                    label: AppLocalizations.of(context)!.nationalIdPhoto,
                    file: _nationalIdImage,
                    onTap: () => _pickImage('national_id'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _licenseNumberController,
                    focusNode: _licenseNumberFocus,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.licenseNumber,
                      prefixIcon: const Icon(Icons.card_membership_outlined),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (value) =>
                        FormValidators.licenseNumber(context, value),
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                  ),
                  if (_showErrors &&
                      FormValidators.licenseNumber(
                              context, _licenseNumberController.text) !=
                          null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        key: const ValueKey('license_number_error_text'),
                        FormValidators.licenseNumber(
                            context, _licenseNumberController.text)!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ImagePickerTile(
                    label: AppLocalizations.of(context)!.licensePhoto,
                    file: _licenseImage,
                    onTap: () => _pickImage('license'),
                  ),
                  const SizedBox(height: 16),
                  _ImagePickerTile(
                    label: AppLocalizations.of(context)!.backgroundCheckPhoto,
                    file: _criminalRecordImage,
                    onTap: () => _pickImage('criminal_record'),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: context.divColor),
                  const SizedBox(height: 24),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      AppLocalizations.of(context)!.vehicleInformation,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  BlocProvider<VehicleCategoriesCubit>.value(
                    value: _vehicleCategoriesCubit!,
                    child: BlocBuilder<VehicleCategoriesCubit,
                        VehicleCategoriesState>(
                      builder: (context, state) {
                        if (state.isLoading) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        // [CATEGORY-FIX] قيم الـ fallback لازم تطابق فئات مركبة
                        // فيزيائية حقيقية (chk_dp_vehicle_category)، مش باقات
                        // تسعير زي "sedan"/"motorcycle" اللي كانت موجودة قبل كده.
                        final categories = state.categories.isNotEmpty
                            ? state.categories
                            : [
                                {
                                  'name': 'car',
                                  'display_name':
                                      AppLocalizations.of(context)!.sedan
                                },
                                {
                                  'name': 'bike',
                                  'display_name':
                                      AppLocalizations.of(context)!.motorcycle
                                }
                              ];

                        if (_vehicleCategory == null ||
                            !categories
                                .any((c) => c['name'] == _vehicleCategory)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() => _vehicleCategory =
                                  categories.first['name'] as String);
                            }
                          });
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _vehicleCategory,
                          decoration: InputDecoration(
                            labelText:
                                AppLocalizations.of(context)!.vehicleType,
                            prefixIcon:
                                const Icon(Icons.directions_car_rounded),
                          ),
                          dropdownColor: context.cardColor,
                          items: categories
                              .map((c) => DropdownMenuItem<String>(
                                    value: c['name'] as String,
                                    child: Text(c['display_name'] as String,
                                        style: TextStyle(
                                            color: context.textPrimary)),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _vehicleCategory = v),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehicleBrandController,
                    focusNode: _vehicleBrandFocus,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.vehicleBrand,
                      prefixIcon: const Icon(Icons.directions_car_outlined),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (value) =>
                        FormValidators.vehicleBrand(context, value),
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                  ),
                  if (_showErrors &&
                      FormValidators.vehicleBrand(
                              context, _vehicleBrandController.text) !=
                          null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        key: const ValueKey('vehicle_brand_error_text'),
                        FormValidators.vehicleBrand(
                            context, _vehicleBrandController.text)!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehicleModelController,
                    focusNode: _vehicleModelFocus,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.vehicleModel,
                      prefixIcon: const Icon(Icons.directions_car_outlined),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (value) =>
                        FormValidators.vehicleModel(context, value),
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                  ),
                  if (_showErrors &&
                      FormValidators.vehicleModel(
                              context, _vehicleModelController.text) !=
                          null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        key: const ValueKey('vehicle_model_error_text'),
                        FormValidators.vehicleModel(
                            context, _vehicleModelController.text)!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehicleYearController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.vehicleYear,
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (value) =>
                        FormValidators.vehicleYear(context, value),
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                  ),
                  if (_showErrors &&
                      FormValidators.vehicleYear(
                              context, _vehicleYearController.text) !=
                          null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        key: const ValueKey('vehicle_year_error_text'),
                        FormValidators.vehicleYear(
                            context, _vehicleYearController.text)!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehicleColorController,
                    focusNode: _vehicleColorFocus,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.vehicleColor,
                      prefixIcon: const Icon(Icons.palette_outlined),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (value) =>
                        FormValidators.vehicleColor(context, value),
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                  ),
                  if (_showErrors &&
                      FormValidators.vehicleColor(
                              context, _vehicleColorController.text) !=
                          null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        key: const ValueKey('vehicle_color_error_text'),
                        FormValidators.vehicleColor(
                            context, _vehicleColorController.text)!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehiclePlateController,
                    focusNode: _vehiclePlateFocus,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.plateNumber,
                      prefixIcon: const Icon(Icons.confirmation_number_outlined),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (value) =>
                        FormValidators.vehiclePlate(context, value),
                    onChanged: _showErrors ? (_) => setState(() {}) : null,
                  ),
                  if (_showErrors &&
                      FormValidators.vehiclePlate(
                              context, _vehiclePlateController.text) !=
                          null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        key: const ValueKey('vehicle_plate_error_text'),
                        FormValidators.vehiclePlate(
                            context, _vehiclePlateController.text)!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ImagePickerTile(
                    label: AppLocalizations.of(context)!.vehiclePhoto,
                    file: _vehicleImage,
                    onTap: () => _pickImage('vehicle'),
                  ),
                  const SizedBox(height: 32),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      return AppButton(
                        text: AppLocalizations.of(context)!.createAccount,
                        onPressed: _submit,
                        isLoading: _isUploading || _isSubmitting || state is AuthLoading,
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;

  const _ImagePickerTile({
    required this.label,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: file != null ? AppColors.primary : context.divColor,
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(file!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    color: context.textSecondary,
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
