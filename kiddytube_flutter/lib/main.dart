import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'catalog/catalog_repository.dart';
import 'ui/app_orientations.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bound decoded-image cache for Android TV RAM / Mix scrolling.
  PaintingBinding.instance.imageCache.maximumSize = 120;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 << 20;
  // Portrait + landscape; no upside-down (matches iOS Info.plist).
  await SystemChrome.setPreferredOrientations(kBrowseOrientations);
  final repository = CatalogRepository();
  runApp(KiddyTubeApp(repository: repository));
}

class KiddyTubeApp extends StatelessWidget {
  const KiddyTubeApp({super.key, required this.repository});

  final CatalogRepository repository;

  /// YouTube-inspired red.
  static const _ytRed = Color(0xFFFF0000);
  static const _ytBg = Color(0xFF0F0F0F);
  static const _ytSurface = Color(0xFF212121);

  @override
  Widget build(BuildContext context) {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: _ytRed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: _ytRed,
      onPrimary: Colors.white,
      surface: _ytBg,
      onSurface: Colors.white,
      onSurfaceVariant: const Color(0xFFAAAAAA),
      surfaceContainerHighest: _ytSurface,
      surfaceContainerLow: const Color(0xFF181818),
      outline: const Color(0xFF3F3F3F),
    );

    final lightScheme = ColorScheme.fromSeed(
      seedColor: _ytRed,
      brightness: Brightness.light,
    ).copyWith(
      primary: _ytRed,
    );

    return MaterialApp(
      title: 'KiddyTube',
      debugShowCheckedModeBanner: false,
      // Consistent YouTube-like chrome on TV and phones.
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: _ytBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: _ytBg,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: HomeScreen(repository: repository),
    );
  }
}
