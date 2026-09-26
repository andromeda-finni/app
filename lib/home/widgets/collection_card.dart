import 'package:flutter/material.dart';

import '../../economy/item_artwork.dart';
import '../../theme/app_theme.dart';
import '../models/artifact.dart';

/// The artefact shelf. Empty slots are drawn as dashed silhouettes so the
/// shelf reads as "there is room for three things here" rather than as a
/// broken or still-loading card.
class CollectionCard extends StatelessWidget {
  const CollectionCard({
    super.key,
    required this.items,
    required this.busy,
    required this.onEquip,
    this.slots = 3,
  });

  final List<Artifact> items;
  final bool busy;
  final ValueChanged<String?> onEquip;
  final int slots;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/icons/chest.webp', width: 30, height: 30),
              const SizedBox(width: 10),
              Text('Коллекция', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in items)
                _ArtifactTile(item: item, busy: busy, onEquip: onEquip),
              for (var i = items.length; i < slots; i++) const _EmptySlot(),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.parchmentDark,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              items.isEmpty
                  ? 'Артефакты появятся после покупок за накопления.'
                  : 'Надетый артефакт помогает питомцу и отмечен галочкой.',
              textAlign: TextAlign.center,
              style: AppTextStyles.swatchLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtifactTile extends StatelessWidget {
  const _ArtifactTile({
    required this.item,
    required this.busy,
    required this.onEquip,
  });

  final Artifact item;
  final bool busy;
  final ValueChanged<String?> onEquip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: item.equipped,
      label: '${item.name}. ${item.equipped ? 'Надет' : 'Не надет'}',
      child: InkWell(
        key: ValueKey('artifact-${item.inventoryId}'),
        onTap: busy
            ? null
            : () => onEquip(item.equipped ? null : item.inventoryId),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 92,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ItemArtwork(
                    itemId: item.itemId,
                    semanticLabel: item.name,
                    size: 68,
                    borderRadius: 12,
                  ),
                  if (item.equipped)
                    const Positioned(
                      right: -4,
                      top: -4,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: AppColors.leafGreen,
                        child: Icon(Icons.check, size: 15, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.swatchLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.parchment.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder.withValues(alpha: 0.8)),
      ),
      child: Icon(
        Icons.pets,
        size: 26,
        color: AppColors.inkMuted.withValues(alpha: 0.45),
      ),
    );
  }
}
