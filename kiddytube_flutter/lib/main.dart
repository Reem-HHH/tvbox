import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'catalog/catalog_repository.dart';
import 'ui/app_orientations.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait + landscape; no upside-down (matches iOS Info.plist).
  await SystemChrome.setPreferredOrientations(kBrowseOrientations);
  final repository = CatalogRepository();
  runApp(KiddyTubeApp(repository: repository));
}

class KiddyTubeApp extends StatelessWidget {
  const KiddyTubeApp({super.key, required this.repository});

  final CatalogRepository repository;

  static const _seed = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KiddyTube',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(repository: repository),
    );
  }
}
