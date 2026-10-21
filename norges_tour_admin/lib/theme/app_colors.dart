import 'package:flutter/material.dart';

/// SpikeDunk · Norges Tour — fargetokens for kontrollpanelet.
/// Merkefargene øverst er hentet fra designsystemet i spillerappen.
class AppColors {
  AppColors._();

  // ── Merkefarger (fra spillerappen) ────────────────────────────
  /// Primary text, headlines, icons
  static const Color ink   = Color(0xFF0B1B33);

  /// Primary accent — live indicator, CTAs, scores, coral fills
  static const Color coral      = Color(0xFFF1574A);
  static const Color coralDeep  = Color(0xFFD8412F);

  /// Success / verified / open registration
  static const Color green      = Color(0xFF1F7556);

  /// Divider / border
  static const Color line       = Color(0x1A0B1B33); // 10% ink

  static const LinearGradient heroNavy = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF16243F), Color(0xFF24365E), Color(0xFF0B1B33)],
    stops: [0.0, 0.55, 1.0],
  );

  // ── Admin Specific Theme (Light/Clean) ────────────────────────
  static const Color adminBg = Color(0xFFF4F7FE);
  static const Color adminSidebarBg = Color(0xFF111C44);
  static const Color adminSurface = Color(0xFFFFFFFF);
  /// Dempet flate (nøytrale merker, skillelinjer inne i kort, hover).
  static const Color adminSurfaceElevated = Color(0xFFF1F5F9);
  static const Color adminPrimary = Color(0xFF2563EB);
  /// Merk: brukes for *forsinkede* kamper (+Nmin) – ikke en hover-tilstand.
  static const Color adminPrimaryHover = Color(0xFF3311DB);
  static const Color adminText = Color(0xFF111827);
  static const Color adminTextSecondary = Color(0xFF6B7280);
  static const Color adminSidebarText = Color(0xFFFFFFFF);
  static const Color adminSidebarTextSecondary = Color(0xFFA3AED0);

  // ── Kontrollpanel – utvidede tokens (ryddig design) ───────────
  /// Kantlinje på kort, felt og knapper.
  static const Color adminOutline = Color(0xFFE2E8F0);
  /// Skillelinjer mellom rader inne i kort.
  static const Color adminDivider = Color(0xFFF1F5F9);
  /// Bakgrunn for segmenterte kontroller, fremdriftsspor, tellere.
  static const Color adminMuted = Color(0xFFEEF2F8);
  /// Tabellhode og kortbunn.
  static const Color adminTableHead = Color(0xFFF8FAFC);
  /// Rad-hover.
  static const Color adminRowHover = Color(0xFFF8FAFF);
  /// Mørkere blå (trykk/hover på primærknapp, info-tekst).
  static const Color adminPrimaryDark = Color(0xFF1D4ED8);
  /// Lys blå info-flate og kant.
  static const Color adminInfoBg = Color(0xFFEFF4FF);
  static const Color adminInfoBorder = Color(0xFFBFD3FB);
  /// Nøytral tekst på dempet flate.
  static const Color adminTextMuted = Color(0xFF4B5563);
  static const Color adminTextBody = Color(0xFF374151);
  /// Destruktive handlinger.
  static const Color adminDanger = Color(0xFFDC2626);
  static const Color adminDangerText = Color(0xFFB91C1C);
  static const Color adminDangerSidebar = Color(0xFFF87171);
  static const Color adminDangerSidebarHover = Color(0xFFFCA5A5);
  /// Frist / advarsel (hold alltid etikett ved siden av – lav kontrast).
  static const Color adminWarning = Color(0xFFB45309);
  static const Color adminWarningBg = Color(0xFFFFF4E5);
  /// Ikon i merkeflisen i sidemenyen.
  static const Color adminBrandIcon = Color(0xFF5B8DEF);
  /// Skillelinje i sidemenyen.
  static const Color adminSidebarDivider = Color(0x1AFFFFFF);
}
