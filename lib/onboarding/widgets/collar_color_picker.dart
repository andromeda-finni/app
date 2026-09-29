import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../onboarding_data.dart';

const collarColorOptions = [
  CollarColorOption(id: 'ACC_COLLAR_RED', label: 'красный', swatch: 0xFFB62C28),
  CollarColorOption(
    id: 'ACC_COLLAR_GREEN',
    label: 'зелёный',
    swatch: 0xFF4E713D,
  ),
  CollarColorOption(id: 'ACC_COLLAR_BLUE', label: 'синий', swatch: 0xFF2768A8),
];

/// Three labelled colour choices. Labels, a selection ring and a check mark
/// make the state understandable without relying on colour perception alone.
class CollarColorPicker extends StatelessWidget {
  const CollarColorPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - AppSpacing.sm * 2) / 3;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in collarColorOptions)
              SizedBox(
                width: tileWidth,
                child: _CollarSwatch(
                  option: option,
                  selected: option.id == selectedId,
                  onSelected: onSelected,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CollarSwatch extends StatelessWidget {
  const _CollarSwatch({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  final CollarColorOption option;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Цвет ошейника: ${option.label}',
      onTap: () => onSelected(option.id),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected(option.id),
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(option.swatch),
                          border: Border.all(
                            color: selected
                                ? AppColors.crimsonDark
                                : AppColors.parchmentDark,
                            width: selected ? 3 : 1,
                          ),
                          boxShadow: selected
                              ? const [
                                  BoxShadow(
                                    color: Color(0x24AD2B23),
                                    blurRadius: 0,
                                    spreadRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      if (selected)
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.crimson,
                              border: Border.fromBorderSide(
                                BorderSide(color: AppColors.canvas, width: 2),
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    option.label,
                    maxLines: 1,
                    style: AppTextStyles.swatchLabel.copyWith(
                      color: selected
                          ? AppColors.crimsonDark
                          : AppColors.inkMuted,
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
