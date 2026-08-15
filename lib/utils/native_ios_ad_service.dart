import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'admob_log.dart';
import 'full_screen_ad_coordinator.dart';

enum NativeAdResult {
  rewarded,
  dismissed,
  failed,
  notReady,
  alreadyShowing,
}

/// iOS-only native full-screen ad bridge. Android must keep using
/// [FullScreenAdCoordinator] with `google_mobile_ads`.
class NativeIosAdService {
  NativeIosAdService._();

  static final NativeIosAdService instance = NativeIosAdService._();

  static const MethodChannel _channel =
      MethodChannel('com.farwa.farwa_khalid/native_ads');

  bool _isShowing = false;

  bool get isFullScreenAdShowing => _isShowing;

  Future<bool> loadInterstitial({required String adUnitId}) async {
    if (!Platform.isIOS) return false;
    AdMobLog.debug('native load start (interstitial)');
    final loaded = await _channel.invokeMethod<bool>(
      'loadInterstitial',
      {'adUnitId': adUnitId},
    );
    AdMobLog.debug('native load end (interstitial): loaded=$loaded');
    return loaded ?? false;
  }

  Future<NativeAdResult> showInterstitial() async {
    if (!Platform.isIOS) return NativeAdResult.failed;

    _isShowing = true;
    AdMobLog.debug('native show requested (interstitial)');

    try {
      final result = await _channel.invokeMethod<String>('showInterstitial');
      AdMobLog.debug('native show result (interstitial): $result');
      return _parseResult(result);
    } catch (e) {
      AdMobLog.debug('native show threw (interstitial): $e');
      return NativeAdResult.failed;
    } finally {
      _isShowing = false;
    }
  }

  Future<bool> loadRewarded({required String adUnitId}) async {
    if (!Platform.isIOS) return false;
    AdMobLog.debug('native load start (rewarded)');
    final loaded = await _channel.invokeMethod<bool>(
      'loadRewarded',
      {'adUnitId': adUnitId},
    );
    AdMobLog.debug('native load end (rewarded): loaded=$loaded');
    return loaded ?? false;
  }

  Future<NativeAdResult> showRewarded() async {
    if (!Platform.isIOS) return NativeAdResult.failed;

    _isShowing = true;
    AdMobLog.debug('native show requested (rewarded)');

    try {
      final result = await _channel.invokeMethod<String>('showRewarded');
      AdMobLog.debug('native show result (rewarded): $result');
      return _parseResult(result);
    } catch (e) {
      AdMobLog.debug('native show threw (rewarded): $e');
      return NativeAdResult.failed;
    } finally {
      _isShowing = false;
    }
  }

  Future<void> disposeInterstitial() async {
    if (!Platform.isIOS || _isShowing) return;
    await _channel.invokeMethod<void>('disposeInterstitial');
  }

  Future<void> disposeRewarded() async {
    if (!Platform.isIOS || _isShowing) return;
    await _channel.invokeMethod<void>('disposeRewarded');
  }

  NativeAdResult _parseResult(String? value) {
    switch (value) {
      case 'rewarded':
        return NativeAdResult.rewarded;
      case 'dismissed':
        return NativeAdResult.dismissed;
      case 'failed':
        return NativeAdResult.failed;
      case 'notReady':
        return NativeAdResult.notReady;
      case 'alreadyShowing':
        return NativeAdResult.alreadyShowing;
      default:
        return NativeAdResult.failed;
    }
  }
}

/// Returns whether any full-screen ad path currently holds a show lock.
bool isAnyFullScreenAdShowing() {
  if (Platform.isIOS && NativeIosAdService.instance.isFullScreenAdShowing) {
    return true;
  }
  return FullScreenAdCoordinator.instance.isFullScreenAdShowing;
}
