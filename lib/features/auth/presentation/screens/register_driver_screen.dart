
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
import '../../../../core/error/error_mapper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../bloc/vehicle_types_cubit.dart';

class RegisterDriverScreen extends StatefulWidget {
  const RegisterDriverScreen({super.key});

  @override
  State<RegisterDriverScreen> createState() => _RegisterDriverScreenState();
}

class _RegisterDriverScreenState extends State<RegisterDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehiclePlateController = TextEditingController();

  File? _nationalIdImage;
  File? _licenseImage;
  File? _criminalRecordImage;
  File? _vehicleImage;

  final ImagePicker _picker = ImagePicker();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isUploading = false;
  String? _vehicleType;

  @override
  void initState() {
    super.initState();
  }



  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nationalIdController.dispose();
    _licenseNumberController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _vehiclePlateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        switch (type) {
          case 'national_id':
            _nationalIdImage = File(image.path);
            break;
          case 'license':
            _licenseImage = File(image.path);
            break;
          case 'criminal_record':
            _criminalRecordImage = File(image.path);
            break;
          case 'vehicle':
            _vehicleImage = File(image.path);
            break;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      AppToast.error(AppLocalizations.of(context)!.passwordsNotMatch);
      return;
    }
    if (_nationalIdImage == null ||
        _licenseImage == null ||
        _criminalRecordImage == null ||
        _vehicleImage == null) {
      AppToast.error(AppLocalizations.of(context)!.uploadAllDocuments);
      return;
    }

    setState(() => _isUploading = true);
    final repo = context.read<AuthRepositoryImpl>();
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

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
        if (mounted) setState(() => _isUploading = false);
        return;
      }
      if (i == 0) nationalIdUrl = url;
      if (i == 1) licenseUrl = url;
      if (i == 2) criminalRecordUrl = url;
      if (i == 3) vehicleUrl = url;
    }

    setState(() => _isUploading = false);

    if (!mounted) return;
    context.read<AuthBloc>().add(SignUpDriverRequested(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      nationalId: _nationalIdController.text.trim(),
      nationalIdImageUrl: nationalIdUrl!,
      licenseNumber: _licenseNumberController.text.trim(),
      licenseImageUrl: licenseUrl!,
      criminalRecordUrl: criminalRecordUrl!,
      vehicleType: _vehicleType ?? 'sedan',
      vehicleBrand: _vehicleBrandController.text.trim(),
      vehicleModel: _vehicleModelController.text.trim(),
      vehicleYear: int.tryParse(_vehicleYearController.text) ?? 2020,
      vehicleColor: _vehicleColorController.text.trim(),
      vehiclePlate: _vehiclePlateController.text.trim(),
      vehicleImageUrl: vehicleUrl!,
    ));
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
            context.go(AppRoutes.pendingVerification);
          } else if (state is AuthError) {
            AppToast.error(ErrorMapper.getErrorMessage(context, state.message));
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fullName,
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterFullName;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.phone,
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterPhone;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.email,
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.password,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterPassword;
                      }
                      if (value.length < 6) {
                        return AppLocalizations.of(context)!.passwordMinLength;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.confirmPassword,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.pleaseConfirmPassword;
                      }
                      return null;
                    },
                  ),
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
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.nationalId,
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterNationalId;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _ImagePickerTile(
                    label: AppLocalizations.of(context)!.nationalIdPhoto,
                    file: _nationalIdImage,
                    onTap: () => _pickImage('national_id'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _licenseNumberController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.licenseNumber,
                      prefixIcon: Icon(Icons.card_membership_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterLicenseNumber;
                      }
                      return null;
                    },
                  ),
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
                      AppLocalizations.of(context)!.requiredDocuments,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  BlocProvider(
                    create: (context) => VehicleTypesCubit()..fetchVehicleTypes(),
                    child: BlocBuilder<VehicleTypesCubit, VehicleTypesState>(
                      builder: (context, state) {
                        if (state.isLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        
                        final types = state.vehicleTypes.isNotEmpty
                            ? state.vehicleTypes
                            : [
                                {'name': 'sedan', 'display_name': AppLocalizations.of(context)!.sedan},
                                {'name': 'motorcycle', 'display_name': AppLocalizations.of(context)!.motorcycle}
                              ];

                        if (_vehicleType == null || !types.any((t) => t['name'] == _vehicleType)) {
                           _vehicleType = types.first['name'] as String;
                        }

                        return DropdownButtonFormField<String>(
                          value: _vehicleType,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.vehicleType,
                            prefixIcon: const Icon(Icons.directions_car_rounded),
                          ),
                          dropdownColor: context.cardColor,
                          items: types
                              .map((t) => DropdownMenuItem<String>(
                                    value: t['name'] as String,
                                    child: Text(t['display_name'] as String,
                                        style: TextStyle(color: context.textPrimary)),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _vehicleType = v),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehicleBrandController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.vehicleBrand,
                      prefixIcon: Icon(Icons.directions_car_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterVehicleBrand;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehicleModelController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.vehicleModel,
                      prefixIcon: Icon(Icons.directions_car_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterVehicleModel;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehicleYearController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.vehicleYear,
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterVehicleYear;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehicleColorController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.vehicleColor,
                      prefixIcon: Icon(Icons.palette_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterVehicleColor;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vehiclePlateController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.plateNumber,
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.enterPlateNumber;
                      }
                      return null;
                    },
                  ),
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
                        isLoading: _isUploading || state is AuthLoading,
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
