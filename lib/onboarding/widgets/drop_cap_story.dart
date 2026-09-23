import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A readable narrative paragraph with one decorative initial. Decorative
/// typography is deliberately limited to the first letter.
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
    final story = rest.isEmpty ? firstLine : '$firstLine $rest';
    return Semantics(
      label: '$dropCap$story',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StoryDropCap(letter: dropCap),
                Expanded(child: Text(firstLine, style: AppTextStyles.story)),
              ],
            ),
            if (rest.isNotEmpty) Text(rest, style: AppTextStyles.story),
          ],
        ),
      ),
    );
  }
}

/// Decorative initial kept intentionally simple: the display face and crimson
/// colour already provide enough emphasis without competing ornament.
class StoryDropCap extends StatelessWidget {
  const StoryDropCap({super.key, required this.letter, this.size = 66});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    // The accent font has generous right-side bearings. A deliberately tight
    // box makes the following letters read as one word with the initial. The
    // box follows the system text scale as well, otherwise wide letters such
    // as «П» can paint over the continuation at accessibility sizes.
    final effectiveSize = MediaQuery.textScalerOf(context).scale(size);
    final visualWidth = effectiveSize * 0.70;
    return SizedBox(
      width: visualWidth,
      height: effectiveSize * 0.92,
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          letter,
          style: AppTextStyles.dropCap.copyWith(fontSize: size - 4),
        ),
      ),
    );
  }
}
