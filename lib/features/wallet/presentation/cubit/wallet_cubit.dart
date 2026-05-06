import 'package:equatable/equatable.dart';
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

      final transactions = await _repo.getTransactionHistory(userId: driverId, limit: 30);
      final withdrawals = await _repo.getWithdrawalRequests(driverId);

      emit(WalletLoaded(
        wallet: DriverWalletModel.fromJson(walletJson),
        transactions: transactions,
        withdrawals: withdrawals,
      ));
    } catch (e) {
      emit(WalletError('فشل تحميل بيانات المحفظة: $e'));
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
      emit(WithdrawalFailure('حدث خطأ: $e'));
    }
  }

  String _mapError(String code, Map<String, dynamic> result) {
    switch (code) {
      case 'insufficient_balance':
        final available = result['available'] ?? 0;
        return 'الرصيد غير كافٍ. المتاح: $available جنيه';
      case 'below_minimum':
        return 'الحد الأدنى للسحب هو 50 جنيه';
      case 'pending_withdrawal_exists':
        return 'لديك طلب سحب قيد المعالجة بالفعل';
      case 'wallet_not_found':
        return 'لم يتم العثور على المحفظة';
      case 'unauthorized':
        return 'غير مصرح بهذه العملية';
      default:
        return 'حدث خطأ غير متوقع ($code)';
    }
  }
}
