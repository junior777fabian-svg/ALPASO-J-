import 'package:material_ui/material_ui.dart';

import 'admin_repository.dart';
import 'sections/accounts_section.dart';
import 'sections/bookings_section.dart';
import 'sections/lodgings_section.dart';
import 'sections/money_section.dart';
import 'sections/support_section.dart';
import 'ui.dart';

const _oro = Color(0xFFC9A74B);

class AdminApp extends StatelessWidget {
  const AdminApp({required this.repository, this.demo = true, super.key});

  final AdminRepository repository;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Al Paso · Administración',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _oro,
          brightness: Brightness.dark,
        ),
      ),
      builder: (context, child) => demo
          ? Banner(
              message: 'DEMO',
              location: BannerLocation.topEnd,
              color: Colors.deepOrange.shade700,
              child: child!,
            )
          : child!,
      home: _Gate(repository: repository),
    );
  }
}

/// Solo entra una cuenta administradora: lo decide el servidor.
class _Gate extends StatefulWidget {
  const _Gate({required this.repository});

  final AdminRepository repository;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _admin = false;

  @override
  Widget build(BuildContext context) {
    return _admin
        ? _Home(
            repository: widget.repository,
            onSignOut: () async {
              await widget.repository.signOut();
              setState(() => _admin = false);
            },
          )
        : _SignIn(
            repository: widget.repository,
            onAdmin: () => setState(() => _admin = true),
          );
  }
}

class _SignIn extends StatefulWidget {
  const _SignIn({required this.repository, required this.onAdmin});

  final AdminRepository repository;
  final VoidCallback onAdmin;

  @override
  State<_SignIn> createState() => _SignInState();
}

class _SignInState extends State<_SignIn> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.signIn(_email.text, _password.text);
      // El servidor confirma el rol; si no es admin, se cierra la sesión.
      await widget.repository.overview();
      widget.onAdmin();
    } on Object catch (e) {
      if (widget.repository.isSignedIn) await widget.repository.signOut();
      setState(() => _error = failureText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Al Paso · Administración',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('admin-email'),
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                TextField(
                  key: const Key('admin-password'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  key: const Key('admin-submit'),
                  onPressed: _busy ? null : _submit,
                  child: const Text('Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.repository, required this.onSignOut});

  final AdminRepository repository;
  final VoidCallback onSignOut;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _index = 0;

  static const _titles = [
    'Resumen',
    'Hostales',
    'Cuentas',
    'Reservas',
    'Liquidaciones',
    'Soporte',
    'Configuración',
  ];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.storefront_outlined,
    Icons.people_outline,
    Icons.confirmation_number_outlined,
    Icons.payments_outlined,
    Icons.support_agent,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    final body = switch (_index) {
      0 => _Overview(repository: repo),
      1 => LodgingsSection(repository: repo),
      2 => AccountsSection(repository: repo),
      3 => BookingsSection(repository: repo),
      4 => MoneySection(repository: repo),
      5 => SupportSection(repository: repo),
      _ => _Settings(repository: repo),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          TextButton(onPressed: widget.onSignOut, child: const Text('Salir')),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (var i = 0; i < _titles.length; i++)
                NavigationRailDestination(
                  icon: Icon(_icons[i]),
                  label: Text(_titles[i]),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(16), child: body),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.repository});

  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    const labels = {
      'lodgings_pending_review': 'Hostales por revisar',
      'lodgings_published': 'Hostales publicados',
      'bookings_today': 'Reservas de hoy',
      'support_open': 'Incidencias abiertas',
      'complaints_open': 'Reclamos por responder',
      'payouts_pending': 'Liquidaciones por transferir',
    };
    return Loader<Json>(
      load: repository.overview,
      builder: (context, data, reload) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final e in labels.entries)
            SizedBox(
              width: 220,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data[e.key] ?? 0}',
                        key: Key('overview-${e.key}'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(e.value),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A6. Configuración pública, de solo lectura. Cambiarla se hace con una
/// migración, para que quede en el historial del repositorio.
class _Settings extends StatelessWidget {
  const _Settings({required this.repository});

  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    return Loader<Json>(
      load: repository.publicSettings,
      builder: (context, data, reload) => ListView(
        children: [
          const Text(
            'Los valores se cambian con una migración en supabase/migrations, para que quede registro.',
          ),
          for (final e in data.entries)
            ListTile(title: Text(e.key), trailing: Text('${e.value}')),
        ],
      ),
    );
  }
}
