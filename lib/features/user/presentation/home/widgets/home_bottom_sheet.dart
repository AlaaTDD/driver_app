// lib/features/user/presentation/home/widgets/home_bottom_sheet.dart
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../services/supabase_service.dart';
import '../../../../../core/localization/generated/app_localizations.dart';

class HomeBottomSheet extends StatefulWidget {
  final VoidCallback onSearchTap;

  const HomeBottomSheet({super.key, required this.onSearchTap});

  @override
  State<HomeBottomSheet> createState() => _HomeBottomSheetState();
}

class _HomeBottomSheetState extends State<HomeBottomSheet> {
  List<Map<String, dynamic>> _coupons = [];

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;
      final data = await SupabaseService.client
          .from('user_coupons')
          .select('*, coupons(*)')
          .eq('user_id', userId)
          .order('assigned_at', ascending: false);
      final unusedCoupons = (data as List)
          .where((json) => json['used_at'] == null)
          .toList();
      if (mounted) {
        setState(() {
          _coupons = unusedCoupons.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) { debugPrint('❌ Error: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.divColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            AppLocalizations.of(context)!.whereToGo,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: widget.onSearchTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.divColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: context.textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)!.searchDestination,
                    style: TextStyle(color: context.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          if (_coupons.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.availableCoupons,
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _coupons.length,
                itemBuilder: (context, index) {
                  final coupon = _coupons[index]['coupons'] as Map?;
                  final code = coupon?['code'] as String? ?? '';
                  final discount = coupon?['discount_value'];
                  final isPercent = coupon?['discount_type'] == 'percentage';
                  final l = AppLocalizations.of(context)!;
                  final label = isPercent
                      ? '${l.discount} ${discount?.toStringAsFixed(0)}%'
                      : '${l.discount} ${discount?.toStringAsFixed(0)} ${l.currencySar}';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      color: context.primaryTint,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          code,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
