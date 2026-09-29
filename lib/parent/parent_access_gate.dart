import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../onboarding/widgets/back_circle_button.dart';
import '../onboarding/widgets/story_button.dart';
import '../theme/app_theme.dart';

abstract interface class ParentAccessStorage {
  Future<String?> readPin();
  Future<void> savePin(String pin);
}

class SecureParentAccessStorage implements ParentAccessStorage {
  SecureParentAccessStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'parent_local_access_pin';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readPin() => _storage.read(key: _key);

  @override
  Future<void> savePin(String pin) => _storage.write(key: _key, value: pin);
}

enum _GateState { loading, setup, locked }

/// A local adult gate for a shared child device.
///
/// The parent bearer token deliberately lives separately from the child token,
/// but token separation alone does not stop a child tapping "Я родитель" and
/// approving their own task. A six-digit PIN in platform secure storage locks
/// every entry into the parent cabinet without sending that PIN to the server.
class ParentAccessGate extends StatefulWidget {
  const ParentAccessGate({
    super.key,
    required this.onUnlocked,
    required this.onBack,
    this.storage,
  });

  final VoidCallback onUnlocked;
  final VoidCallback onBack;
  final ParentAccessStorage? storage;

  @override
  State<ParentAccessGate> createState() => _ParentAccessGateState();
}

class _ParentAccessGateState extends State<ParentAccessGate> {
  late final ParentAccessStorage _storage =
      widget.storage ?? SecureParentAccessStorage();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  _GateState _state = _GateState.loading;
  String? _savedPin;
  String? _error;
  bool _busy = false;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final pin = await _storage.readPin();
    if (!mounted) return;
    setState(() {
      _savedPin = pin;
      _state = pin == null ? _GateState.setup : _GateState.locked;
    });
  }

  Future<void> _setPin() async {
    final pin = _pinController.text;
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _error = 'Введите ровно 6 цифр.');
      return;
    }
    if (pin != _confirmController.text) {
      setState(() => _error = 'Коды не совпадают. Проверьте ещё раз.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    await _storage.savePin(pin);
    if (!mounted) return;
    widget.onUnlocked();
  }

  void _unlock() {
    if (_pinController.text == _savedPin) {
      _failedAttempts = 0;
      widget.onUnlocked();
      return;
    }
    _failedAttempts++;
    _pinController.clear();
    setState(
      () => _error = _failedAttempts >= 3
          ? 'Код не подошёл. Перед следующей попыткой проверьте цифры.'
          : 'Неверный код. Попробуйте ещё раз.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _GateState.loading) {
      return const Scaffold(
        backgroundColor: AppColors.parchment,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.crimson),
        ),
      );
    }

    final setup = _state == _GateState.setup;
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BackCircleButton(onPressed: widget.onBack),
                  ),
                  const SizedBox(height: 28),
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 64,
                    color: AppColors.leafGreen,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    setup ? 'Защитите кабинет' : 'Кабинет родителя',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.screenTitle,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    setup
                        ? 'Придумайте взрослый код из 6 цифр. Он понадобится '
                              'каждый раз при входе с этого устройства.'
                        : 'Введите взрослый код. Ребёнок не сможет открыть '
                              'прогресс и подтвердить себе награду.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.story,
                  ),
                  const SizedBox(height: 22),
                  _PinField(
                    key: const ValueKey('parent-pin'),
                    controller: _pinController,
                    label: setup ? 'Новый код' : 'Код родителя',
                    onSubmitted: setup ? null : (_) => _unlock(),
                  ),
                  if (setup) ...[
                    const SizedBox(height: 12),
                    _PinField(
                      key: const ValueKey('parent-pin-confirm'),
                      controller: _confirmController,
                      label: 'Повторите код',
                      onSubmitted: (_) => _setPin(),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.crimsonDark),
                    ),
                  ],
                  const SizedBox(height: 20),
                  StoryButton(
                    label: setup ? 'Сохранить код' : 'Открыть кабинет',
                    isLoading: _busy,
                    onPressed: _busy
                        ? null
                        : setup
                        ? _setPin
                        : _unlock,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    super.key,
    required this.controller,
    required this.label,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
      maxLength: 6,
    );
  }
}
