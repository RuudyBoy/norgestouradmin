import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// SpikeDunk · Norges Tour — tekststiler som brukes utenom [AdminText].
///
///   • Saira — stor overskrift i «Pågår nå»-kortet
///   • Schibsted Grotesk — brødtekst og knappetekst
class AppText {
  AppText._();

  /// Page title / large heading — 30 pt italic black
  static TextStyle dispH1([double size = 30]) => GoogleFonts.saira(
    fontWeight: FontWeight.w900, fontStyle: FontStyle.italic,
    fontSize: size, color: AppColors.ink, letterSpacing: 0.2, height: 0.95,
  );

  /// Primary body — 14 pt medium
  static TextStyle uiBody = GoogleFonts.schibstedGrotesk(
    fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.ink, height: 1.45,
  );

  /// CTA / button label — 15 pt extrabold
  static TextStyle uiCta = GoogleFonts.schibstedGrotesk(
    fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white, letterSpacing: 0.1,
  );
}
