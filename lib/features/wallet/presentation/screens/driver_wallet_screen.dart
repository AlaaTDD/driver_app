import 'package:flutter/material.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../cubit/wallet_cubit.dart';
import '../../data/models/driver_wallet_model.dart';
import '../../data/models/wallet_transaction_model.dart';
import '../../data/models/withdrawal_request_model.dart';

// ─── Number Formatter ─────────────────────────────────────────────────────────

NumberFormat _getCurrencyFormat(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return NumberFormat.currency(locale: Localizations.localeOf(context).languageCode, symbol: l.egp, decimalDigits: 2);
}

NumberFormat _getCompactCurrencyFormat(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return NumberFormat.currency(locale: Localizations.localeOf(context).languageCode, symbol: l.egp, decimalDigits: 0);
}

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      context.read<WalletCubit>().load(auth.user.id);
    }
  }

  String _localizedError(String key, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return switch (key) {
      'failedLoadWallet' => l.failedLoadWallet(''),
      'errorInsufficientBalance' => l.errorInsufficientBalance(''),
      'minAmount50' => l.minAmount50,
      'errorWithdrawalPending' => l.errorWithdrawalPending,
      'errorWalletNotFound' => l.errorWalletNotFound,
      'errorUnauthorizedOperation' => l.errorUnauthorizedOperation,
      'errorUnexpected' => l.errorUnexpected,
      'errorOccurredWithDetails' => l.errorOccurredWithDetails(''),
      _ => key,
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: BlocConsumer<WalletCubit, WalletState>(
        listener: (context, state) {
          if (state is WalletError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_localizedError(state.message, context)), backgroundColor: AppColors.error),
            );
          }
          if (state is WithdrawalSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.withdrawalSuccessMsg(state.amount.toString())), backgroundColor: AppColors.success),
            );
            _loadData(); // Refresh data
          }
          if (state is WithdrawalFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_localizedError(state.error, context)), backgroundColor: AppColors.error),
            );
          }
          if (state is WalletLoaded) {
            _fadeCtrl.forward(from: 0);
          }
        },
        builder: (context, state) {
          if (state is WalletLoading) return _buildShimmer();
          if (state is WalletError) return _buildError(_localizedError(state.message, context));
          if (state is WalletLoaded) return _buildLoaded(state);
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildLoaded(WalletLoaded state) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          _buildSliverHeader(context, state.wallet),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: _buildTabBar(context),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTransactionsList(context, state.transactions),
            _buildWithdrawalsList(context, state.withdrawals),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context, DriverWalletModel wallet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E3A8A), // Slate 900 / Blue 900
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      title: Text(AppLocalizations.of(context)!.driverWallet,
        style: TextStyle(
          color: Colors.white,
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
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A), const Color(0xFF020617)] // Slate
                : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8), const Color(0xFF1E3A8A)], // Blue
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
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.0),
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
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.0),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.availableToWithdraw,
                              style: TextStyle(
                                color: Colors.white,
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
                                _getCurrencyFormat(context).format(wallet.balance).replaceAll(AppLocalizations.of(context)!.egp, ''),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.5,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.egp,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (wallet.pendingWithdrawal > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2), // Amber
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.hourglass_empty_rounded, color: Color(0xFFFCD34D), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '${AppLocalizations.of(context)!.pendingPrefix}${_getCompactCurrencyFormat(context).format(wallet.pendingWithdrawal)}',
                                style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          _buildStatChip(
                            icon: Icons.trending_up_rounded,
                            label: AppLocalizations.of(context)!.thisWeek,
                            value: _getCompactCurrencyFormat(context).format(wallet.earningsLastWeek),
                          ),
                          const SizedBox(width: 12),
                          _buildStatChip(
                            icon: Icons.calendar_month_rounded,
                            label: AppLocalizations.of(context)!.last30Days,
                            value: _getCompactCurrencyFormat(context).format(wallet.earningsLast30Days),
                          ),
                          const SizedBox(width: 12),
                          _buildStatChip(
                            icon: Icons.directions_car_rounded,
                            label: AppLocalizations.of(context)!.trips,
                            value: '${wallet.completedTrips}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: wallet.balance >= 50
                              ? () => _showWithdrawalSheet(context, wallet)
                              : null,
                          icon: const Icon(Icons.account_balance_rounded, size: 20),
                          label: Text(
                            wallet.balance >= 50 ? AppLocalizations.of(context)!.requestWithdrawal : AppLocalizations.of(context)!.minWithdrawal50,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.cardColor,
                            foregroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1D4ED8),
                            disabledBackgroundColor: context.cardColor.withValues(alpha: 0.2),
                            disabledForegroundColor: context.textSecondary.withValues(alpha: 0.6),
                            elevation: wallet.balance >= 50 ? 8 : 0,
                            shadowColor: Colors.black.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
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

  Widget _buildStatChip({required IconData icon, required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.5),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.divColor.withValues(alpha: 0.5)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: context.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: AppLocalizations.of(context)!.transactions),
          Tab(text: AppLocalizations.of(context)!.withdrawalRequests),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(BuildContext context, List<WalletTransactionModel> txns) {
    if (txns.isEmpty) {
      return _buildEmptyState(AppLocalizations.of(context)!.noTransactionsYet, Icons.receipt_long_outlined, AppLocalizations.of(context)!.earningsWillAppearHere);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: txns.length,
      itemBuilder: (context, i) => _buildTransactionCard(context, txns[i]),
    );
  }

  Color _adaptiveIconBg(Color iconColor, BuildContext context) {
    return context.isDark
        ? iconColor.withValues(alpha: 0.15)
        : iconColor.withValues(alpha: 0.08);
  }

  Widget _buildTransactionCard(BuildContext context, WalletTransactionModel txn) {
    final isCredit = txn.isCredit;
    final (icon, iconColor, lightBg, label) = switch (txn.type) {
      WalletTransactionType.tripEarning     => (Icons.directions_car_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), AppLocalizations.of(context)!.tripEarning),
      WalletTransactionType.withdrawal      => (Icons.arrow_upward_rounded, const Color(0xFFF97316), const Color(0xFFFFF7ED), AppLocalizations.of(context)!.withdrawal),
      WalletTransactionType.withdrawalRefund=> (Icons.undo_rounded, const Color(0xFF3B82F6), const Color(0xFFEFF6FF), AppLocalizations.of(context)!.withdrawalRefund),
      WalletTransactionType.bonus           => (Icons.star_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), AppLocalizations.of(context)!.bonus),
      WalletTransactionType.couponSubsidy   => (Icons.local_offer_rounded, const Color(0xFF8B5CF6), const Color(0xFFF5F3FF), AppLocalizations.of(context)!.couponSubsidy),
      WalletTransactionType.penalty         => (Icons.remove_circle_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2), AppLocalizations.of(context)!.penalty),
      WalletTransactionType.topUp           => (Icons.add_card_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5), AppLocalizations.of(context)!.topUp),
      WalletTransactionType.refund          => (Icons.keyboard_return_rounded, const Color(0xFF3B82F6), const Color(0xFFEFF6FF), AppLocalizations.of(context)!.refund),
      WalletTransactionType.tripPayment     => (Icons.payment_rounded, const Color(0xFF6366F1), const Color(0xFFEEF2FF), AppLocalizations.of(context)!.tripPayment),
      WalletTransactionType.adjustment      => (Icons.swap_horiz_rounded, Colors.grey.shade600, Colors.grey.shade100, AppLocalizations.of(context)!.adjustment),
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
            color: Colors.black.withValues(alpha: 0.02),
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
                  style: TextStyle(fontWeight: FontWeight.w800, color: context.textPrimary, fontSize: 15),
                ),
                if (txn.description != null && txn.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    txn.description!,
                    style: TextStyle(color: context.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 12, color: context.textSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(txn.createdAt),
                      style: TextStyle(color: context.textSecondary.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600),
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
                  color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
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
                  '${AppLocalizations.of(context)!.balancePrefix}${_getCompactCurrencyFormat(context).format(txn.balanceAfter)}',
                  style: TextStyle(color: context.textSecondary, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalsList(BuildContext context, List<WithdrawalRequestModel> withdrawals) {
    if (withdrawals.isEmpty) {
      return _buildEmptyState(AppLocalizations.of(context)!.noWithdrawalRequests, Icons.account_balance_outlined, AppLocalizations.of(context)!.canRequestWithdrawalWhenReachedMin);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: withdrawals.length,
      itemBuilder: (context, i) => _buildWithdrawalCard(context, withdrawals[i]),
    );
  }

  Widget _buildWithdrawalCard(BuildContext context, WithdrawalRequestModel w) {
    final (statusLabel, statusColor, lightStatusBg) = switch (w.status) {
      WithdrawalStatus.completed  => (AppLocalizations.of(context)!.statusCompleted, const Color(0xFF10B981), const Color(0xFFECFDF5)),
      WithdrawalStatus.rejected   => (AppLocalizations.of(context)!.statusRejected, const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
      WithdrawalStatus.cancelled  => (AppLocalizations.of(context)!.statusCancelled, Colors.grey.shade600, Colors.grey.shade100),
      WithdrawalStatus.processing => (AppLocalizations.of(context)!.statusProcessing, const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
      WithdrawalStatus.approved   => (AppLocalizations.of(context)!.statusApproved, const Color(0xFF0EA5E9), const Color(0xFFE0F2FE)),
      WithdrawalStatus.pending    => (AppLocalizations.of(context)!.statusPending, const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
    };
    final statusBg = context.isDark
        ? statusColor.withValues(alpha: 0.15)
        : lightStatusBg;
    
    final methodStr = switch (w.paymentMethod) {
      WithdrawalMethod.vodafoneCash => AppLocalizations.of(context)!.vodafoneCash,
      WithdrawalMethod.instapay    => AppLocalizations.of(context)!.instapay,
      WithdrawalMethod.orangeMoney => AppLocalizations.of(context)!.orangeMoney,
      WithdrawalMethod.bankTransfer => AppLocalizations.of(context)!.bankTransfer,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              color: statusBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.account_balance_wallet_rounded, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.withdrawalViaMethod(methodStr),
                  style: TextStyle(fontWeight: FontWeight.w800, color: context.textPrimary, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 12, color: context.textSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(w.createdAt),
                      style: TextStyle(color: context.textSecondary.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _getCurrencyFormat(context).format(w.amount),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: context.textPrimary, letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800),
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
          Text(title, style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              style: TextStyle(color: context.textSecondary, fontSize: 14, height: 1.5),
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
                  color: Colors.grey.withValues(alpha: 0.1),
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
            child: Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
          ),
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context)!.anErrorOccurred, style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(msg, textAlign: TextAlign.center, style: TextStyle(color: context.textSecondary, fontSize: 14)),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(AppLocalizations.of(context)!.retryButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Withdrawal Bottom Sheet ───────────────────────────────────────────────

  void _showWithdrawalSheet(BuildContext context, DriverWalletModel wallet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<WalletCubit>(),
        child: _WithdrawalSheet(wallet: wallet),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    final today = DateTime.now();
    final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
    
    final timeStr = DateFormat('h:mm a', Localizations.localeOf(context).languageCode).format(d);
    if (isToday) return AppLocalizations.of(context)!.todayAtTime(timeStr);
    
    return DateFormat('d MMM, yyyy - h:mm a', Localizations.localeOf(context).languageCode).format(d);
  }
}

// ─── Withdrawal Bottom Sheet Widget ───────────────────────────────────────────

class _WithdrawalSheet extends StatefulWidget {
  final DriverWalletModel wallet;
  const _WithdrawalSheet({required this.wallet});

  @override
  State<_WithdrawalSheet> createState() => _WithdrawalSheetState();
}

class _WithdrawalSheetState extends State<_WithdrawalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();

  String _selectedMethod = 'vodafone_cash';

  List<(String, String, IconData)> get _methods => [
    ('vodafone_cash', AppLocalizations.of(context)!.vodafoneCash, Icons.phone_android_rounded),
    ('instapay', AppLocalizations.of(context)!.instapay, Icons.account_balance_rounded),
    ('orange_money', AppLocalizations.of(context)!.orangeMoney, Icons.phone_android_rounded),
    ('bank_transfer', AppLocalizations.of(context)!.bankTransfer, Icons.account_balance_wallet_rounded),
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _ibanCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    Map<String, dynamic> accountDetails;

    if (_selectedMethod == 'bank_transfer') {
      accountDetails = {'iban': _ibanCtrl.text.trim(), 'bank': _bankCtrl.text.trim()};
    } else {
      accountDetails = {'phone': _phoneCtrl.text.trim()};
    }

    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    Navigator.pop(context);

    context.read<WalletCubit>().requestWithdrawal(
      driverId: auth.user.id,
      amount: amount,
      paymentMethod: _selectedMethod,
      accountDetails: accountDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48, height: 6,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context)!.requestWithdrawal,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                                color: context.textPrimary, letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Text(
                          '${AppLocalizations.of(context)!.balancePrefix}${_getCurrencyFormat(context).format(widget.wallet.balance)}',
                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              
              // المبلغ
              Text(AppLocalizations.of(context)!.amountToWithdraw, style: TextStyle(fontWeight: FontWeight.w700, color: context.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary),
                decoration: _inputDec(AppLocalizations.of(context)!.enterAmount, Icons.attach_money_rounded, context),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 50) return AppLocalizations.of(context)!.minAmount50;
                  if (n > widget.wallet.balance) return AppLocalizations.of(context)!.amountGreaterThanBalance;
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // طريقة السحب
              Text(AppLocalizations.of(context)!.withdrawalMethod, style: TextStyle(fontWeight: FontWeight.w700, color: context.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 12,
                children: _methods.map((m) {
                  final (value, label, icon) = m;
                  final selected = _selectedMethod == value;
                  return ChoiceChip(
                    avatar: Icon(icon, size: 18,
                        color: selected ? Colors.white : AppColors.primary),
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedMethod = value),
                    selectedColor: AppColors.primary,
                    backgroundColor: context.bgColor,
                    side: BorderSide(
                      color: selected ? Colors.transparent : context.divColor,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : context.textPrimary,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              
              // حقول الحساب
              Text(AppLocalizations.of(context)!.transferDetails, style: TextStyle(fontWeight: FontWeight.w700, color: context.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              if (_selectedMethod != 'bank_transfer')
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary),
                  decoration: _inputDec(AppLocalizations.of(context)!.mobileNumber, Icons.phone_android_rounded, context),
                  validator: (v) {
                    if (v == null || v.length < 11) return AppLocalizations.of(context)!.invalidMobileNumber;
                    return null;
                  },
                )
              else ...[
                TextFormField(
                  controller: _bankCtrl,
                  style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary),
                  decoration: _inputDec(AppLocalizations.of(context)!.bankName, Icons.account_balance_rounded, context),
                  validator: (v) => (v?.isEmpty ?? true) ? AppLocalizations.of(context)!.enterBankName : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ibanCtrl,
                  style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimary),
                  decoration: _inputDec(AppLocalizations.of(context)!.accountNumberOrIban, Icons.credit_card_rounded, context),
                  validator: (v) => (v?.isEmpty ?? true) ? AppLocalizations.of(context)!.enterAccountNumberOrIban : null,
                ),
              ],
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _submit(context),
                  icon: const Icon(Icons.send_rounded, size: 20),
                  label: Text(AppLocalizations.of(context)!.confirmWithdrawalRequest, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon, BuildContext context) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: context.textSecondary, fontWeight: FontWeight.w500),
    prefixIcon: Icon(icon, color: context.textSecondary),
    filled: true,
    fillColor: context.bgColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: context.divColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: context.divColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  );
}
