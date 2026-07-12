import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/email_utils.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/form_validators.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/widgets/widgets.dart';

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _fullPhone = ''; // رقم التليفون الكامل مع كود البلد
  // يُفعّل بعد محاولة إرسال فاشلة، لعرض رسائل خطأ دائمة بجانب الاسم/الهاتف/الإيميل،
  // قابلة للإمساك عبر find.byKey في الاختبارات، مدفوعة مباشرة من نفس دوال FormValidators
  // الممررة لـ validator كل حقل أدناه — مصدر حقيقة واحد، لا منطق مكرر.
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    // لو المستخدم يعدّل كلمة المرور الأصلية بعد فشل أول محاولة إرسال، رسالة
    // خطأ "كلمتا المرور غير متطابقتين" تحت حقل التأكيد لازم تُعاد حسابها فورًا
    // (وليس فقط عند الكتابة داخل حقل التأكيد نفسه)، لأن confirmPassword
    // validator يعتمد على _passwordController.text كمرجع للمطابقة.
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
    super.dispose();
  }

  void _submit() {
    final isValid = _formKey.currentState!.validate();
    setState(() => _showErrors = !isValid);
    if (isValid) {
      context.read<AuthBloc>().add(SignUpUserRequested(
            name: _nameController.text.trim(),
            phone: _fullPhone,
            email: normalizeEmailInput(_emailController.text),
            password: _passwordController.text,
          ));
    } else {
      _focusFirstInvalidField();
    }
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('register_user_screen'),
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        title: Text(AppLocalizations.of(context)!.createUserAccount),
        centerTitle: true,
        leading: IconButton(
          key: const ValueKey('back_button'),
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            AppToast.success(
                AppLocalizations.of(context)!.accountCreatedSuccessfully);
            context.go(AppRoutes.userHome);
          } else if (state is AuthError) {
            AppToast.error(ErrorMapper.getErrorMessage(context, state.message));
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 36,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.personalInfo,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)!
                              .enterDataToCreateAccount,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _sectionLabel(AppLocalizations.of(context)!.basicData),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('name_field'),
                    controller: _nameController,
                    focusNode: _nameFocus,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fullName,
                      prefixIcon: const Icon(Icons.person_outlined),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (v) => FormValidators.name(context, v),
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
                  const SizedBox(height: 14),
                  AppPhoneField(
                    key: const ValueKey('phone_field'),
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
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('email_field'),
                    controller: _emailController,
                    focusNode: _emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.email,
                      hintText: AppLocalizations.of(context)!.emailExample,
                      prefixIcon: const Icon(Icons.email_outlined),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (v) => FormValidators.email(context, v),
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
                  const SizedBox(height: 24),
                  _sectionLabel(AppLocalizations.of(context)!.password),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.password,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (v) => FormValidators.password(context, v),
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
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocus,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.confirmPassword,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                    ),
                    validator: (v) => FormValidators.confirmPassword(
                      context,
                      v,
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
                  const SizedBox(height: 36),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) => AppButton(
                      key: const ValueKey('signup_button'),
                      text: AppLocalizations.of(context)!.createAccount,
                      onPressed: _submit,
                      isLoading: state is AuthLoading,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: context.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}
