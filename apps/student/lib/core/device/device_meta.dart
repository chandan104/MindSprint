import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

/// Per-session device metadata (spec: recorded so benchmarks can be
/// segmented by hardware/input — impossible to reconstruct later).
Map<String, Object?> gatherDeviceMeta(BuildContext context, String appVersion) {
  final media = MediaQuery.maybeOf(context);
  return {
    'platform': Platform.operatingSystem,
    'os_version': Platform.operatingSystemVersion,
    'app_version': appVersion,
    'screen_w': media?.size.width.round(),
    'screen_h': media?.size.height.round(),
    'pixel_ratio': media?.devicePixelRatio,
    // Touch is the classroom norm; desktop builds refine this later.
    'input_method': (Platform.isAndroid || Platform.isIOS) ? 'touch' : 'pointer',
  };
}
