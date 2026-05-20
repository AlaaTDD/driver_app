import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../data/models/user_wallet_model.dart';
import '../../data/models/wallet_transaction_model.dart';
import '../cubit/user_wallet_cubit.dart';
import '../../../../core/widgets/app_button.dart';

// ─── Number Formatter ─────────────────────────────────────────────────────────

NumberFormat _getCurrencyFormat(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return NumberFormat.currency(
      locale: Localizations.localeOf(context).languageCode,
      symbol: l.currencySar,
      decimalDigits: 2);
}

NumberFormat _getCompactCurrencyFormat(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return NumberFormat.currency(
      locale: Localizations.localeOf(context).languageCode,
      symbol: l.currencySar,
      decimalDigits: 0);
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class UserWalletScreen extends StatefulWidget {
  const UserWalletScreen({super.key});

  @override
  State<UserWalletScreen> createState() => _UserWalletScreenState();
}

class _UserWalletScreenState extends State<UserWalletScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWallet());
  }

  void _loadWallet() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      context.read<UserWalletCubit>().load(auth.user.id);
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: BlocConsumer<UserWalletCubit, UserWalletState>(
        listener: (context, state) {
          if (state is UserWalletLoaded) {
            _fadeCtrl.forward(from: 0);
          }
        },
        builder: (context, state) {
          if (state is UserWalletLoading || state is UserWalletInitial) {
            return _buildShimmer();
          }
          if (state is UserWalletError) {
            return _buildError(
              state.message == 'failedLoadWallet'
                  ? AppLocalizations.of(context)!.failedLoadWallet(
                      AppLocalizations.of(context)!.errorUnexpected)
                  : state.message,
            );
          }
          if (state is UserWalletLoaded) return _buildLoaded(state);
          return const SizedBox();
        },
      ),
    );
  }

  // ── Loaded ────────────────────────────────────────────────────────────────
  Widget _buildLoaded(UserWalletLoaded s) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverHeader(context, s.wallet),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)!.transactionHistory,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.elevatedColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!
                          .totalTransactionsLabel(s.transactions.length),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          s.transactions.isEmpty
              ? SliverFillRemaining(
                  child: _buildEmptyState(
                      AppLocalizations.of(context)!.noTransactionsYet,
                      Icons.receipt_long_outlined,
                      AppLocalizations.of(context)!.transactionsWillAppearHere))
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) =>
                          _buildTransactionCard(context, s.transactions[i]),
                      childCount: s.transactions.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildSliverHeader(BuildContext context, UserWalletModel wallet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      stretch: true,
      backgroundColor: isDark
          ? context.bgColor
          : AppColors.primaryDark, // Slate 900 / Blue 900
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      title: Text(
        AppLocalizations.of(context)!.myWallet,
        style: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: [StretchMode.zoomBackground],
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      context.elevatedColor,
                      context.bgColor,
                      context.bgColor
                    ] // Slate
                  : [
                      AppColors.primary,
                      AppColors.primaryDark,
                      AppColors.primaryDark
                    ], // Blue
            ),
          ),
          child: Stack(
            children: [
              // Glassmorphism abstract shapes
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.white.withValues(alpha: 0.1),
                        AppColors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -60,
                bottom: 20,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.white.withValues(alpha: 0.08),
                        AppColors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_wallet_rounded,
                                color: AppColors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!
                                  .availableBalanceLabel,
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                _getCurrencyFormat(context)
                                    .format(wallet.balance)
                                    .replaceAll(
                                        AppLocalizations.of(context)!.currencySar, ''),
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.currencySar,
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.7),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _buildStatChip(
                            icon: Icons.add_card_rounded,
                            label: AppLocalizations.of(context)!.totalTopUp,
                            value: _getCompactCurrencyFormat(context)
                                .format(wallet.totalToppedUp),
                          ),
                          const SizedBox(width: 12),
                          _buildStatChip(
                            icon: Icons.shopping_bag_rounded,
                            label: AppLocalizations.of(context)!.totalSpent,
                            value: _getCompactCurrencyFormat(context)
                                .format(wallet.totalSpent),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(
      {required IconData icon, required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _adaptiveIconBg(Color iconColor, BuildContext context) {
    return context.isDark
        ? iconColor.withValues(alpha: 0.15)
        : iconColor.withValues(alpha: 0.08);
  }

  Widget _buildTransactionCard(
      BuildContext context, WalletTransactionModel txn) {
    final isCredit = txn.isCredit;
    final (icon, iconColor, lightBg, label) = switch (txn.type) {
      WalletTransactionType.tripEarning => (
          Icons.directions_car_rounded,
          AppColors.success,
          AppColors.successLight,
          AppLocalizations.of(context)!.tripEarning
        ),
      WalletTransactionType.withdrawal => (
          Icons.arrow_upward_rounded,
          AppColors.warning,
          AppColors.warningLight,
          AppLocalizations.of(context)!.withdrawal
        ),
      WalletTransactionType.withdrawalRefund => (
          Icons.undo_rounded,
          AppColors.primary,
          context.textPrimary,
          AppLocalizations.of(context)!.withdrawalRefund
        ),
      WalletTransactionType.bonus => (
          Icons.star_rounded,
          AppColors.warning,
          AppColors.warningLight,
          AppLocalizations.of(context)!.bonus
        ),
      WalletTransactionType.couponSubsidy => (
          Icons.local_offer_rounded,
          AppColors.purple,
          AppColors.purpleLight,
          AppLocalizations.of(context)!.couponSubsidy
        ),
      WalletTransactionType.penalty => (
          Icons.remove_circle_rounded,
          AppColors.error,
          AppColors.errorLight,
          AppLocalizations.of(context)!.penalty
        ),
      WalletTransactionType.topUp => (
          Icons.add_card_rounded,
          AppColors.success,
          AppColors.successLight,
          AppLocalizations.of(context)!.topUp
        ),
      WalletTransactionType.refund => (
          Icons.keyboard_return_rounded,
          AppColors.primary,
          context.textPrimary,
          AppLocalizations.of(context)!.refund
        ),
      WalletTransactionType.tripPayment => (
          Icons.payment_rounded,
          AppColors.indigo,
          AppColors.indigoLight,
          AppLocalizations.of(context)!.tripPayment
        ),
      WalletTransactionType.adjustment => (
          Icons.swap_horiz_rounded,
          AppColors.grey,
          AppColors.grey,
          AppLocalizations.of(context)!.adjustment
        ),
    };
    final bgColor = _adaptiveIconBg(iconColor, context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                      fontSize: 15),
                ),
                if (txn.description != null && txn.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    txn.description!,
                    style:
                        TextStyle(color: context.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 12,
                        color: context.textSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(txn.createdAt),
                      style: TextStyle(
                          color: context.textSecondary.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : ''}${_getCurrencyFormat(context).format(txn.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isCredit ? AppColors.success : AppColors.error,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.elevatedColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppLocalizations.of(context)!.balanceAfterLabel(
                      _getCompactCurrencyFormat(context)
                          .format(txn.balanceAfter)),
                  style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, IconData icon, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(title,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              style: TextStyle(
                  color: context.textSecondary, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            height: 380,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.4),
                  AppColors.primary.withValues(alpha: 0.2),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, __) => Container(
                height: 90,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.error),
          ),
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context)!.anErrorOccurred,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary, fontSize: 14)),
          ),
          const SizedBox(height: 32),
          AppButton(
            text: AppLocalizations.of(context)!.retryButton,
            onPressed: _loadWallet,
            leadingIcon: Icons.refresh_rounded,
            size: AppButtonSize.md,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    final today = DateTime.now();
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;

    final timeStr =
        DateFormat('h:mm a', Localizations.localeOf(context).languageCode)
            .format(d);
    if (isToday) return AppLocalizations.of(context)!.todayAtTime(timeStr);

    return DateFormat('d MMM, yyyy - h:mm a',
            Localizations.localeOf(context).languageCode)
        .format(d);
  }
}
