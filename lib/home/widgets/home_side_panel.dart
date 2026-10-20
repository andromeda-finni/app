import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/wax_seal.dart';

enum HomePanelStyle { classic, waxSeal }

const _defaultPanelStyle =
    bool.fromEnvironment('HOME_WAX_SEAL_BUTTONS', defaultValue: true)
    ? HomePanelStyle.waxSeal
    : HomePanelStyle.classic;

/// One action of the home's left-side panel: a round, colour-coded medallion
/// drawn over the room scene, game-style. The picture carries the meaning on
/// screen; [label] is still announced by screen readers and shown as a
/// tooltip on long press, so the button never depends on its icon alone.
class HomePanelAction {
  const HomePanelAction({
    required this.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.attention = false,
    this.busy = false,
    this.tourKey,
  });

  final Key key;
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  /// Marks the action the child should take next with a badge and a short
  /// pulse, e.g. a plan that still has to be made.
  final bool attention;
  final bool busy;
  final GlobalKey? tourKey;
}

class HomeSidePanel extends StatelessWidget {
  const HomeSidePanel({
    super.key,
    required this.actions,
    this.style = _defaultPanelStyle,
  });

  final List<HomePanelAction> actions;
  final HomePanelStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            KeyedSubtree(
              key: actions[i].tourKey,
              child: _PanelButton(action: actions[i], style: style),
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelButton extends StatefulWidget {
  const _PanelButton({required this.action, required this.style});

  final HomePanelAction action;
  final HomePanelStyle style;

  @override
  State<_PanelButton> createState() => _PanelButtonState();
}

class _PanelButtonState extends State<_PanelButton>
    with SingleTickerProviderStateMixin {
  static const _size = 60.0;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  bool _pulsed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pulseIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _PanelButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.action.attention && widget.action.attention) {
      _pulsed = false;
    }
    _pulseIfNeeded();
  }

  // A few beats only: a looping animation would pressure the child and keep
  // the frame clock busy forever.
  void _pulseIfNeeded() {
    if (_pulsed ||
        !widget.action.attention ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _pulsed = true;
    _pulse.repeat(reverse: true, count: 3);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final enabled = action.onTap != null && !action.busy;
    final color = enabled ? action.color : AppColors.inkMuted;
    final medallion = widget.style == HomePanelStyle.waxSeal
        ? WaxSeal(
            size: _size,
            icon: action.icon,
            child: action.busy
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFFF4CBAB),
                    ),
                  )
                : null,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(color, Colors.white, 0.22)!, color],
              ),
              border: Border.all(color: AppColors.cardBg, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: enabled ? 0.28 : 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SizedBox.square(
              dimension: _size,
              child: Center(
                child: action.busy
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Icon(action.icon, size: 32, color: Colors.white),
              ),
            ),
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      excludeSemantics: true,
      onTap: enabled ? action.onTap : null,
      child: Tooltip(
        message: action.label,
        excludeFromSemantics: true,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) =>
              Transform.scale(scale: 1 + _pulse.value * 0.08, child: child),
          child: Opacity(
            opacity: enabled ? 1 : 0.6,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  type: MaterialType.transparency,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: action.key,
                    onTap: enabled ? action.onTap : null,
                    customBorder: const CircleBorder(),
                    child: medallion,
                  ),
                ),
                if (action.attention)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: _AttentionBadge(style: widget.style),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttentionBadge extends StatelessWidget {
  const _AttentionBadge({required this.style});

  final HomePanelStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style == HomePanelStyle.waxSeal
            ? AppColors.parchment
            : AppColors.coinGold,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cardBg, width: 2),
      ),
      child: Text(
        '!',
        style: TextStyle(
          color: style == HomePanelStyle.waxSeal
              ? AppColors.crimson
              : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          height: 1,
        ),
      ),
    );
  }
}
