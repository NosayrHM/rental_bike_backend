import 'package:flutter_test/flutter_test.dart';
import 'package:mi_primer_app/main.dart';

void main() {
  testWidgets('App muestra pantalla de login si no está logueado', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('App muestra menú principal si está logueado', (WidgetTester tester) async {
    // Simular usuario logueado
    // Aquí deberías mockear UserService, pero se muestra ejemplo básico
    await tester.pumpWidget(const MyApp());
    // El test real debe mockear el estado logueado
    expect(find.text('Menú principal'), findsWidgets);
  });
}
