import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exceptions.dart';
import '../../data/models/user_wallet_model.dart';
import '../../data/models/wallet_transaction_model.dart';
import '../../data/repositories/wallet_repository.dart';
import 'package:snapix/core/utils/app_logger.dart';

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

  // ✅ BUG-5 FIX: added pagination fields.
  final bool hasMoreTransactions;
  final bool isLoadingMore;

  const UserWalletLoaded({
    required this.wallet,
    required this.transactions,
    this.hasMoreTransactions = false,
    this.isLoadingMore = false,
  });

  UserWalletLoaded copyWith({
    UserWalletModel? wallet,
    List<WalletTransactionModel>? transactions,
    bool? hasMoreTransactions,
    bool? isLoadingMore,
  }) {
    return UserWalletLoaded(
      wallet: wallet ?? this.wallet,
      transactions: transactions ?? this.transactions,
      hasMoreTransactions: hasMoreTransactions ?? this.hasMoreTransactions,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props =>
      [wallet, transactions, hasMoreTransactions, isLoadingMore];
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

  // ✅ BUG-5 FIX: page size and cursor for pagination.
  static const int _pageSize = 50;
  DateTime? _oldestTransactionTime;

  Future<void> load(String userId) async {
    emit(const UserWalletLoading());
    _oldestTransactionTime = null; // reset pagination cursor

    try {
      final wallet = await _repo.getUserWallet(userId);
      if (wallet == null) {
        throw NotFoundException('errorWalletNotFound');
      }

      final transactions = await _repo.getTransactionHistory(
        userId: userId,
        walletType: 'user',
        limit: _pageSize,
      );

      if (transactions.isNotEmpty) {
        _oldestTransactionTime = transactions.last.createdAt;
      }

      emit(UserWalletLoaded(
        wallet: wallet,
        transactions: transactions,
        hasMoreTransactions: transactions.length == _pageSize,
      ));

      _watchWallet(userId);
    } catch (e, st) {
      AppLogger.error('UserWalletCubit: load failed: $e\n$st');
      emit(const UserWalletError('failedLoadWallet'));
    }
  }

  // ✅ BUG-5 FIX: new method — loads next page using cursor-based pagination.
  // Does NOT affect the Realtime stream.
  Future<void> loadMoreTransactions(String userId) async {
    if (state is! UserWalletLoaded) return;
    final current = state as UserWalletLoaded;

    if (current.isLoadingMore || !current.hasMoreTransactions) return;

    emit(current.copyWith(isLoadingMore: true));

    try {
      final moreTransactions = await _repo.getTransactionHistory(
        userId: userId,
        walletType: 'user',
        limit: _pageSize,
        before: _oldestTransactionTime,
      );

      if (!isClosed && state is UserWalletLoaded) {
        final currentState = state as UserWalletLoaded;

        if (moreTransactions.isNotEmpty) {
          _oldestTransactionTime = moreTransactions.last.createdAt;
        }

        emit(currentState.copyWith(
          transactions: [...currentState.transactions, ...moreTransactions],
          hasMoreTransactions: moreTransactions.length == _pageSize,
          isLoadingMore: false,
        ));
      }
    } catch (e, st) {
      AppLogger.warning('UserWalletCubit: loadMoreTransactions failed: $e\n$st');
      if (!isClosed && state is UserWalletLoaded) {
        emit((state as UserWalletLoaded).copyWith(isLoadingMore: false));
      }
    }
  }

  void _watchWallet(String userId) {
    _walletSub?.cancel();
    _walletSub = _repo.watchUserWallet(userId).listen((wallet) async {
      if (isClosed || wallet == null || state is! UserWalletLoaded) return;

      final current = state as UserWalletLoaded;
      emit(current.copyWith(wallet: wallet));

      // ✅ BUG-5 FIX: reset cursor on balance change so we always show fresh
      // first-page data, then allow the user to paginate again.
      _oldestTransactionTime = null;

      try {
        final transactions = await _repo.getTransactionHistory(
          userId: userId,
          walletType: 'user',
          limit: _pageSize,
        );

        if (!isClosed && state is UserWalletLoaded) {
          if (transactions.isNotEmpty) {
            _oldestTransactionTime = transactions.last.createdAt;
          }
          emit((state as UserWalletLoaded).copyWith(
            transactions: transactions,
            hasMoreTransactions: transactions.length == _pageSize,
            isLoadingMore: false,
          ));
        }
      } catch (e, st) {
        AppLogger.warning('UserWalletCubit: transaction refresh failed: $e\n$st');
      }
    });
  }

  @override
  Future<void> close() {
    _walletSub?.cancel();
    return super.close();
  }
}
