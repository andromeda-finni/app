/// Balances returned by the economy API. Only [spendable] belongs to the
/// wallet shown as money available to spend; savings stay in the piggy bank.
final class WalletBalances {
  const WalletBalances({
    required this.spendable,
    required this.savings,
    required this.frozen,
  });

  final int spendable;
  final int savings;
  final int frozen;

  factory WalletBalances.fromJson(Object? value) {
    final wallets = value is Map ? value : const {};
    return WalletBalances(
      spendable: _amount(wallets['SPENDABLE']),
      savings: _amount(wallets['SAVINGS']),
      frozen: _amount(wallets['FROZEN']),
    );
  }

  static int _amount(Object? value) {
    if (value is Map) {
      return _amount(value['spendable'] ?? value['balance'] ?? value['amount']);
    }
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
