import 'package:flutter/material.dart';

import '../../core/pet_assets.dart';
import '../../theme/app_theme.dart';
import '../models/pet.dart';

class PetScene extends StatefulWidget {
  const PetScene({
    super.key,
    required this.pet,
    required this.backgroundAsset,
    this.height = 340,
    this.backgroundAlignment = Alignment.center,
    this.petHeightFactor = 0.7,
    this.heroTag,
  });

  final Pet pet;
  final String backgroundAsset;
  final double height;
  final Alignment backgroundAlignment;
  final double petHeightFactor;
  final String? heroTag;

  @override
  State<PetScene> createState() => _PetSceneState();
}

class _PetSceneState extends State<PetScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.99,
    end: 1.02,
  ).animate(CurvedAnimation(parent: _breathing, curve: Curves.easeInOut));
  bool _reacting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _breathe());
  }

  Future<void> _breathe() async {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    await _breathing.forward();
    if (mounted) await _breathing.reverse();
  }

  Future<void> _react() async {
    if (_reacting) return;
    setState(() => _reacting = true);
    _breathe();
    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (mounted) setState(() => _reacting = false);
  }

  @override
  void dispose() {
    _breathing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Image.asset(
        _reacting ? 'assets/Cat/Base/playful.png' : widget.pet.assetPath,
        key: ValueKey(_reacting ? 'pet-reaction' : widget.pet.assetPath),
        height: widget.height * widget.petHeightFactor,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
      ),
    );
    final petImage = widget.heroTag == null
        ? image
        : Hero(tag: widget.heroTag!, child: image);

    return Semantics(
      button: true,
      label: 'Питомец ${widget.pet.name}. Нажми, чтобы погладить.',
      onTap: _react,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _react,
            child: Ink(
              height: widget.height,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(widget.backgroundAsset),
                  fit: BoxFit.cover,
                  alignment: widget.backgroundAlignment,
                ),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: -4,
                    child: AnimatedBuilder(
                      animation: _scale,
                      child: petImage,
                      builder: (context, child) => Transform.scale(
                        scale: _scale.value,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: AnimatedOpacity(
                      opacity: _reacting ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'Мур-р! ♥',
                          style: AppTextStyles.cardRowLabel,
                        ),
                      ),
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

String petMoodWord(Pet pet) => switch (pet.mood) {
  PetMood.happy => 'довольный',
  PetMood.sad => 'грустный',
  PetMood.sleep => 'уставший',
  PetMood.fully => 'сытый',
  PetMood.base => 'спокойный',
};
