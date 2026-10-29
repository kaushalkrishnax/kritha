import 'package:material_ui/material_ui.dart';

import '../../../core/theme.dart';

/// The Kritha avatar mark.
class KrithaAvatar extends StatelessWidget {
  const KrithaAvatar({super.key, this.size = 32, this.showRing = true});

  final double size;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(showRing ? 1.5 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: showRing
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  KrithaColors.accentCyan,
                  KrithaColors.accentBlue,
                  KrithaColors.accentSky,
                ],
              )
            : null,
        boxShadow: showRing
            ? [
                BoxShadow(
                  color: Color(0x333B82F6),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/kritha_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
