import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../onboarding_data.dart';

const furColorOptions = [
  FurColorOption(
    id: 'FUR_GRAY',
    label: 'серый',
    swatch: 0xFF9B9082,
    catAsset: 'assets/Cat/Red_collar/base/striped.png',
  ),
  FurColorOption(
    id: 'FUR_ORANGE',
    label: 'рыжий',
    swatch: 0xFFC97A3D,
    catAsset: 'assets/Cat/Red_collar/base/red.png',
  ),
  FurColorOption(
    id: 'FUR_WHITE',
    label: 'белый',
    swatch: 0xFFEDE6D8,
    catAsset: 'assets/Cat/Red_collar/base/white.png',
  ),
];

// The swatch shows a patch of the cat's own coat rather than a flat colour,
// so "серый/рыжий/белый" previews the actual art. The cut-out is drawn far
// larger than the 40px circle and offset onto the flank, which is the one
// region that is pure fur in all three variants (the chest is white on every
// cat and the collar is red on every cat, so either would preview the same
// swatch three times).
const _swatchZoom = 116.0;
const _swatchFocus = Alignment(-0.45, 0.30);

/// Looks up the cat art for a chosen fur id, falling back to the base pose
/// while nothing is chosen yet.
String catAssetForFur(String? furColorId) {
  for (final option in furColorOptions) {
    if (option.id == furColorId) return option.catAsset;
  }
  return kBaseCatAsset;
}

/// One fur swatch + label, sized to sit inline inside the story paragraph
/// via a WidgetSpan (see onboarding_step1_screen.dart).
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
    // Wrap, not Row: at large text-scale factors the labels below each
    // swatch widen past the circle, and a plain Row (sized to fit inline
    // inside the story text) has no way to shrink and overflows. Wrap lets
    // a swatch drop to a second line instead.
    return Wrap(
      children: [
        for (final option in furColorOptions)
          _Swatch(
            option: option,
            selectedId: selectedId,
            onSelected: onSelected,
          ),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: 'Цвет шёрстки: ${option.label}',
        child: GestureDetector(
          onTap: () => onSelected(option.id),
          behavior: HitTestBehavior.opaque,
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // Sits under the art so the circle still reads as the
                        // right colour wherever the cut-out is transparent.
                        color: Color(option.swatch),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.crimson
                              : AppColors.fieldBorder,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                      child: ClipOval(
                        child: OverflowBox(
                          maxWidth: _swatchZoom,
                          maxHeight: _swatchZoom,
                          alignment: _swatchFocus,
                          child: Image.asset(
                            option.catAsset,
                            width: _swatchZoom,
                            height: _swatchZoom,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.crimson,
                            border: Border.fromBorderSide(
                              BorderSide(color: Colors.white, width: 1.5),
                            ),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(option.label, style: AppTextStyles.swatchLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
