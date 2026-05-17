import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/driver_wallet_model.dart';
import '../../data/models/wallet_transaction_model.dart';
import '../../data/models/withdrawal_request_model.dart';
import '../../data/repositories/wallet_repository.dart';

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

  const WalletLoaded({
    required this.wallet,
    required this.transactions,
    required this.withdrawals,
  });

  WalletLoaded copyWith({
    DriverWalletModel? wallet,
    List<WalletTransactionModel>? transactions,
    List<WithdrawalRequestModel>? withdrawals,
  }) {
    return WalletLoaded(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      withdrawals: withdrawals ?? this.withdrawals,
    );
  }

  @override
  List<Object?> get props => [wallet, transactions, withdrawals];
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
  WalletCubit() : super(WalletInitial());

  final _repo = WalletRepository();

  Future<void> load(String driverId) async {
    emit(WalletLoading());
    try {
      final walletJson = await _repo.getDriverEarningsSummary(driverId);
      walletJson['driver_id'] = driverId;

      final transactions = await _repo.getTransactionHistory(
          userId: driverId, walletType: 'driver', limit: 30);
      final withdrawals = await _repo.getWithdrawalRequests(driverId);

      emit(WalletLoaded(
        wallet: DriverWalletModel.fromJson(walletJson),
        transactions: transactions,
        withdrawals: withdrawals,
      ));

      watchWallet(driverId);
    } catch (e) {
      emit(WalletError('failedLoadWallet'));
    }
  }

  Future<void> requestWithdrawal({
    required String driverId,
    required double amount,
    required String paymentMethod,
    required Map<String, dynamic> accountDetails,
  }) async {
    emit(WithdrawalSubmitting());
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
        await load(driverId);
      } else {
        final err = result['error'] as String? ?? 'unknown_error';
        emit(WithdrawalFailure(_mapError(err, result)));
      }
    } catch (e) {
      emit(WithdrawalFailure('errorOccurredWithDetails'));
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

      // Fetch latest transactions and withdrawals since balance changed
      try {
        final results = await Future.wait([
          _repo.getTransactionHistory(
              userId: driverId, walletType: 'driver', limit: 30),
          _repo.getWithdrawalRequests(driverId),
        ]);
        if (!isClosed && state is WalletLoaded) {
          emit((state as WalletLoaded).copyWith(
            transactions: results[0] as List<WalletTransactionModel>,
            withdrawals: results[1] as List<WithdrawalRequestModel>,
          ));
        }
      } catch (e, st) {
        debugPrint(
            '⚠️ WalletCubit: failed to refresh wallet side data: $e\n$st');
        if (!isClosed) {
          emit(const WalletError('failedLoadWallet'));
        }
      }
    });
  }

  @override
  Future<void> close() {
    _walletSub?.cancel();
    return super.close();
  }
}
