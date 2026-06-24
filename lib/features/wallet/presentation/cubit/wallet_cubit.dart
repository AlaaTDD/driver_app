import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/driver_wallet_model.dart';
import '../../data/models/wallet_transaction_model.dart';
import '../../data/models/withdrawal_request_model.dart';
import '../../data/repositories/wallet_repository.dart';
import 'package:snapix/core/utils/app_logger.dart';

// ─── States ──────────────────────────────────────────────────────────────────

abstract class WalletState extends Equatable {
  const WalletState();
  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletLoaded extends WalletState {
  final DriverWalletModel wallet;
  final List<WalletTransactionModel> transactions;
  final List<WithdrawalRequestModel> withdrawals;

  // ✅ BUG-5 FIX: added pagination fields.
  // `hasMoreTransactions` tells the UI whether a "Load More" button should appear.
  // `isLoadingMore` prevents double-taps on the load-more button.
  final bool hasMoreTransactions;
  final bool isLoadingMore;

  const WalletLoaded({
    required this.wallet,
    required this.transactions,
    required this.withdrawals,
    this.hasMoreTransactions = false,
    this.isLoadingMore = false,
  });

  WalletLoaded copyWith({
    DriverWalletModel? wallet,
    List<WalletTransactionModel>? transactions,
    List<WithdrawalRequestModel>? withdrawals,
    bool? hasMoreTransactions,
    bool? isLoadingMore,
  }) {
    return WalletLoaded(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      withdrawals: withdrawals ?? this.withdrawals,
      hasMoreTransactions: hasMoreTransactions ?? this.hasMoreTransactions,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props =>
      [wallet, transactions, withdrawals, hasMoreTransactions, isLoadingMore];
}

class WalletError extends WalletState {
  final String message;
  const WalletError(this.message);
  @override
  List<Object?> get props => [message];
}

class WithdrawalSubmitting extends WalletState {}

class WithdrawalSuccess extends WalletState {
  final double amount;
  final String withdrawalId;
  const WithdrawalSuccess({required this.amount, required this.withdrawalId});
  @override
  List<Object?> get props => [amount, withdrawalId];
}

class WithdrawalFailure extends WalletState {
  final String error;
  const WithdrawalFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// ─── Cubit ───────────────────────────────────────────────────────────────────

class WalletCubit extends Cubit<WalletState> {
  WalletCubit({WalletRepository? repository})
      : _repo = repository ?? WalletRepository(),
        super(WalletInitial());

  final WalletRepository _repo;

  // ✅ BUG-5 FIX: page size constant. The initial load fetches _pageSize items.
  // If the response has exactly _pageSize items, we assume there are more.
  static const int _pageSize = 30;

  // Tracks the oldest transaction timestamp seen so far — used as the cursor
  // for cursor-based pagination. Reset to null on every Realtime balance update
  // so that watchWallet always shows the freshest first page.
  DateTime? _oldestTransactionTime;

  Future<void> load(String driverId) async {
    emit(WalletLoading());
    _oldestTransactionTime = null; // reset pagination cursor

    try {
      final walletJson =
          (await _repo.getDriverEarningsSummary(driverId)).toSnakeJson();
      walletJson['driver_id'] = driverId;

      final transactions = await _repo.getTransactionHistory(
          userId: driverId, walletType: 'driver', limit: _pageSize);
      final withdrawals = await _repo.getWithdrawalRequests(driverId);

      // Update cursor to oldest fetched transaction
      if (transactions.isNotEmpty) {
        _oldestTransactionTime = transactions.last.createdAt;
      }

      emit(WalletLoaded(
        wallet: DriverWalletModel.fromJson(walletJson),
        transactions: transactions,
        withdrawals: withdrawals,
        hasMoreTransactions: transactions.length == _pageSize,
      ));

      if (!isClosed) watchWallet(driverId);
    } catch (e) {
      emit(WalletError('failedLoadWallet'));
    }
  }

  // ✅ BUG-5 FIX: new method — loads the next page of transactions using
  // cursor-based pagination. Does NOT cancel or disturb the Realtime stream.
  Future<void> loadMoreTransactions(String driverId) async {
    if (state is! WalletLoaded) return;
    final current = state as WalletLoaded;

    // Guard: already loading more, or no more pages
    if (current.isLoadingMore || !current.hasMoreTransactions) return;

    emit(current.copyWith(isLoadingMore: true));

    try {
      final moreTransactions = await _repo.getTransactionHistory(
        userId: driverId,
        walletType: 'driver',
        limit: _pageSize,
        before: _oldestTransactionTime, // cursor: fetch only older records
      );

      if (!isClosed && state is WalletLoaded) {
        final currentState = state as WalletLoaded;

        if (moreTransactions.isNotEmpty) {
          _oldestTransactionTime = moreTransactions.last.createdAt;
        }

        emit(currentState.copyWith(
          transactions: [...currentState.transactions, ...moreTransactions],
          hasMoreTransactions: moreTransactions.length == _pageSize,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      AppLogger.warning('WalletCubit: loadMoreTransactions failed: $e');
      // On error: just clear the loading indicator, keep current list intact
      if (!isClosed && state is WalletLoaded) {
        emit((state as WalletLoaded).copyWith(isLoadingMore: false));
      }
    }
  }

  Future<bool> requestWithdrawal({
    required String driverId,
    required double amount,
    required String paymentMethod,
    required Map<String, dynamic> accountDetails,
  }) async {
    // Note: We don't emit WithdrawalSubmitting to avoid overwriting WalletLoaded
    // The UI handles its own loading state for the bottom sheet
    try {
      final result = await _repo.requestWithdrawal(
        driverId: driverId,
        amount: amount,
        paymentMethod: paymentMethod,
        accountDetails: accountDetails,
      );

      if (result['success'] == true) {
        emit(WithdrawalSuccess(
          amount: amount,
          withdrawalId: result['withdrawal_id'].toString(),
        ));
        // Removed `await load(driverId)` to fix BUG-05 & BUG-07 (triple load race condition).
        // `watchWallet` will naturally pick up DB changes and silently update the balance.
        return true;
      } else {
        final err = result['error'] as String? ?? 'unknown_error';
        emit(WithdrawalFailure(_mapError(err, result)));
        return false;
      }
    } catch (e) {
      emit(WithdrawalFailure('errorOccurredWithDetails'));
      return false;
    }
  }

  String _mapError(String code, Map<String, dynamic> result) {
    switch (code) {
      case 'insufficient_balance':
        return 'errorInsufficientBalance';
      case 'below_minimum':
        return 'minAmount50';
      case 'pending_withdrawal_exists':
        return 'errorWithdrawalPending';
      case 'wallet_not_found':
        return 'errorWalletNotFound';
      case 'unauthorized':
        return 'errorUnauthorizedOperation';
      default:
        return 'errorUnexpected';
    }
  }

  StreamSubscription? _walletSub;

  void watchWallet(String driverId) {
    _walletSub?.cancel();
    _walletSub = _repo.watchDriverWallet(driverId).listen((newWallet) async {
      if (isClosed || newWallet == null || state is! WalletLoaded) return;

      final currentState = state as WalletLoaded;
      final currentWallet = currentState.wallet;

      // Preserve summary-only fields that the real-time stream (driver_wallets table) doesn't have.
      // Core financial fields (balance, totalEarned, totalWithdrawn, pendingWithdrawal)
      // come from the stream and are correctly mapped by fromJson.
      final mergedWallet = newWallet.copyWith(
        earningsLastWeek: currentWallet.earningsLastWeek,
        earningsLast30Days: currentWallet.earningsLast30Days,
        completedTrips: currentWallet.completedTrips,
      );

      if (isClosed) return;
      emit(currentState.copyWith(wallet: mergedWallet));

      // ✅ BUG-5 FIX: On a Realtime balance change, reset pagination cursor and
      // reload only the first page. This ensures fresh data is always at the top
      // without losing the ability to paginate further afterward.
      _oldestTransactionTime = null;

      try {
        final results = await Future.wait([
          _repo.getTransactionHistory(
              userId: driverId, walletType: 'driver', limit: _pageSize),
          _repo.getWithdrawalRequests(driverId),
        ]);

        if (!isClosed && state is WalletLoaded) {
          final freshTransactions = results[0] as List<WalletTransactionModel>;
          if (freshTransactions.isNotEmpty) {
            _oldestTransactionTime = freshTransactions.last.createdAt;
          }

          emit((state as WalletLoaded).copyWith(
            transactions: freshTransactions,
            withdrawals: results[1] as List<WithdrawalRequestModel>,
            hasMoreTransactions: freshTransactions.length == _pageSize,
            isLoadingMore: false,
          ));
        }
      } catch (e, st) {
        AppLogger.debug(
            '⚠️ WalletCubit: failed to refresh wallet side data: $e\n$st');
        // Removed emit(WalletError) to prevent UI flashing (BUG-05/BUG-11)
        // We just keep the current WalletLoaded state
      }
    });
  }

  @override
  Future<void> close() {
    _walletSub?.cancel();
    return super.close();
  }
}
