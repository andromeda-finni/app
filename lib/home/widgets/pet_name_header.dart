import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../models/pet.dart';

class PetNameHeader extends StatelessWidget {
  const PetNameHeader({
    super.key,
    required this.pet,
    required this.onRename,
    this.showStage = false,
  });

  final Pet pet;
  final Future<void> Function(String name) onRename;
  final bool showStage;

  Future<void> _edit(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initialName: pet.name),
    );
    if (name == null || name == pet.name || !context.mounted) return;
    try {
      await onRename(name);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не получилось сохранить имя. Попробуй ещё раз.'),
        ),
      );
    }
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
                tooltip: 'Изменить имя',
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
  const _RenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );
  String? _error;

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введи имя');
      return;
    }
    Navigator.of(context).pop(name);
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
      title: const Text('Как зовут питомца?'),
      content: TextField(
        key: const Key('pet-name-field'),
        controller: _controller,
        autofocus: true,
        maxLength: 24,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Имя',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.crimson),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
