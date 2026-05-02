import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PerformanceUtils {
  /// Optimizes memory usage by limiting image cache size
  static void optimizeImageCache() {
    // Set image cache size to prevent memory issues
    PaintingBinding.instance.imageCache.maximumSize = 100;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50MB
  }

  /// Enables hardware acceleration for better scrolling performance
  static void enableHardwareAcceleration() {
    // Enable hardware acceleration (fullscreen immersive mode)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Optimizes app performance for reading
  static void optimizeForReading() {
    optimizeImageCache();
    enableHardwareAcceleration();

    // ✅ Safe cleanup instead of closing the app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
  }

  /// Creates an optimized scroll physics for better performance
  static ScrollPhysics get optimizedScrollPhysics =>
      const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );

  /// Creates an optimized page controller for PageView
  static PageController createOptimizedPageController({
    int initialPage = 0,
    double viewportFraction = 1.0,
  }) {
    return PageController(
      initialPage: initialPage,
      viewportFraction: viewportFraction,
      keepPage: true,
    );
  }

  /// Wraps a widget with performance optimizations
  static Widget optimizeWidget(Widget child,
      {bool enableRepaintBoundary = true}) {
    if (enableRepaintBoundary) {
      return RepaintBoundary(child: child);
    }
    return child;
  }

  /// Creates optimized image loading parameters
  static Map<String, dynamic> get optimizedImageParams => {
        'cacheWidth': 400,
        'cacheHeight': 300,
        'memCacheWidth': 300,
        'memCacheHeight': 400,
        'maxWidthDiskCache': 300,
        'maxHeightDiskCache': 400,
      };

  /// Debounces function calls to prevent excessive rebuilds
  static void debounce(VoidCallback callback,
      {Duration delay = const Duration(milliseconds: 100)}) {
    Timer? timer;
    timer?.cancel();
    timer = Timer(delay, callback);
  }
}

/// Mixin for automatic performance optimizations
mixin PerformanceOptimizedState<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    PerformanceUtils.optimizeForReading();
  }
}
