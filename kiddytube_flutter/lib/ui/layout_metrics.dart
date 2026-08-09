import 'package:flutter/material.dart';

/// Shared breakpoints for phone / tablet / Android TV-like layouts.
///
/// Google TV at 1080p often reports ~960×540 logical px (shortestSide < 600),
/// so we treat wide landscape as TV even when shortestSide looks "phone-sized".
class LayoutMetrics {
  LayoutMetrics(this.size);

  factory LayoutMetrics.of(BuildContext context) =>
      LayoutMetrics(MediaQuery.sizeOf(context));

  final Size size;

  double get width => size.width;
  double get height => size.height;
  double get shortest => size.shortestSide;
  bool get isLandscape => width > height;

  /// iPad / large phones in landscape with enough width.
  bool get isTablet => shortest >= 600;

  /// Living-room / Leanback-style: wide landscape even if shortestSide < 600.
  bool get isTvLike =>
      (isLandscape && width >= 900) || shortest >= 900 || width >= 1200;

  double get maxContentWidth {
    if (isTvLike) return 1680;
    if (isTablet) return 1100;
    return double.infinity;
  }

  double get pagePadding => isTablet || isTvLike ? 28 : 16;

  double get logoSize => isTablet || isTvLike ? 56 : 44;

  double get titleSize => isTablet || isTvLike ? 34 : 28;

  double get sectionTitleSize => isTablet || isTvLike ? 18 : 15;

  double get continueHeight {
    if (isTvLike) return isLandscape ? 168 : 150;
    if (isTablet) return isLandscape ? 168 : 150;
    return 128;
  }

  double get continueWidth {
    if (isTvLike) return isLandscape ? 260 : 220;
    if (isTablet) return isLandscape ? 240 : 210;
    return 180;
  }

  /// Kid-friendly tiles: large enough to tap/click, not one per row on TV.
  int gridColumns({required bool isMix}) {
    if (isTvLike) {
      return isMix ? (isLandscape ? 5 : 4) : (isLandscape ? 4 : 3);
    }
    if (isTablet) {
      return isMix ? (isLandscape ? 4 : 3) : (isLandscape ? 4 : 3);
    }
    // Phone
    return isMix ? (isLandscape ? 3 : 2) : (isLandscape ? 3 : 2);
  }

  int libraryColumns() {
    if (isTvLike) return isLandscape ? 4 : 3;
    if (isTablet) return isLandscape ? 4 : 3;
    return isLandscape ? 3 : 2;
  }
}
