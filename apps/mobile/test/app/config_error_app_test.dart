import 'package:alpaso/app/config_error_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra el motivo por el que la app no puede iniciar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ConfigErrorApp(message: 'APP_ENV debe ser "demo" o "prod".'),
    );

    expect(find.text('La app no puede iniciar'), findsOneWidget);
    expect(find.text('APP_ENV debe ser "demo" o "prod".'), findsOneWidget);
  });
}
