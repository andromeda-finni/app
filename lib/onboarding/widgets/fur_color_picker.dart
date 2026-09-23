import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../onboarding_data.dart';

const furColorOptions = [
  FurColorOption(
    id: 'FUR_GRAY',
    label: 'серый',
    swatch: 0xFF85817E,
    catAsset: 'assets/Cat/Red_collar/base/striped.png',
  ),
  FurColorOption(
    id: 'FUR_ORANGE',
    label: 'рыжий',
    swatch: 0xFFD27A32,
    catAsset: 'assets/Cat/Red_collar/base/red.png',
  ),
  FurColorOption(
    id: 'FUR_WHITE',
    label: 'белый',
    swatch: 0xFFF3EDE2,
    catAsset: 'assets/Cat/Red_collar/base/white.png',
  ),
];

/// Looks up the cat art for a chosen fur id, falling back to the base pose
/// while nothing is chosen yet.
String catAssetForFur(String? furColorId, {bool happy = false}) {
  for (final option in furColorOptions) {
    if (option.id == furColorId) {
      return happy
          ? option.catAsset.replaceFirst('/base/', '/happy/')
          : option.catAsset;
    }
  }
  return kBaseCatAsset;
}

/// Three clean flat-colour choices. The transparent hit area is larger than
/// the painted circle, while selection remains visible through a ring, check
/// mark and semantics rather than colour alone.
class FurColorPicker extends StatelessWidget {
  const FurColorPicker({
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
            for (final option in furColorOptions)
              SizedBox(
                width: tileWidth,
                child: _Swatch(
                  option: option,
                  selectedId: selectedId,
                  onSelected: onSelected,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.option,
    required this.selectedId,
    required this.onSelected,
  });

  final FurColorOption option;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = option.id == selectedId;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Цвет шёрстки: ${option.label}',
      onTap: () => onSelected(option.id),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected(option.id),
          borderRadius: BorderRadius.circular(AppRadii.md),
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 82),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(option.swatch),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.crimson
                                : option.id == 'FUR_WHITE'
                                ? AppColors.parchmentDark
                                : Colors.transparent,
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected
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
                      if (isSelected)
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.crimson,
                              border: Border.fromBorderSide(
                                BorderSide(color: AppColors.canvas, width: 2),
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    option.label,
                    style: AppTextStyles.swatchLabel.copyWith(
                      color: isSelected
                          ? AppColors.crimsonDark
                          : AppColors.inkMuted,
                    ),
                    maxLines: 1,
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
