import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class BackCircleButton extends StatelessWidget {
  const BackCircleButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Назад',
      child: Material(
        color: AppColors.cardBg,
        shape: CircleBorder(side: BorderSide(color: AppColors.fieldBorder)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 52,
            height: 52,
            child: ExcludeSemantics(child: Icon(Icons.arrow_back, color: AppColors.ink, size: 22)),
          ),
        ),
      ),
    );
  }
}
