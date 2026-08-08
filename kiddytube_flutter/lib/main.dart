import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'catalog/catalog_repository.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Soften Android TV overscan / keep landscape friendly on tablets.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final repository = CatalogRepository();
  runApp(KiddyTubeApp(repository: repository));
}

class KiddyTubeApp extends StatelessWidget {
  const KiddyTubeApp({super.key, required this.repository});

  final CatalogRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KiddyTube',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(repository: repository),
    );
  }
}
