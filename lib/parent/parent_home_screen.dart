import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/auth_storage.dart';
import '../onboarding/widgets/back_circle_button.dart';
import '../onboarding/widgets/story_button.dart';
import '../theme/app_theme.dart';
import 'child_overview.dart';
import 'parent_dashboard_screen.dart';

enum _ParentState { loading, needsAccount, noChildren, ready, error }

/// Entry point of parent mode: create the parent account, invite a child,
/// then show that child's real progress.
///
/// Linking follows the flow agreed for the product: the parent receives a
/// one-time code and the child enters it in their own settings. The parent
/// never types anything that identifies the child.
class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({
    super.key,
    required this.onBack,
    this.apiClient,
    this.authStorage,
  });

  final VoidCallback onBack;

  /// Injected in tests; by default the parent uses its own token storage so
  /// it never picks up the child's session on a shared device.
  final ApiClient? apiClient;
  final AuthStorage? authStorage;

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  late final AuthStorage _storage = widget.authStorage ?? AuthStorage.parent();
  late final ApiClient _api =
      widget.apiClient ?? ApiClient(authStorage: _storage);

  _ParentState _state = _ParentState.loading;
  ChildOverview? _overview;
  List<({String childUserId, String petName})> _children = const [];
  String? _selectedChildUserId;
  String? _inviteCode;
  DateTime? _inviteExpiresAt;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _ParentState.loading);
    if (await _storage.readToken() == null) {
      if (mounted) setState(() => _state = _ParentState.needsAccount);
      return;
    }
    try {
      final children = await _api.getList('/parent/children');
      if (children.isEmpty) {
        if (mounted) {
          setState(() {
            _children = const [];
            _selectedChildUserId = null;
            _state = _ParentState.noChildren;
          });
        }
        return;
      }
      final summaries = children
          .map((value) {
            if (value is! Map) {
              throw const FormatException('child summary is invalid');
            }
            final child = value;
            final childUserId = child['childUserId'];
            if (childUserId is! String || childUserId.isEmpty) {
              throw const FormatException('childUserId is missing');
            }
            final petName = child['petName'];
            return (
              childUserId: childUserId,
              petName: petName is String && petName.trim().isNotEmpty
                  ? petName
                  : 'Питомец',
            );
          })
          .toList(growable: false);
      final selectedId =
          summaries.any((child) => child.childUserId == _selectedChildUserId)
          ? _selectedChildUserId!
          : summaries.first.childUserId;
      final overview = await _api.get('/parent/children/$selectedId/overview');
      if (!mounted) return;
      setState(() {
        _children = summaries;
        _selectedChildUserId = selectedId;
        _overview = ChildOverview.fromJson(overview);
        _state = _ParentState.ready;
      });
    } on ApiException catch (error) {
      // A revoked parent token cannot be recovered; start a fresh account
      // instead of retrying the same dead session forever.
      if (error.statusCode == 401) {
        await _storage.clearToken();
        if (mounted) setState(() => _state = _ParentState.needsAccount);
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = error.isNetworkError
            ? 'Нет связи с сервером. Проверьте подключение и попробуйте ещё раз.'
            : 'Не удалось загрузить данные ребёнка.';
        _state = _ParentState.error;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = 'Сервер вернул неполные данные ребёнка.';
        _state = _ParentState.error;
      });
    }
  }

  Future<void> _createAccount() async {
    await _run(() async {
      final result = await _api.post('/auth/parent/register', auth: false);
      await _storage.saveToken(result['token'] as String);
      await _load();
    });
  }

  Future<void> _createInvite() async {
    await _run(() async {
      final result = await _api.post('/auth/parent/invites');
      if (!mounted) return;
      setState(() {
        _inviteCode = result['inviteCode'] as String?;
        _inviteExpiresAt = DateTime.tryParse('${result['expiresAt']}')
            ?.toLocal();
        _state = _ParentState.noChildren;
      });
    });
  }

  void _selectChild(String childUserId) {
    if (childUserId == _selectedChildUserId || _busy) return;
    _selectedChildUserId = childUserId;
    _load();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error.isNetworkError
            ? 'Нет связи с сервером. Проверьте подключение и попробуйте ещё раз.'
            : 'Не получилось. Попробуйте ещё раз.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _ParentState.ready && _overview != null) {
      return ParentDashboardScreen(
        overview: _overview!,
        children: _children,
        selectedChildUserId: _selectedChildUserId!,
        onChildSelected: _selectChild,
        onRefresh: _load,
        onInviteChild: _createInvite,
        onExitToRoleChoice: widget.onBack,
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF1EEE8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: BackCircleButton(onPressed: widget.onBack),
                ),
                const SizedBox(height: 24),
                ..._body(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body() {
    switch (_state) {
      case _ParentState.loading:
      case _ParentState.ready:
        return const [
          SizedBox(height: 80),
          Center(child: CircularProgressIndicator(color: AppColors.crimson)),
        ];
      case _ParentState.error:
        return [
          Text(_error ?? '', style: AppTextStyles.story),
          const SizedBox(height: 16),
          StoryButton(label: 'Повторить', onPressed: _load),
        ];
      case _ParentState.needsAccount:
        return [
          Text('Кабинет родителя', style: AppTextStyles.screenTitle),
          const SizedBox(height: 12),
          Text(
            'Здесь видно, как ребёнок распоряжается монетами, какие задания '
            'прошёл и где ему может понадобиться помощь. Мы не просим ни имени, '
            'ни почты, ни телефона.',
            style: AppTextStyles.story,
          ),
          const SizedBox(height: 24),
          if (_error != null) _ErrorText(_error!),
          StoryButton(
            label: 'Создать кабинет',
            isLoading: _busy,
            onPressed: _busy ? null : _createAccount,
          ),
        ];
      case _ParentState.noChildren:
        return [
          Text('Пригласите ребёнка', style: AppTextStyles.screenTitle),
          const SizedBox(height: 12),
          Text(
            'Получите код и попросите ребёнка открыть «Настройки» в своём '
            'приложении и ввести его в поле «Код от родителя». После этого '
            'его прогресс появится здесь.',
            style: AppTextStyles.story,
          ),
          const SizedBox(height: 24),
          if (_inviteCode != null) ...[
            _InviteCodeCard(code: _inviteCode!, expiresAt: _inviteExpiresAt),
            const SizedBox(height: 16),
          ],
          if (_error != null) _ErrorText(_error!),
          if (_children.isNotEmpty) ...[
            OutlinedButton(
              onPressed: _busy ? null : _load,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.fieldBorder),
              ),
              child: const Text('Вернуться к прогрессу детей'),
            ),
            const SizedBox(height: 10),
          ],
          StoryButton(
            label: _inviteCode == null ? 'Получить код' : 'Получить новый код',
            isLoading: _busy,
            onPressed: _busy ? null : _createInvite,
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _busy ? null : _load,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.fieldBorder),
            ),
            child: const Text('Ребёнок ввёл код — обновить'),
          ),
        ];
    }
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code, required this.expiresAt});

  final String code;
  final DateTime? expiresAt;

  /// "6B9B-EBHW": the middle break makes eight characters easy to read aloud.
  /// The child's field ignores the hyphen, so it can be typed either way.
  String get _display =>
      code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;

  @override
  Widget build(BuildContext context) {
    final until = expiresAt;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.crimsonFaded, width: 1.5),
      ),
      child: Column(
        children: [
          const Text(
            'Код для ребёнка',
            style: TextStyle(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _display,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              letterSpacing: 3,
              fontWeight: FontWeight.bold,
              color: AppColors.crimsonDark,
            ),
          ),
          if (until != null) ...[
            const SizedBox(height: 8),
            Text(
              'Действует до ${until.day.toString().padLeft(2, '0')}.'
              '${until.month.toString().padLeft(2, '0')} '
              '${until.hour.toString().padLeft(2, '0')}:'
              '${until.minute.toString().padLeft(2, '0')}. '
              'Код одноразовый.',
              textAlign: TextAlign.center,
              style: AppTextStyles.swatchLabel,
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: AppTextStyles.swatchLabel.copyWith(color: AppColors.crimson),
      ),
    );
  }
}
