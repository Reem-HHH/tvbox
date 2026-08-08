import 'package:flutter_test/flutter_test.dart';
import 'package:kiddytube/catalog/catalog_repository.dart';
import 'package:kiddytube/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home shows brand and mode chip', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = CatalogRepository(secrets: MemorySecretsStore());
    await tester.pumpWidget(KiddyTubeApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('KiddyTube'), findsOneWidget);
    expect(find.text('Shows'), findsOneWidget);
  });
}
