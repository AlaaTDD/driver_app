import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/email_utils.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  // يُفعّل بعد محاولة إرسال فاشلة، لعرض رسائل الخطأ كعناصر دائمة في
  // الشجرة (قابلة للإمساك عبر find.byKey)، مدفوعة مباشرة من نتيجة
  // _formKey.currentState!.validate() الحقيقية، وليس من نسخة معزولة يحسبها الحقل.
  bool _showErrors = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final isValid = _formKey.currentState!.validate();
    setState(() => _showErrors = !isValid);
    if (isValid) {
      context.read<AuthBloc>().add(SignInRequested(
            email: normalizeEmailInput(_emailController.text),
            password: _passwordController.text,
          ));
    }
  }

  void _showForgotPassword(BuildContext context) {
    final emailCtrl = TextEditingController();
    final l = AppLocalizations.of(context)!;
    // خارج نطاق builder المتكرر عمداً: لو وضعناه داخل الـ builder نفسه،
    // كان سيتصفر لـ false من جديد مع كل إعادة بناء يستدعيها setDialogState،
    // ويصبح الشرط ميت دائمًا (هذا الخطأ الذي رصده flutter analyze).
    bool linkSent = false;
    showDialog<void>(
      context: context,
      // key: يسمح لاختبارات التكامل بانتظار ظهور الحوار عبر waitForKey، بنفس
      // الطريقة التي تنتظر بها أي شاشة كاملة، رغم أن هذا فعليًا AlertDialog.
      builder: (ctx) => StatefulBuilder(
        key: const ValueKey('forgot_password_screen'),
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(l.forgotPasswordTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.forgotPasswordDesc),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('reset_email_field'),
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(hintText: l.emailExample),
                ),
                // عنصر دائم (وليس toast متلاشيًا) يبقى ظاهرًا في شجرة الودجت
                // بعد الإرسال الناجح — قابل للإمساك عبر find.byKey في الاختبارات.
                if (linkSent) ...[
                  const SizedBox(height: 12),
                  Text(
                    key: const ValueKey('reset_success_message'),
                    l.forgotPasswordSent,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l.cancel),
              ),
              TextButton(
                key: const ValueKey('send_reset_link_button'),
                onPressed: () async {
                  final email = emailCtrl.text.trim();
                  if (email.isEmpty) return;
                  try {
                    await SupabaseService.client.auth
                        .resetPasswordForEmail(email);
                    setDialogState(() => linkSent = true);
                    if (mounted) AppToast.success(l.forgotPasswordSent);
                  } catch (_) {
                    if (mounted) AppToast.error(l.errorUnexpected);
                  }
                },
                child: Text(l.send),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(
            state.user.role == 'driver'
                ? AppRoutes.driverHome
                : AppRoutes.userHome,
          );
        } else if (state is AuthDriverPending) {
          context.go(AppRoutes.pendingVerification);
        } else if (state is AuthDriverBlocked) {
          // [AUTH-BLOCKED FIX] سائق محظور يحاول تسجيل الدخول من شاشة التسجيل
          // (نادر لكنه ممكن من خلال Realtime event يصل قبل إتمام التوجيه).
          context.go(AppRoutes.driverBlocked);
        } else if (state is AuthError) {
          AppToast.error(ErrorMapper.getErrorMessage(context, state.message));
        }
      },
      child: Scaffold(
        key: const ValueKey('login_screen'),
        backgroundColor: context.bgColor,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.45,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.9,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          Container(
                            width: 80,
                            height: 80,
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
                                      AppColors.primary.withValues(alpha: 0.38),
                                  blurRadius: 28,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.directions_car_rounded,
                              size: 40,
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            AppLocalizations.of(context)!.appName,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.loginTitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 48),
                          _FloatingInput(
                            fieldKey: const ValueKey('email_field'),
                            errorKey: const ValueKey('email_error_text'),
                            showError: _showErrors,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            label: AppLocalizations.of(context)!.email,
                            hint: AppLocalizations.of(context)!.emailExample,
                            icon: Icons.email_outlined,
                            validator: (v) => (v == null || v.isEmpty)
                                ? AppLocalizations.of(context)!.enterEmail
                                : null,
                          ),
                          const SizedBox(height: 20),
                          _FloatingInput(
                            fieldKey: const ValueKey('password_field'),
                            errorKey: const ValueKey('password_error_text'),
                            showError: _showErrors,
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (String? _) => _submit(),
                            label: AppLocalizations.of(context)!.password,
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: context.textSecondary,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? AppLocalizations.of(context)!.enterPassword
                                : null,
                          ),
                          const SizedBox(height: 36),
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, state) => _GradientButton(
                              key: const ValueKey('login_button'),
                              text: AppLocalizations.of(context)!.login,
                              onPressed: _submit,
                              isLoading: state is AuthLoading,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            key: const ValueKey('forgot_password_button'),
                            onPressed: () => _showForgotPassword(context),
                            child: Text(
                              AppLocalizations.of(context)!.forgotPassword,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.noAccount,
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                key: const ValueKey('go_to_signup_button'),
                                onTap: () => context.push(AppRoutes.register),
                                child: Text(
                                  AppLocalizations.of(context)!.registerNow,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingInput extends StatefulWidget {
  final Key? fieldKey;
  final Key? errorKey;
  // يتم ضبط هذه القيمة من الفورم الأب مباشرةً بعد نتيجة
  // _formKey.currentState!.validate() الحقيقية — الحقل نفسه لا يحسب صحته بمعزل.
  final bool showError;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final String label;
  final String hint;
  final IconData icon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _FloatingInput({
    this.fieldKey,
    this.errorKey,
    this.showError = false,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    required this.label,
    required this.hint,
    required this.icon,
    this.suffixIcon,
    this.validator,
  });

  @override
  State<_FloatingInput> createState() => _FloatingInputState();
}

class _FloatingInputState extends State<_FloatingInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  // مع كل ضغطة، نعيد بناء الودجت فقط لتحديث رسالة الخطأ المعروضة حيًّا دون
  // انتظار إرسال جديد؛ قيمة showError نفسها تبقى مملوكة للأب.
  void _onTextChanged() {
    if (widget.showError) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // مصدر الحقيقة الوحيد: نفس دالة الـ validator الممررة لـ TextFormField أدناه.
    final errorText = widget.showError
        ? widget.validator?.call(widget.controller.text)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorText != null ? AppColors.error : context.divColor,
              width: 1,
            ),
          ),
          child: TextFormField(
            key: widget.fieldKey,
            controller: widget.controller,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onFieldSubmitted,
            style: TextStyle(
              fontSize: 15,
              color: context.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: 15,
                color: context.textSecondary,
              ),
              prefixIcon:
                  Icon(widget.icon, color: context.textSecondary, size: 22),
              suffixIcon: widget.suffixIcon,
              border: InputBorder.none,
              // نُسكت رسالة الخطأ المدمجة الافتراضية لتفادي التكرار مع الرسالة
              // الدائمة أسفل الحقل؛ المنطق نفسه (validator) لا يتغير.
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: widget.validator,
            autovalidateMode: AutovalidateMode.disabled,
          ),
        ),
        // رسالة خطأ دائمة (وليس toast متلاشيًا) محسوبة مباشرةً من نتيجة الـ
        // validator الحقيقية، تظهر فقط بعد محاولة إرسال فاشلة وتختفي فور التصحيح.
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              key: widget.errorKey,
              errorText,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;

  const _GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.32),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.white),
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
