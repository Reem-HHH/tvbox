import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/catalog_repository.dart';
import 'package:kiddytube/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home shows brand, mode chip, and lock', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = CatalogRepository(secrets: MemorySecretsStore());
    await tester.pumpWidget(KiddyTubeApp(repository: repository));
    await tester.pump(); // first frame
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Image), findsWidgets); // header logo
    expect(find.text('Shows'), findsAtLeastNWidgets(1));
    expect(find.text('Mix'), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
