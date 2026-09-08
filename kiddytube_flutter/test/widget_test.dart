import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/catalog_repository.dart';
import 'package:kiddytube/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home shows brand, mode chip, and lock', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final secrets = MemorySecretsStore();
    // Skip first-run PBKDF2 (compute() deadlocks under FakeAsync).
    await secrets.writePin('ab' * 16, 'pre-seeded');
    final repository = CatalogRepository(secrets: secrets);
    await tester.pumpWidget(KiddyTubeApp(repository: repository));
    await tester.pump(); // first frame
    await tester.pump(); // catalog load
    expect(find.byType(Image), findsWidgets); // header logo
    expect(find.text('D·0.1.0'), findsOneWidget); // debug build stamp
    expect(find.text('Shows'), findsAtLeastNWidgets(1));
    expect(find.text('Arabic Shows'), findsOneWidget);
    expect(find.text('Mix'), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
