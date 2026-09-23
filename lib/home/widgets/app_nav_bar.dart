import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// One tab of the bottom bar. The outlined icon is the resting state and the
/// filled one marks the selected tab, which is what separates "Дом" from the
/// rest in the reference design.
class NavDestination {
  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const kNavDestinations = <NavDestination>[
  NavDestination(
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'Дом',
  ),
  NavDestination(
    icon: Icons.map_outlined,
    activeIcon: Icons.map,
    label: 'Карта',
  ),
  NavDestination(
    icon: Icons.storefront_outlined,
    activeIcon: Icons.storefront,
    label: 'Магазин',
  ),
  NavDestination(
    icon: Icons.savings_outlined,
    activeIcon: Icons.savings,
    label: 'Копилка',
  ),
];

/// The bottom bar: four tabs on parchment, the selected one drawn in crimson
/// with a filled icon and a dot beneath its label.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(
          top: BorderSide(color: AppColors.fieldBorder.withValues(alpha: 0.55)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < kNavDestinations.length; i++)
              Expanded(
                child: _NavItem(
                  destination: kNavDestinations[i],
                  selected: i == currentIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    // Hover and keyboard focus preview the selected look rather than
    // inventing a third colour, so pointing at a tab reads as "this is what
    // you are about to open".
    final previewing = !selected && (_hovered || _focused);
    final foreground = selected
        ? AppColors.crimson
        : previewing
        ? AppColors.crimson.withValues(alpha: 0.7)
        : AppColors.inkMuted;

    // Merged so a screen reader announces the tab once, as "Дом, selected,
    // button" — without this the label, the tap target and the selected flag
    // are three separate nodes the user has to swipe through.
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          borderRadius: BorderRadius.circular(18),
          hoverColor: AppColors.crimson.withValues(alpha: 0.05),
          focusColor: AppColors.crimson.withValues(alpha: 0.09),
          splashColor: AppColors.crimson.withValues(alpha: 0.12),
          highlightColor: AppColors.crimson.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              // A ring, not just a tint: a keyboard user gets no hover colour
              // to go by, so focus needs an outline that survives on top of
              // whatever background the tab already has.
              border: Border.all(
                color: _focused ? AppColors.crimson : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected
                      ? widget.destination.activeIcon
                      : widget.destination.icon,
                  size: 27,
                  color: foreground,
                ),
                const SizedBox(height: 3),
                Text(
                  widget.destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.navLabel.copyWith(color: foreground),
                ),
                // The dot's row keeps its height whether or not the dot is
                // drawn, so switching tabs never nudges the labels.
                SizedBox(
                  height: 10,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: selected ? 1 : 0,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.crimson,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
