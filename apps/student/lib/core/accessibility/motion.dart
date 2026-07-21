import 'package:flutter/widgets.dart';

/// Whether decorative motion should be skipped. Read from the platform's
/// reduce-motion setting; never affects the underlying game timing (a
/// countdown bar's real deadline is unaffected — only whether it animates).
bool reducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
