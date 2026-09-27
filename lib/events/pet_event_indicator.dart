import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pet_event_models.dart';

class PetEventIndicator extends StatefulWidget {
  const PetEventIndicator({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<PetEventIndicator> createState() => _PetEventIndicatorState();
}

class _PetEventIndicatorState extends State<PetEventIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Финни нужна помощь. Открыть событие',
      child: ScaleTransition(
        scale: Tween(begin: 0.92, end: 1.08).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Material(
          color: const Color(0xFFF2A63B),
          shape: const CircleBorder(),
          elevation: 5,
          child: IconButton(
            key: const Key('pet-event-indicator'),
            tooltip: 'Подорожник — Финни нужна помощь',
            onPressed: widget.onPressed,
            icon: const Icon(Icons.eco_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class PetEventBanner extends StatelessWidget {
  const PetEventBanner({
    super.key,
    required this.event,
    required this.onPressed,
  });

  final PetEventOccurrence event;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFE6BF),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        key: const Key('pet-event-banner'),
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: const Color(0xFFE39422), width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFF9B5512)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.definition.title,
                      style: AppTextStyles.cardRowLabel.copyWith(
                        color: const Color(0xFF6F3A08),
                      ),
                    ),
                    Text(
                      'Финни нужна помощь · ${event.amountDue} 🪙',
                      style: AppTextStyles.supporting.copyWith(
                        color: const Color(0xFF6F3A08),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9B5512)),
            ],
          ),
        ),
      ),
    );
  }
}
