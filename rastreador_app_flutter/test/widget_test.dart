import 'package:flutter_test/flutter_test.dart';
import 'package:rastreador_app_flutter/src/app/app.dart';
import 'package:rastreador_app_flutter/src/app/app_dependencies.dart';

void main() {
  testWidgets('shows login screen for unauthenticated users', (tester) async {
    final dependencies = AppDependencies.testing();
    await dependencies.initialize();

    await tester.pumpWidget(MyApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    expect(find.text('Tracker Carsat'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
