import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'drop_cap_ornament.dart';

/// A purely narrative paragraph: big red drop cap + small ornament on the
/// left, first line of text beside it, remaining lines flowing full-width
/// below. Used by the story-only onboarding steps (no inputs).
class DropCapStory extends StatelessWidget {
  const DropCapStory({
    super.key,
    required this.dropCap,
    required this.firstLine,
    required this.rest,
  });

  final String dropCap;
  final String firstLine;
  final String rest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(dropCap, style: AppTextStyles.dropCap),
            const SizedBox(width: 4),
            const DropCapOrnament(),
            const SizedBox(width: 6),
            Expanded(child: Text(firstLine, style: AppTextStyles.story)),
          ],
        ),
        const SizedBox(height: 6),
        Text(rest, style: AppTextStyles.story),
      ],
    );
  }
}
