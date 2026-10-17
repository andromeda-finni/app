import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../core/pet_assets.dart';
import '../../onboarding/widgets/collar_color_picker.dart';
import '../models/pet.dart';

class PetNameHeader extends StatelessWidget {
  const PetNameHeader({
    super.key,
    required this.pet,
    required this.onRename,
    this.onUpdateIdentity,
    this.showStage = false,
  });

  final Pet pet;
  final Future<void> Function(String name) onRename;
  final Future<void> Function(String name, String collarId)? onUpdateIdentity;
  final bool showStage;

  Future<void> _edit(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _RenameDialog(
        pet: pet,
        allowCollar: onUpdateIdentity != null,
        onSave: (name, collar) async {
          if (onUpdateIdentity != null) {
            await onUpdateIdentity!(name, collar);
          } else {
            await onRename(name);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 390 ||
        MediaQuery.textScalerOf(context).scale(16) > 21;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!compact) ...[
              Image.asset('assets/icons/leaf.webp', width: 28, height: 28),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                pet.name,
                key: const Key('pet-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.dropCap.copyWith(
                  fontSize: compact ? 32 : 38,
                ),
              ),
            ),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const Key('edit-pet-name'),
                tooltip: onUpdateIdentity == null
                    ? 'Изменить имя'
                    : 'Изменить имя и ошейник',
                onPressed: () => _edit(context),
                icon: const Icon(Icons.edit_rounded),
                color: AppColors.crimson,
              ),
            ),
            if (!compact)
              Transform.flip(
                flipX: true,
                child: Image.asset(
                  'assets/icons/leaf.webp',
                  width: 28,
                  height: 28,
                ),
              ),
          ],
        ),
        if (showStage) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Text(
              'Стадия ${pet.evolutionStage} из ${Pet.maxStage} · ${pet.stageName}',
              style: AppTextStyles.swatchLabel.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ],
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({
    required this.pet,
    required this.allowCollar,
    required this.onSave,
  });

  final Pet pet;
  final bool allowCollar;
  final Future<void> Function(String name, String collarId) onSave;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.pet.name,
  );
  late String _collarId =
      CollarColorPicker.options.any(
        (option) => option.id == widget.pet.accessoryOptionId,
      )
      ? widget.pet.accessoryOptionId!
      : 'ACC_COLLAR_RED';
  String? _error;
  bool _saving = false;

  Future<void> _submit() async {
    if (_saving) return;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введи имя');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(name, _collarId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Не получилось сохранить. Проверь связь и попробуй ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      title: Text(widget.allowCollar ? 'Имя и ошейник' : 'Как зовут питомца?'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.allowCollar) ...[
                Image.asset(
                  catAsset(
                    furOptionId: widget.pet.furOptionId,
                    accessoryOptionId: _collarId,
                    evolutionStage: widget.pet.evolutionStage,
                  ),
                  height: 130 * catStageScale(widget.pet.evolutionStage),
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextField(
                key: const Key('pet-name-field'),
                controller: _controller,
                autofocus: !widget.allowCollar,
                enabled: !_saving,
                maxLength: 24,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Имя',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (widget.allowCollar) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Цвет ошейника', style: AppTextStyles.sectionTitle),
                IgnorePointer(
                  ignoring: _saving,
                  child: CollarColorPicker(
                    selectedId: _collarId,
                    onSelected: (id) => setState(() => _collarId = id),
                  ),
                ),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: AppTextStyles.supporting.copyWith(
                    color: AppColors.crimson,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.crimson),
          child: Text(_saving ? 'Сохраняем…' : 'Сохранить'),
        ),
      ],
    );
  }
}
