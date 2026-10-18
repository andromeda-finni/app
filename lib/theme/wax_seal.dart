import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared wax medallion for dictionary and home actions.
class WaxSeal extends StatelessWidget {
  const WaxSeal({
    super.key,
    this.size = 48,
    this.icon = Icons.auto_stories_outlined,
    this.child,
  });
  final double size;
  final IconData icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: [Color(0xFFB34E51), AppColors.crimson, Color(0xFF5F1A26)],
      ),
      border: Border.all(color: const Color(0xFF74222D), width: 3),
      boxShadow: const [
        BoxShadow(
          color: Color(0x402F130A),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Center(
      child: Container(
        width: size * 0.75,
        height: size * 0.75,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCD7A71)),
        ),
        child:
            child ??
            Icon(icon, color: const Color(0xFFF4CBAB), size: size * 0.4),
      ),
    ),
  );
}
