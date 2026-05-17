import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exceptions.dart';
import '../../data/models/user_wallet_model.dart';
import '../../data/models/wallet_transaction_model.dart';
import '../../data/repositories/wallet_repository.dart';

abstract class UserWalletState extends Equatable {
  const UserWalletState();

  @override
  List<Object?> get props => [];
}

class UserWalletInitial extends UserWalletState {
  const UserWalletInitial();
}

class UserWalletLoading extends UserWalletState {
  const UserWalletLoading();
}

class UserWalletLoaded extends UserWalletState {
  final UserWalletModel wallet;
  final List<WalletTransactionModel> transactions;

  const UserWalletLoaded({
    required this.wallet,
    required this.transactions,
  });

  UserWalletLoaded copyWith({
    UserWalletModel? wallet,
    List<WalletTransactionModel>? transactions,
  }) {
    return UserWalletLoaded(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
    );
  }

  @override
  List<Object?> get props => [wallet, transactions];
}

class UserWalletError extends UserWalletState {
  final String message;

  const UserWalletError(this.message);

  @override
  List<Object?> get props => [message];
}

class UserWalletCubit extends Cubit<UserWalletState> {
  UserWalletCubit({WalletRepository? repository})
      : _repo = repository ?? WalletRepository(),
        super(const UserWalletInitial());

  final WalletRepository _repo;
  StreamSubscription? _walletSub;

  Future<void> load(String userId) async {
    emit(const UserWalletLoading());

    try {
      final wallet = await _repo.getUserWallet(userId);
      if (wallet == null) {
        throw NotFoundException('errorWalletNotFound');
      }

      final transactions = await _repo.getTransactionHistory(
        userId: userId,
        walletType: 'user',
        limit: 50,
      );

      emit(UserWalletLoaded(wallet: wallet, transactions: transactions));
      _watchWallet(userId);
    } catch (e, st) {
      debugPrint('❌ UserWalletCubit: load failed: $e\n$st');
      emit(const UserWalletError('failedLoadWallet'));
    }
  }

  void _watchWallet(String userId) {
    _walletSub?.cancel();
    _walletSub = _repo.watchUserWallet(userId).listen((wallet) async {
      if (isClosed || wallet == null || state is! UserWalletLoaded) return;

      final current = state as UserWalletLoaded;
      emit(current.copyWith(wallet: wallet));

      try {
        final transactions = await _repo.getTransactionHistory(
          userId: userId,
          walletType: 'user',
          limit: 50,
        );
        if (!isClosed && state is UserWalletLoaded) {
          emit(
              (state as UserWalletLoaded).copyWith(transactions: transactions));
        }
      } catch (e, st) {
        debugPrint('⚠️ UserWalletCubit: transaction refresh failed: $e\n$st');
      }
    });
  }

  @override
  Future<void> close() {
    _walletSub?.cancel();
    return super.close();
  }
}
