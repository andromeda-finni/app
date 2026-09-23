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
        color: AppColors.parchment,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 54,
            height: 54,
            child: ExcludeSemantics(
              child: Icon(Icons.arrow_back, color: AppColors.ink, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
