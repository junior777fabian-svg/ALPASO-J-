import 'package:alpaso/app/theme/app_colors.dart';
import 'package:alpaso/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

/// Cinta "DEMO" en la esquina superior, visible sobre cualquier pantalla.
///
/// Mientras algún servicio funcione en modo demo, nadie debe poder confundir
/// lo que ve con una reserva o un cobro real.
class DemoBanner extends StatelessWidget {
  const DemoBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Banner(
      message: AppLocalizations.of(context).demoBannerLabel,
      location: BannerLocation.topEnd,
      color: AppColors.demo,
      child: child,
    );
  }
}
