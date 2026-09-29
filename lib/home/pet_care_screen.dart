import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'models/home_economy_state.dart';
import 'models/pet.dart';
import 'widgets/collection_card.dart';
import 'widgets/pet_name_header.dart';
import 'widgets/pet_scene.dart';
import 'widgets/pet_stats_card.dart';
import 'widgets/plantain_table_card.dart';

/// The pet's personal page: condition, collected artefacts and first aid.
class PetCareScreen extends StatefulWidget {
  const PetCareScreen({
    super.key,
    required this.state,
    required this.onRename,
    required this.onRefresh,
    required this.onOpenInsurance,
    required this.onOpenEvent,
    required this.onEquipArtifact,
    required this.onRepairArtifact,
  });

  final HomeEconomyState state;
  final Future<void> Function(String name) onRename;
  final Future<HomeEconomyState> Function() onRefresh;
  final VoidCallback onOpenInsurance;
  final VoidCallback onOpenEvent;
  final Future<HomeEconomyState> Function(ArtifactItem item) onEquipArtifact;
  final Future<HomeEconomyState> Function(ArtifactItem item) onRepairArtifact;

  @override
  State<PetCareScreen> createState() => _PetCareScreenState();
}

class _PetCareScreenState extends State<PetCareScreen> {
  late HomeEconomyState _state = widget.state;

  Pet get _pet => _state.pet;

  Future<void> _rename(String name) async {
    await widget.onRename(name);
    if (mounted) {
      setState(() => _state = _state.copyWith(pet: _pet.copyWith(name: name)));
    }
  }

  Future<void> _refresh() async {
    final next = await widget.onRefresh();
    if (mounted) setState(() => _state = next);
  }

  Future<void> _equipArtifact(ArtifactItem item) async {
    try {
      final next = await widget.onEquipArtifact(item);
      if (mounted) setState(() => _state = next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить снаряжение.')),
      );
      rethrow;
    }
  }

  Future<void> _repairArtifact(ArtifactItem item) async {
    try {
      final next = await widget.onRepairArtifact(item);
      if (mounted) setState(() => _state = next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось починить артефакт.')),
      );
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final sceneHeight = (shortestSide * 0.83).clamp(280.0, 390.0);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.crimson,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: IconButton(
                              key: const Key('pet-care-back'),
                              tooltip: 'Вернуться в домик',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: AppColors.crimson,
                            ),
                          ),
                          Expanded(
                            child: PetNameHeader(
                              pet: _pet,
                              onRename: _rename,
                              showStage: true,
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 12),
                      PetScene(
                        key: const Key('meadow-pet-scene'),
                        pet: _pet,
                        backgroundAsset: 'assets/backgrounds/town.webp',
                        backgroundAlignment: Alignment.bottomCenter,
                        height: sceneHeight,
                        petHeightFactor: 0.68,
                        heroTag: 'home-pet',
                      ),
                      const SizedBox(height: 16),
                      PetStatsCard(
                        stats: [
                          PetStat(
                            label: 'Сытость',
                            icon: Icons.soup_kitchen_rounded,
                            color: const Color(0xFF4CAF50),
                            value: _pet.satiety,
                          ),
                          PetStat(
                            label: 'Радость',
                            icon: Icons.wb_sunny_rounded,
                            color: const Color(0xFFFFA000),
                            value: _pet.joy,
                          ),
                          PetStat(
                            label: 'Здоровье',
                            icon: Icons.favorite_rounded,
                            color: const Color(0xFF2196F3),
                            value: _pet.health,
                            onTap: _state.activeEvent == null
                                ? widget.onOpenInsurance
                                : widget.onOpenEvent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      CollectionCard(
                        items: _state.inventory,
                        spendable: _state.spendable,
                        onEquip: _equipArtifact,
                        onRepair: _repairArtifact,
                      ),
                      const SizedBox(height: 14),
                      PlantainTableCard(
                        activeEvent: _state.activeEvent,
                        activeInsurance: _state.activeInsurance,
                        onOpenInsurance: widget.onOpenInsurance,
                        onOpenEvent: widget.onOpenEvent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
