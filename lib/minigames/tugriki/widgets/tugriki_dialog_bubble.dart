import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../tugriki_game_data.dart';

class TugrikiDialogBubble extends StatelessWidget {
  const TugrikiDialogBubble({
    super.key,
    required this.speakerName,
    required this.text,
    this.isSparrow = true,
    this.isHappy = false,
    this.footerWidget,
  });

  final String speakerName;
  final String text;
  final bool isSparrow;
  final bool isHappy;
  final Widget? footerWidget;

  @override
  Widget build(BuildContext context) {
    final avatarAsset = isSparrow
        ? (isHappy ? TugrikiAssets.vorobeyHappy : TugrikiAssets.vorobeyNormal)
        : TugrikiAssets.catStriped;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.fieldBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F3B2F27),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.parchment,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSparrow ? AppColors.crimson : AppColors.leafGreen,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    avatarAsset,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      speakerName,
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSparrow ? AppColors.crimson : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: const TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 16,
                        height: 1.35,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (footerWidget != null) ...[
            const SizedBox(height: 12),
            footerWidget!,
          ],
        ],
      ),
    );
  }
}
