import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../app/config.dart';
import '../../theme/app_theme.dart';

/// Ads (AdMob adaptive banner). Rules from the spec:
/// - only Home bottom and the end of the reading; never during loading, offline, or the reveal;
/// - when it fails or is offline, the slot collapses (no empty box).
/// Category blocking (gambling, dating, loans, get-rich-quick) is set in the AdMob console.
class Ads {
  static Future<void> init() async {
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
    );
  }
}

class AdBanner extends StatefulWidget {
  const AdBanner({super.key, required this.enabled, this.label});
  final bool enabled; // false while loading or offline
  final String? label; // "Advertisement" on the reading page
  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(AdBanner old) {
    super.didUpdateWidget(old);
    _maybeLoad();
  }

  Future<void> _maybeLoad() async {
    if (!widget.enabled || _requested) return;
    _requested = true;
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;
    final ad = BannerAd(
      adUnitId: AppConfig.admobBannerUnit,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!widget.enabled || ad == null || !_loaded) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: Text(widget.label!, style: AppText.caption),
          ),
        ],
        SizedBox(width: ad.size.width.toDouble(), height: ad.size.height.toDouble(), child: AdWidget(ad: ad)),
      ],
    );
  }
}
