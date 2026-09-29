import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/artifact_catalog.dart';
import '../models/home_economy_state.dart';

class CollectionCard extends StatelessWidget {
  const CollectionCard({
    super.key,
    this.items = const [],
    this.spendable = 0,
    this.onEquip,
    this.onRepair,
  });

  final List<ArtifactItem> items;
  final int spendable;
  final Future<void> Function(ArtifactItem item)? onEquip;
  final Future<void> Function(ArtifactItem item)? onRepair;

  @override
  Widget build(BuildContext context) {
    final owned = <String, ArtifactItem>{
      for (final item in items) canonicalArtifactId(item.itemId): item,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B542F), Color(0xFF5F351F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFB9854D), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset('assets/icons/chest.webp', width: 32, height: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Коллекция',
                  style: AppTextStyles.cardTitle.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ShelfRow(
            definitions: artifactCatalog.take(4).toList(growable: false),
            owned: owned,
            onTap: (definition, item) =>
                _showDetails(context, definition, item),
          ),
          const _WoodenShelf(),
          _ShelfRow(
            definitions: artifactCatalog.skip(4).toList(growable: false),
            owned: owned,
            onTap: (definition, item) =>
                _showDetails(context, definition, item),
          ),
          const _WoodenShelf(),
          const SizedBox(height: 8),
          Text(
            'Собрано: ${owned.length} из ${artifactCatalog.length}',
            style: AppTextStyles.swatchLabel.copyWith(
              color: const Color(0xFFFFE4AF),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    ArtifactDefinition definition,
    ArtifactItem? item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _ArtifactDetails(
                definition: definition,
                item: item,
                spendable: spendable,
                onEquip: onEquip,
                onRepair: onRepair,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow({
    required this.definitions,
    required this.owned,
    required this.onTap,
  });

  final List<ArtifactDefinition> definitions;
  final Map<String, ArtifactItem> owned;
  final void Function(ArtifactDefinition definition, ArtifactItem? item) onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 7.0;
      final width = ((constraints.maxWidth - gap * 3) / 4).clamp(58.0, 108.0);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < definitions.length; index++) ...[
            if (index > 0) const SizedBox(width: gap),
            _DisplaySlot(
              definition: definitions[index],
              item: owned[definitions[index].id],
              width: width,
              onTap: () =>
                  onTap(definitions[index], owned[definitions[index].id]),
            ),
          ],
        ],
      );
    },
  );
}

class _DisplaySlot extends StatelessWidget {
  const _DisplaySlot({
    required this.definition,
    required this.item,
    required this.width,
    required this.onTap,
  });

  final ArtifactDefinition definition;
  final ArtifactItem? item;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final acquired = item != null;
    return Semantics(
      button: true,
      label: acquired
          ? '${definition.name}, прочность ${item!.durabilityCurrent} из ${item!.durabilityMax}'
          : '${definition.name}, ещё не получен',
      child: SizedBox(
        width: width,
        height: 94,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('artifact-slot-${definition.id}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                color: const Color(0xFFDDD5CA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: item?.isBroken == true
                      ? const Color(0xFFB3261E)
                      : const Color(0xFF432719),
                  width: item?.equipped == true ? 3 : 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(7),
                    child: acquired
                        ? Image.asset(
                            definition.assetPath,
                            key: Key('artifact-image-${item!.itemId}'),
                            fit: BoxFit.contain,
                            opacity: item!.isBroken
                                ? const AlwaysStoppedAnimation(0.38)
                                : null,
                          )
                        : Opacity(
                            opacity: 0.2,
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.matrix(<double>[
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0.2126,
                                0.7152,
                                0.0722,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ]),
                              child: Image.asset(
                                definition.assetPath,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                  ),
                  if (!acquired)
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 17,
                          color: Color(0xFF6D645D),
                        ),
                      ),
                    ),
                  if (item?.equipped == true)
                    const Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.check_circle,
                          size: 20,
                          color: AppColors.leafGreen,
                        ),
                      ),
                    ),
                  if (item?.isBroken == true)
                    const Center(
                      child: Icon(
                        Icons.flash_on_rounded,
                        size: 48,
                        color: Color(0xFFB3261E),
                      ),
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

class _WoodenShelf extends StatelessWidget {
  const _WoodenShelf();

  @override
  Widget build(BuildContext context) => Container(
    height: 12,
    margin: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFCB9252), Color(0xFF6B3B21)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(4),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 4,
          offset: Offset(0, 3),
        ),
      ],
    ),
  );
}

class _ArtifactDetails extends StatefulWidget {
  const _ArtifactDetails({
    required this.definition,
    required this.item,
    required this.spendable,
    required this.onEquip,
    required this.onRepair,
  });

  final ArtifactDefinition definition;
  final ArtifactItem? item;
  final int spendable;
  final Future<void> Function(ArtifactItem item)? onEquip;
  final Future<void> Function(ArtifactItem item)? onRepair;

  @override
  State<_ArtifactDetails> createState() => _ArtifactDetailsState();
}

class _ArtifactDetailsState extends State<_ArtifactDetails> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // The owning screen already presents the localized failure message.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Image.asset(
            widget.definition.assetPath,
            height: 170,
            fit: BoxFit.contain,
            opacity: item == null || item.isBroken
                ? const AlwaysStoppedAnimation(0.42)
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.definition.name,
          textAlign: TextAlign.center,
          style: AppTextStyles.sectionTitle,
        ),
        const SizedBox(height: 8),
        Text(
          widget.definition.ability,
          textAlign: TextAlign.center,
          style: AppTextStyles.supporting,
        ),
        const SizedBox(height: 18),
        if (item == null)
          Text(
            'Ещё не получен',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardRowLabel,
          )
        else ...[
          Row(
            children: [
              Text('Прочность', style: AppTextStyles.cardRowLabel),
              const Spacer(),
              Text(
                '${item.durabilityCurrent}/${item.durabilityMax}',
                style: AppTextStyles.counterValue.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              key: Key('artifact-durability-${item.itemId}'),
              minHeight: 12,
              value: item.durabilityProgress,
              backgroundColor: AppColors.parchmentDark,
              color: _durabilityColor(item.durabilityProgress),
            ),
          ),
          if (item.isBroken) ...[
            const SizedBox(height: 10),
            const Text(
              'СЛОМАНО · способность не работает',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFB3261E),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (item.isWearable)
            FilledButton.icon(
              key: const Key('artifact-equip-action'),
              onPressed: _busy || item.isBroken || widget.onEquip == null
                  ? null
                  : () => _run(() => widget.onEquip!(item)),
              icon: Icon(
                item.equipped ? Icons.close_rounded : Icons.check_rounded,
              ),
              label: Text(item.equipped ? 'Снять' : 'Экипировать'),
            ),
          if (item.durabilityCurrent < item.durabilityMax) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('artifact-repair-action'),
              onPressed:
                  _busy ||
                      widget.onRepair == null ||
                      widget.spendable < item.repairCost
                  ? null
                  : () => _run(() => widget.onRepair!(item)),
              icon: const Icon(Icons.handyman_rounded),
              label: Text('Починить за ${item.repairCost} 🪙'),
            ),
            if (widget.spendable < item.repairCost)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  'В кошельке не хватает монет на ремонт.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.supporting,
                ),
              ),
          ],
        ],
      ],
    );
  }
}

Color _durabilityColor(double progress) {
  if (progress > 0.6) return AppColors.leafGreen;
  if (progress > 0.25) return const Color(0xFFFFA000);
  return const Color(0xFFB3261E);
}
