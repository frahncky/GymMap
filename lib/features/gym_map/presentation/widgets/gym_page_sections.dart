import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/l10n/l10n.dart';
import '../gym_map_colors.dart';
import '../gym_map_helpers.dart';

class QuickFilterChipData {
  const QuickFilterChipData({
    required this.id,
    required this.label,
    required this.icon,
    required this.selected,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool selected;
}

class GymPageHeader extends StatelessWidget {
  const GymPageHeader({
    super.key,
    required this.planLabel,
    required this.planBadgeColor,
    required this.planBadgeTextColor,
    required this.communityPoints,
    required this.onOpenPlanSettings,
    required this.onOpenCommunityRanking,
  });

  final String planLabel;
  final Color planBadgeColor;
  final Color planBadgeTextColor;
  final int communityPoints;
  final VoidCallback onOpenPlanSettings;
  final VoidCallback onOpenCommunityRanking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Row(
        children: [
          Image.asset(
            'assets/brand/pin.png',
            height: 44,
            semanticLabel: 'GymMap',
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrandWordmark(
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: withUiOpacity(planBadgeColor, 0.90),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              planLabel,
              style: TextStyle(
                color: planBadgeTextColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: _t.headerCommunityPointsLabel('$communityPoints'),
            hint: _t.headerCommunityPointsHint,
            child: Tooltip(
              message: _t.headerOpenRanking,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onOpenCommunityRanking,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: withUiOpacity(Colors.white, 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.workspace_premium_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _t.communityPointsShort(
                                '${communityPoints.clamp(0, 1000000)}',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: _t.headerPlanSettings,
            hint: _t.headerPlanSettingsHint,
            child: IconButton(
              tooltip: _t.headerPlanSettings,
              onPressed: onOpenPlanSettings,
              icon: const Icon(Icons.settings, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class GymSearchField extends StatelessWidget {
  const GymSearchField({
    super.key,
    required this.controller,
    required this.searchTerm,
    required this.isResolvingSearchLocation,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onSearchTap,
  });

  final TextEditingController controller;
  final String searchTerm;
  final bool isResolvingSearchLocation;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: _t.searchFieldLabel,
      hint: _t.searchFieldHint,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: _t.searchPlaceholder,
          prefixIcon: IconButton(
            onPressed: onSearchTap,
            icon: const Icon(Icons.search),
            tooltip: _t.searchLocationTooltip,
          ),
          suffixIcon:
              searchTerm.isEmpty
                  ? null
                  : isResolvingSearchLocation
                  ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                  : IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                    tooltip: _t.searchClearTooltip,
                  ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class MapQuickFiltersBar extends StatelessWidget {
  const MapQuickFiltersBar({
    super.key,
    required this.filters,
    required this.onToggle,
  });

  final List<QuickFilterChipData> filters;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: withUiOpacity(Colors.white, 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: withUiOpacity(primary, 0.12)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final gapsWidth = (filters.length - 1) * 6;
          final slotWidth =
              filters.isEmpty
                  ? availableWidth
                  : ((availableWidth - gapsWidth) / filters.length);
          const minReadableSlotWidth = 100.0;
          if (slotWidth >= minReadableSlotWidth) {
            return Row(
              children: [
                for (var index = 0; index < filters.length; index++)
                  Expanded(
                    flex: _chipFlex(filters[index]),
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == filters.length - 1 ? 0 : 6,
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: _QuickFilterToggleChip(
                          filter: filters[index],
                          onToggle: onToggle,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < filters.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: index == filters.length - 1 ? 0 : 6,
                    ),
                    child: _QuickFilterToggleChip(
                      filter: filters[index],
                      onToggle: onToggle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _chipFlex(QuickFilterChipData filter) {
    if (filter.id == 'open') {
      return 4;
    }
    if (filter.id == 'low') {
      return 3;
    }
    if (filter.id == 'favorites') {
      return 3;
    }
    return 2;
  }
}

class _QuickFilterToggleChip extends StatelessWidget {
  const _QuickFilterToggleChip({required this.filter, required this.onToggle});

  final QuickFilterChipData filter;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: filter.selected,
      label: _t.filterSemanticsLabel(filter.label),
      hint: filter.selected ? _t.filterTapToRemove : _t.filterTapToApply,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: FilterChip(
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          labelPadding: const EdgeInsets.symmetric(horizontal: 2),
          avatarBoxConstraints: const BoxConstraints.tightFor(
            width: 18,
            height: 18,
          ),
          avatar: Icon(
            filter.icon,
            size: 14,
            color:
                filter.selected
                    ? Theme.of(context).colorScheme.primary
                    : GymMapColors.textSecondary,
          ),
          selected: filter.selected,
          label: Text(filter.label, maxLines: 1),
          onSelected: (_) => onToggle(filter.id),
          selectedColor: withUiOpacity(
            Theme.of(context).colorScheme.primary,
            0.14,
          ),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: withUiOpacity(
              Theme.of(context).colorScheme.primary,
              filter.selected ? 0.38 : 0.12,
            ),
          ),
          labelStyle: TextStyle(
            color:
                filter.selected
                    ? Theme.of(context).colorScheme.primary
                    : GymMapColors.textStrong,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }
}

class SelectionHintCard extends StatelessWidget {
  const SelectionHintCard({
    super.key,
    required this.hasNoResults,
    required this.hasNoNearbyGyms,
    required this.needsLocationForNearbyGyms,
    this.hasActiveFilters = false,
    this.onClearFilters,
  });

  final bool hasNoResults;
  final bool hasNoNearbyGyms;
  final bool needsLocationForNearbyGyms;
  final bool hasActiveFilters;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    if (!hasNoResults && !hasNoNearbyGyms && !needsLocationForNearbyGyms) {
      return const SizedBox.shrink();
    }

    final message =
        needsLocationForNearbyGyms
            ? _t.emptyZoomIn
            : hasNoResults && hasActiveFilters
            ? _t.emptyNoFilterMatch
            : hasNoResults
            ? _t.emptyNoSearchResults
            : hasNoNearbyGyms
            ? _t.emptyNoNearbyGyms
            : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const BrandEmptyPin(size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (hasNoResults && hasActiveFilters && onClearFilters != null) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onClearFilters,
              child: Text(_t.filterClearAll),
            ),
          ],
        ],
      ),
    );
  }
}

class AdBannerCard extends StatefulWidget {
  const AdBannerCard({super.key});

  @override
  State<AdBannerCard> createState() => _AdBannerCardState();
}

class _AdBannerCardState extends State<AdBannerCard> {
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  // Padrão: IDs de teste do Google. Em produção defina via --dart-define.
  static const String _androidBannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ID_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const String _iosBannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ID_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );

  String? _resolveBannerAdUnitId() {
    if (kIsWeb) {
      return null;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidBannerAdUnitId;
      case TargetPlatform.iOS:
        return _iosBannerAdUnitId;
      default:
        return null;
    }
  }

  void _loadBannerAd() {
    final adUnitId = _resolveBannerAdUnitId();
    if (adUnitId == null) {
      return;
    }
    final ad = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (!mounted) {
            loadedAd.dispose();
            return;
          }
          setState(() {
            _bannerAd = loadedAd as BannerAd;
            _isBannerLoaded = true;
          });
        },
        onAdFailedToLoad: (failedAd, error) {
          failedAd.dispose();
          if (!mounted) {
            return;
          }
          setState(() {
            _isBannerLoaded = false;
            _bannerAd = null;
          });
        },
      ),
    );
    ad.load();
  }

  Widget _buildFallbackCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [GymMapColors.adGradientStart, GymMapColors.adGradientEnd],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign, color: GymMapColors.adIcon),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _t.adLabel,
              style: TextStyle(
                color: GymMapColors.adText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bannerAd = _bannerAd;
    if (!_isBannerLoaded || bannerAd == null) {
      return _buildFallbackCard();
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: bannerAd.size.height.toDouble(),
        width: bannerAd.size.width.toDouble(),
        child: AdWidget(ad: bannerAd),
      ),
    );
  }
}

class MapStatusCard extends StatelessWidget {
  const MapStatusCard({super.key, required this.message, this.loading = false});

  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
      ),
      child: Center(
        child:
            loading
                ? TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.35, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeInOut,
                  builder: (context, opacity, _) {
                    return Opacity(
                      opacity: opacity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: withUiOpacity(
                                Theme.of(context).colorScheme.primary,
                                0.12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: 148,
                            height: 12,
                            decoration: BoxDecoration(
                              color: withUiOpacity(
                                Theme.of(context).colorScheme.primary,
                                0.10 + (0.12 * opacity),
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            message,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: GymMapColors.textStrong,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
                : Text(message),
      ),
    );
  }
}

class MapTutorialOverlay extends StatelessWidget {
  const MapTutorialOverlay({
    super.key,
    required this.onDismiss,
    required this.onFocusNearestGym,
  });

  final VoidCallback onDismiss;
  final VoidCallback onFocusNearestGym;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: withUiOpacity(Colors.black, 0.26),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: withUiOpacity(
                        Theme.of(context).colorScheme.primary,
                        0.12,
                      ),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 14,
                        color: GymMapColors.cardShadow,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t.tutorialTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: GymMapColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _TutorialHintRow(
                        icon: Icons.search_rounded,
                        text: _t.tutorialSearch,
                      ),
                      const SizedBox(height: 6),
                      _TutorialHintRow(
                        icon: Icons.tune_rounded,
                        text: _t.tutorialFilters,
                      ),
                      const SizedBox(height: 6),
                      _TutorialHintRow(
                        icon: Icons.location_on_rounded,
                        text: _t.tutorialPin,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onDismiss,
                              child: Text(_t.tutorialGotIt),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onFocusNearestGym,
                              icon: const Icon(Icons.near_me_rounded, size: 18),
                              label: Text(_t.tutorialShowNearest),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              TextButton(onPressed: onDismiss, child: Text(_t.tutorialSkip)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialHintRow extends StatelessWidget {
  const _TutorialHintRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: GymMapColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: GymMapColors.textStrong,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Traduções do idioma em uso.
AppLocalizations get _t => AppL10n.current;

/// "GymMap" com "Map" no gradiente da marca, como no splash e no README.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.style});

  static const List<Color> gradient = <Color>[
    Color(0xFF3FC6F0),
    Color(0xFF22B7A8),
    Color(0xFF7EDB5A),
  ];

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Gym', style: style),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback:
              (bounds) => const LinearGradient(
                colors: gradient,
              ).createShader(Offset.zero & bounds.size),
          child: Text('Map', style: style),
        ),
      ],
    );
  }
}

/// Pino da marca nas telas sem conteúdo (sem favoritos, sem relatos...).
class BrandEmptyPin extends StatelessWidget {
  const BrandEmptyPin({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset('assets/brand/pin.png', height: size),
    );
  }
}
