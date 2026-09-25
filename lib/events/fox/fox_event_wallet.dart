import 'package:flutter/foundation.dart';

class FoxInsufficientFundsException implements Exception {
  const FoxInsufficientFundsException();
}

class FoxWalletChange {
  const FoxWalletChange({required this.balanceAfter, required this.replayed});

  final int balanceAfter;
  final bool replayed;
}

abstract interface class FoxEventWallet {
  int get balance;

  Future<FoxWalletChange> applyDelta({
    required int delta,
    required String effectKey,
  });
}

/// A runnable wallet for the current Flutter-only prototype. The event module
/// depends on [FoxEventWallet], so the eventual whole-app economy can replace
/// this implementation without changing story content or dialog widgets.
class InMemoryFoxEventWallet extends ChangeNotifier implements FoxEventWallet {
  InMemoryFoxEventWallet({int initialBalance = 100})
    : _balance = initialBalance;

  int _balance;
  final Set<String> _appliedEffectKeys = <String>{};

  @override
  int get balance => _balance;

  @override
  Future<FoxWalletChange> applyDelta({
    required int delta,
    required String effectKey,
  }) async {
    if (_appliedEffectKeys.contains(effectKey)) {
      return FoxWalletChange(balanceAfter: _balance, replayed: true);
    }
    if (_balance + delta < 0) {
      throw const FoxInsufficientFundsException();
    }
    _balance += delta;
    _appliedEffectKeys.add(effectKey);
    notifyListeners();
    return FoxWalletChange(balanceAfter: _balance, replayed: false);
  }
}
