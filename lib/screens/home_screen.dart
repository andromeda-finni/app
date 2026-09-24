import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/auth_storage.dart';
import '../minigames/mole/mole_game_data.dart';
import '../minigames/mole/mole_game_screen.dart';
import '../minigames/tugriki/tugriki_game_data.dart';
import '../minigames/tugriki/tugriki_game_screen.dart';
import '../profile/child_access_code.dart';
import '../settings/child_settings_screen.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.apiClient,
    this.authStorage,
    this.onResetProfile,
    this.onSwitchAudience,
  });

  final ApiClient? apiClient;
  final AuthStorage? authStorage;
  final VoidCallback? onResetProfile;
  final VoidCallback? onSwitchAudience;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _balance = 100;
  int _savings = 30;
  String _petName = 'Грошик';
  String _childCode = childAccessCodeFrom(null);
  ChildSettingsSnapshot _settings = const ChildSettingsSnapshot();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPetData();
  }

  Future<void> _fetchPetData() async {
    if (widget.apiClient == null) return;
    setState(() => _isLoading = true);
    try {
      final petRes = await widget.apiClient!.get('/pet');
      if (mounted) {
        setState(() {
          _petName = (petRes['pet_name'] as String?) ?? 'Грошик';
          _childCode = childAccessCodeFrom(petRes['id'] as String?);
        });
      }

      final walletRes = await widget.apiClient!.get('/wallet');
      if (mounted) {
        setState(() {
          _balance = (walletRes['balance'] as num?)?.toInt() ?? 100;
          _savings = (walletRes['savings'] as num?)?.toInt() ?? 30;
        });
      }
    } catch (_) {
      // Offline fallback: keep default demo values
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openTugrikiGame() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TugrikiGameScreen(
          apiClient: widget.apiClient,
          onExit: () {
            Navigator.of(context).pop();
            _fetchPetData();
          },
        ),
      ),
    );
  }

  void _openMoleGame() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => MoleGameScreen(apiClient: widget.apiClient),
          ),
        )
        .then((_) => _fetchPetData());
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (screenContext) => ChildSettingsScreen(
          childCode: _childCode,
          initialSettings: _settings,
          onSettingsChanged: (next) => setState(() => _settings = next),
          onSwitchAudience: () {
            Navigator.of(screenContext).pop();
            widget.onSwitchAudience?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          children: [
            // Верхняя панель ресурсов
            _buildResourceHeader(),

            // Центральная интерактивная часть
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Карточка питомца
                      _buildPetCard(),
                      const SizedBox(height: 18),

                      // Заголовок доступных заданий
                      const Row(
                        children: [
                          Icon(
                            Icons.sports_esports_outlined,
                            color: AppColors.crimson,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Игры и уроки финансовой грамотности',
                              style: TextStyle(
                                fontFamily: AppFonts.family,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Карточка новой игры «Тугрики»
                      _buildGameCard(
                        title: '«Тугрики» — Иностранная валюта',
                        description: 'Отправляйся с другом Воробьем на ярмарку соседнего государства! Узнай, что такое курс валют, научись пересчитывать цены и распределять бюджет покупок.',
                        badgeText: 'НОВАЯ ИГРА',
                        badgeColor: AppColors.crimson,
                        imageAsset: TugrikiAssets.foreignMoneyBag,
                        onPlay: _openTugrikiGame,
                        tags: const ['Курс 1 к 2', '7-11 лет', '+20 монет'],
                      ),
                      const SizedBox(height: 14),

                      // Карточка игры «Крот Земелик»
                      _buildGameCard(
                        title: '«Осторожно, мелкий шрифт»',
                        description: 'Помоги Кроту Земелику разобраться в чеках и объявлениях. Учись находить скрытые условия и защищать свои монетки!',
                        badgeText: 'ВНИМАНИЕ',
                        badgeColor: AppColors.leafGreen,
                        imageAsset: MoleAssets.zemelik,
                        onPlay: _openMoleGame,
                        tags: const [
                          'Чеки и договоры',
                          '7-11 лет',
                          '+20 монет',
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(bottom: BorderSide(color: AppColors.fieldBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset('assets/icons/coin.png', width: 28, height: 28),
              const SizedBox(width: 6),
              Text(
                '$_balance',
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 16),
              Image.asset('assets/icons/pig.png', width: 28, height: 28),
              const SizedBox(width: 6),
              Text(
                '$_savings',
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.leafGreen,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Обновить баланс',
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.crimson,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.crimson,
                      ),
                onPressed: _isLoading ? null : _fetchPetData,
              ),
              IconButton(
                key: const Key('open-child-settings'),
                tooltip: 'Настройки и ID ребёнка',
                icon: const Icon(Icons.settings_outlined, color: AppColors.ink),
                onPressed: _openSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x143B2F27),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.parchment,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.crimson, width: 2),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/Cat/Red_collar/base/striped.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _petName,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.crimsonDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Питомец уже создан: настроение отличное! 🐱',
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 14,
                    color: AppColors.leafGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Готов узнавать новое о деньгах и путешествиях',
                  style: TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 13,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ID для родителя: $_childCode',
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required String title,
    required String description,
    required String badgeText,
    required Color badgeColor,
    required String imageAsset,
    required VoidCallback onPlay,
    required List<String> tags,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(imageAsset, width: 50, height: 50),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontFamily: AppFonts.family,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontFamily: AppFonts.family,
              fontSize: 14,
              color: AppColors.ink,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: tags
                .map(
                  (tag) => Chip(
                    label: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.ink,
                      ),
                    ),
                    backgroundColor: AppColors.parchment,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onPlay,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.crimson,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const StadiumBorder(),
              elevation: 2,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text(
              'Играть',
              style: TextStyle(
                fontFamily: AppFonts.family,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
