# Copilot Instructions for mi_primer_app

## Arquitectura y Estructura General
- Proyecto Flutter/Dart con estructura estándar, pero contiene dos apps: `mi_primer_app` y `mi_app` (cada una con su propio `pubspec.yaml`, `lib/`, etc.).
- Código fuente principal en `lib/` de cada app. Ejemplo: `lib/screen/` contiene pantallas como `login_screen.dart`, `register_screen.dart`, `splash_screen.dart`.
- Recursos estáticos en `assets/` (imágenes, etc.).
- Soporte multiplataforma: carpetas `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`.

## Flujos de Desarrollo
- **Compilación y ejecución:** Usar comandos estándar de Flutter (`flutter run`, `flutter build <platform>`). Ejecutar desde la raíz de la app deseada.
- **Pruebas:** Los tests están en `test/` (por ejemplo, `widget_test.dart`). Ejecutar con `flutter test`.
- **Gestión de dependencias:** Modificar `pubspec.yaml` y luego correr `flutter pub get`.

## Convenciones y Patrones
- **Pantallas:** En `lib/screen/`, cada archivo representa una pantalla. Ejemplo: `login_screen.dart` define la pantalla de login.
- **Widgets reutilizables:** Ubicados en `lib/widgets/`.
- **Modelos y proveedores:** Usar `lib/models/` y `lib/providers/` para lógica de negocio y estado.
- **Servicios y utilidades:** Lógica de acceso a datos o helpers en `lib/services/` y `lib/utils/`.
- **Navegación:** Usualmente gestionada en el archivo principal (`main.dart`) o en un widget raíz.

## Integraciones y Dependencias
- No se detectan integraciones externas personalizadas fuera de las dependencias estándar de Flutter.
- Los recursos y assets deben declararse en el `pubspec.yaml` correspondiente.

## Ejemplo de flujo típico
1. Crear una nueva pantalla en `lib/screen/` y su widget asociado en `lib/widgets/` si es necesario.
2. Registrar la pantalla en el sistema de rutas en `main.dart`.
3. Añadir dependencias en `pubspec.yaml` y ejecutar `flutter pub get`.
4. Probar cambios con `flutter run` o `flutter test`.

## Archivos clave
- `lib/main.dart`: punto de entrada de la app.
- `pubspec.yaml`: dependencias y configuración de assets.
- `lib/screen/`, `lib/widgets/`, `lib/models/`, `lib/providers/`, `lib/services/`, `lib/utils/`: organización modular del código.

---

Si algún patrón, flujo o integración no está claro, por favor indícalo para mejorar estas instrucciones.