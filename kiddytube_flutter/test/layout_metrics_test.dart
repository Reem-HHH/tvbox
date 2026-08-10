import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/ui/layout_metrics.dart';

void main() {
  test('Google TV-like 960x540 landscape is not one-column phone', () {
    final m = LayoutMetrics(const Size(960, 540));
    expect(m.isTvLike, isTrue);
    // Shows and Mix share TV density so thumbnails stay equally large.
    expect(m.gridColumns(isMix: false), 4);
    expect(m.gridColumns(isMix: true), 4);
    expect(m.libraryColumns(), 4);
  });

  test('phone portrait stays at two columns', () {
    final m = LayoutMetrics(const Size(390, 844));
    expect(m.isTvLike, isFalse);
    expect(m.isTablet, isFalse);
    expect(m.gridColumns(isMix: false), 2);
    expect(m.gridColumns(isMix: true), 2);
  });

  test('iPad landscape uses tablet columns', () {
    final m = LayoutMetrics(const Size(1180, 820));
    expect(m.isTablet, isTrue);
    expect(m.gridColumns(isMix: false), greaterThanOrEqualTo(3));
  });
}
