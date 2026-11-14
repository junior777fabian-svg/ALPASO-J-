import 'package:alpaso/app/env/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.fromValues', () {
    test('demo sin servidor es válido: la app abre solo con pantallas', () {
      final config = AppConfig.fromValues(env: 'demo');

      expect(config.env, AppEnv.demo);
      expect(config.isDemo, isTrue);
      expect(config.hasServer, isFalse);
    });

    test('acepta el entorno con mayúsculas y espacios', () {
      expect(AppConfig.fromValues(env: ' Demo ').env, AppEnv.demo);
    });

    test('rechaza un entorno desconocido', () {
      expect(
        () => AppConfig.fromValues(env: 'staging'),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('producción exige servidor', () {
      expect(
        () => AppConfig.fromValues(env: 'prod'),
        throwsA(
          isA<AppConfigException>().having(
            (e) => e.message,
            'message',
            contains('obligatorias'),
          ),
        ),
      );
    });

    test('producción con https y llave es válido', () {
      final config = AppConfig.fromValues(
        env: 'prod',
        supabaseUrl: 'https://ejemplo.supabase.co',
        supabasePublishableKey: 'llave',
      );

      expect(config.env, AppEnv.prod);
      expect(config.isDemo, isFalse);
      expect(config.hasServer, isTrue);
    });

    test('dirección y llave van juntas', () {
      expect(
        () => AppConfig.fromValues(
          env: 'demo',
          supabaseUrl: 'https://ejemplo.supabase.co',
        ),
        throwsA(isA<AppConfigException>()),
      );
      expect(
        () => AppConfig.fromValues(env: 'demo', supabasePublishableKey: 'x'),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rechaza http hacia un servidor de internet, también en demo', () {
      for (final env in ['demo', 'prod']) {
        expect(
          () => AppConfig.fromValues(
            env: env,
            supabaseUrl: 'http://ejemplo.supabase.co',
            supabasePublishableKey: 'llave',
          ),
          throwsA(isA<AppConfigException>()),
          reason: 'entorno $env',
        );
      }
    });

    test('demo permite http solo hacia la misma máquina o red', () {
      const locales = [
        'http://localhost:54321',
        'http://127.0.0.1:54321',
        'http://10.0.2.2:54321',
        'http://192.168.1.20:54321',
        'http://172.16.0.5:54321',
      ];
      for (final url in locales) {
        final config = AppConfig.fromValues(
          env: 'demo',
          supabaseUrl: url,
          supabasePublishableKey: 'llave',
        );
        expect(config.hasServer, isTrue, reason: url);
      }
    });

    test('producción nunca permite http, ni siquiera local', () {
      expect(
        () => AppConfig.fromValues(
          env: 'prod',
          supabaseUrl: 'http://localhost:54321',
          supabasePublishableKey: 'llave',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rechaza una dirección que no es una dirección', () {
      expect(
        () => AppConfig.fromValues(
          env: 'demo',
          supabaseUrl: 'no es una url',
          supabasePublishableKey: 'llave',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('172.32.x.x no es red local', () {
      expect(
        () => AppConfig.fromValues(
          env: 'demo',
          supabaseUrl: 'http://172.32.0.5:54321',
          supabasePublishableKey: 'llave',
        ),
        throwsA(isA<AppConfigException>()),
      );
    });
  });
}
