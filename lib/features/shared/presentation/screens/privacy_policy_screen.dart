import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  bool _isAr(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  String _t(BuildContext context, String ar, String en) =>
      _isAr(context) ? ar : en;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        title: Text(l.privacyPolicy),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _IntroCard(
            title: _t(context, 'خصوصيتك في Snapix', 'Your Privacy in Snapix'),
            body: _t(
              context,
              'نستخدم بياناتك لتشغيل الرحلات، تحسين الأمان، دعم الحسابات، ومعالجة المدفوعات داخل التطبيق.',
              'We use your data to run trips, improve safety, support accounts, and process in-app payments.',
            ),
          ),
          const SizedBox(height: 16),
          _PolicySection(
            icon: Icons.person_search_rounded,
            title: _t(context, 'البيانات التي نجمعها', 'Data We Collect'),
            items: [
              _t(context, 'بيانات الحساب مثل الاسم ورقم الهاتف والصورة.',
                  'Account data such as name, phone number, and profile photo.'),
              _t(context, 'مواقع الرحلات ونقاط الالتقاء والتتبع أثناء الرحلة.',
                  'Trip locations, meeting points, and live tracking while a trip is active.'),
              _t(context, 'بيانات السائق والمركبة والمستندات المطلوبة للتحقق.',
                  'Driver, vehicle, and verification document data.'),
              _t(context, 'رسائل الدعم والشكاوى والتقييمات.',
                  'Support messages, complaints, and ratings.'),
            ],
          ),
          _PolicySection(
            icon: Icons.lock_rounded,
            title: _t(context, 'كيف نحمي البيانات', 'How We Protect Data'),
            items: [
              _t(
                  context,
                  'نستخدم صلاحيات قاعدة البيانات لمنع الوصول غير المصرح.',
                  'Database permissions limit unauthorized access.'),
              _t(
                  context,
                  'المفاتيح السرية وخدمات الذكاء الاصطناعي تعمل من الخادم وليس من التطبيق مباشرة.',
                  'Secrets and AI providers are handled server-side, not directly in the app.'),
              _t(
                  context,
                  'الصور والمرفقات ترفع عبر خدمة آمنة وتخضع لفحص نوع الملف.',
                  'Images and attachments are uploaded through a secured service with file type validation.'),
            ],
          ),
          _PolicySection(
            icon: Icons.share_rounded,
            title: _t(context, 'مشاركة البيانات', 'Data Sharing'),
            items: [
              _t(
                  context,
                  'نشارك بيانات الرحلة الضرورية فقط بين المستخدم والسائق.',
                  'Only necessary trip data is shared between rider and driver.'),
              _t(context, 'لا نبيع بياناتك الشخصية لأطراف خارجية.',
                  'We do not sell your personal data to third parties.'),
              _t(
                  context,
                  'قد نشارك بيانات محدودة عند وجود التزام قانوني أو أمني.',
                  'Limited data may be shared for legal or safety obligations.'),
            ],
          ),
          _PolicySection(
            icon: Icons.manage_accounts_rounded,
            title: _t(context, 'حقوقك', 'Your Rights'),
            items: [
              _t(context, 'يمكنك تعديل بياناتك من الملف الشخصي.',
                  'You can edit your data from the profile page.'),
              _t(context, 'يمكنك طلب الدعم أو تقديم شكوى من داخل التطبيق.',
                  'You can contact support or file a complaint in the app.'),
              _t(context, 'يمكنك طلب مراجعة بيانات الحساب عند الحاجة.',
                  'You can request account data review when needed.'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              context,
              'آخر تحديث: مايو 2026',
              'Last updated: May 2026',
            ),
            style: TextStyle(color: context.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final String title;
  final String body;

  const _IntroCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_rounded,
              color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;

  const _PolicySection({
    required this.icon,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
