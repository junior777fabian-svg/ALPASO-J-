/// Entorno en el que corre la app.
enum AppEnv { demo, prod }

/// La configuración recibida no permite arrancar la app.
class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}

/// Configuración que la app recibe al compilarse.
///
/// Los valores llegan con `--dart-define-from-file=config/<entorno>.json`.
/// Aquí no viaja ningún secreto: la llave publicable de Supabase está pensada
/// para ir dentro de la app, y lo que protege los datos son las reglas del
/// servidor.
class AppConfig {
  const AppConfig({
    required this.env,
    this.supabaseUrl = '',
    this.supabasePublishableKey = '',
  });

  /// Lee los valores fijados al compilar.
  factory AppConfig.fromEnvironment() => AppConfig.fromValues(
    env: const String.fromEnvironment('APP_ENV', defaultValue: 'demo'),
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
  );

  /// Valida los valores y construye la configuración.
  ///
  /// Lanza [AppConfigException] si algo no cuadra. Es preferible que la app
  /// no abra a que abra apuntando a un servidor equivocado.
  factory AppConfig.fromValues({
    required String env,
    String supabaseUrl = '',
    String supabasePublishableKey = '',
  }) {
    final parsedEnv = switch (env.trim().toLowerCase()) {
      'demo' => AppEnv.demo,
      'prod' => AppEnv.prod,
      _ => throw AppConfigException(
        'APP_ENV debe ser "demo" o "prod". Llegó "$env".',
      ),
    };

    final url = supabaseUrl.trim();
    final key = supabasePublishableKey.trim();

    if (url.isEmpty != key.isEmpty) {
      throw const AppConfigException(
        'SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY van juntas: falta una.',
      );
    }

    if (parsedEnv == AppEnv.prod && url.isEmpty) {
      throw const AppConfigException(
        'En producción SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY son '
        'obligatorias.',
      );
    }

    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.host.isEmpty) {
        throw AppConfigException(
          'SUPABASE_URL no es una dirección válida: "$url".',
        );
      }

      // Sin https la sesión viajaría sin cifrar. La única excepción es un
      // servidor de pruebas en la misma máquina o red, y solo en demo.
      final isLocalHttp =
          uri.scheme == 'http' &&
          parsedEnv == AppEnv.demo &&
          _isLocalHost(uri.host);
      if (uri.scheme != 'https' && !isLocalHttp) {
        throw AppConfigException('SUPABASE_URL debe usar https: "$url".');
      }
    }

    return AppConfig(
      env: parsedEnv,
      supabaseUrl: url,
      supabasePublishableKey: key,
    );
  }

  final AppEnv env;
  final String supabaseUrl;
  final String supabasePublishableKey;

  bool get isDemo => env == AppEnv.demo;

  /// Falso mientras la app corre sin servidor (solo pantallas).
  bool get hasServer => supabaseUrl.isNotEmpty;

  static bool _isLocalHost(String host) {
    if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
      return true;
    }
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.contains(null)) return false;
    final a = parts[0]!;
    final b = parts[1]!;
    return a == 10 ||
        (a == 192 && b == 168) ||
        (a == 172 && b >= 16 && b <= 31);
  }
}
