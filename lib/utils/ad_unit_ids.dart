import 'dart:io' show Platform;

/// Central AdMob unit IDs for full-screen placements.
class AdUnitIds {
  AdUnitIds._();

  static String get novelInterstitial => Platform.isIOS
      ? 'ca-app-pub-6924141712831128/2224608196'
      : 'ca-app-pub-6924141712831128/4882791708';

  static String get episodeRewarded => Platform.isIOS
      ? 'ca-app-pub-6924141712831128/8598444853'
      : 'ca-app-pub-6924141712831128/8822036717';

  /// Voiceover rewarded uses the same unit as episode rewarded on iOS today.
  static String get voiceoverRewarded => episodeRewarded;
}
