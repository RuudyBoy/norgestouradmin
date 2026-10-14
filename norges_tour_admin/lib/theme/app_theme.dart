import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// SpikeDunk · Norges Tour — ThemeData
///
/// Usage in main.dart:
///   MaterialApp(
///     theme: AppTheme.light,
///     darkTheme: AppTheme.dark,
///     themeMode: ThemeMode.system, // or ThemeMode.light to always use light
///   )
class AppTheme {
  AppTheme._();

  // ── Shared shape / radius ─────────────────────────────────────
  static const double radiusCard   = 20.0;
  static const double radiusRow    = 16.0;
  static const double radiusChip   = 999.0; // pill
  static const double radiusInput  = 14.0;
  static const double radiusButton = 14.0;
  static const double radiusBadge  = 8.0;

  // ── Elevation / shadows ───────────────────────────────────────
  static List<BoxShadow> get shadowSm => [
    BoxShadow(color: AppColors.ink.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 4)),
    BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 3,  offset: const Offset(0, 1)),
  ];
  static List<BoxShadow> get shadowLg => [
    BoxShadow(color: AppColors.ink.withValues(alpha: 0.20), blurRadius: 40, offset: const Offset(0, 16)),
    BoxShadow(color: AppColors.ink.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> get shadowCoral => [
    BoxShadow(color: AppColors.coral.withValues(alpha: 0.30), blurRadius: 20, offset: const Offset(0, 8)),
  ];

  // ── Spacing ───────────────────────────────────────────────────
  static const double pageHPad    = 16.0;
  static const double sectionGap  = 24.0;
  static const double rowGap      = 9.0;
  static const double cardPad     = 15.0;

  // ══════════════════════════════════════════════════════════════
  // LIGHT THEME (Sand & Broadcast)
  // ══════════════════════════════════════════════════════════════
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      primaryColor: AppColors.coral,
      colorScheme: ColorScheme.light(
        primary:        AppColors.coral,
        primaryContainer: AppColors.coralDeep,
        secondary:      AppColors.blue,
        secondaryContainer: AppColors.blueBright,
        surface:        AppColors.sand0,
        onPrimary:      Colors.white,
        onSecondary:    Colors.white,
        onSurface:      AppColors.ink,
        outline:        AppColors.line,
      ),

      // typography
      textTheme: _textTheme(AppColors.ink),
      fontFamily: GoogleFonts.schibstedGrotesk().fontFamily,

      // app bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: AppText.dispH2(20).copyWith(color: AppColors.ink),
      ),

      // bottom nav
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.sand0.withValues(alpha: 0.86),
        selectedItemColor: AppColors.coral,
        unselectedItemColor: AppColors.ink3,
        selectedLabelStyle: AppText.uiTab.copyWith(color: AppColors.coral, fontWeight: FontWeight.w800),
        unselectedLabelStyle: AppText.uiTab,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // cards
      cardTheme: CardThemeData(
        color: AppColors.sand0,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
        margin: EdgeInsets.zero,
      ),

      // chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.sand2,
        selectedColor: AppColors.ink,
        labelStyle: AppText.uiTab.copyWith(color: AppColors.ink2),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      ),

      // elevated button (CTA)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.coral,
          foregroundColor: AppColors.ink,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
          textStyle: AppText.uiCta,
          elevation: 0,
        ),
      ),

      // outlined button (ghost)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
          side: BorderSide(color: AppColors.line),
          textStyle: AppText.uiCta.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
        ),
      ),

      // text fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.sand0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.coral, width: 1.5),
        ),
        hintStyle: AppText.uiBody.copyWith(color: AppColors.ink3),
        labelStyle: AppText.monoSm.copyWith(color: AppColors.ink3, fontSize: 11),
      ),

      // divider
      dividerTheme: const DividerThemeData(
        color: AppColors.line, thickness: 1, space: 0,
      ),
    );
    return base;
  }

  // ══════════════════════════════════════════════════════════════
  // DARK THEME (Night mode)
  // ══════════════════════════════════════════════════════════════
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      primaryColor: AppColors.coral,
      colorScheme: ColorScheme.dark(
        primary:        AppColors.coral,
        secondary:      AppColors.blueBright,
        surface:        AppColors.nightSurface0,
        onPrimary:      Colors.white,
        onSurface:      AppColors.nightInk,
        outline:        Colors.white.withValues(alpha: 0.10),
      ),
      textTheme: _textTheme(AppColors.nightInk),
      fontFamily: GoogleFonts.schibstedGrotesk().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.nightInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: AppText.dispH2(20).copyWith(color: AppColors.nightInk),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.nightSurface0.withValues(alpha: 0.88),
        selectedItemColor: AppColors.coral,
        unselectedItemColor: AppColors.nightInk3,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.nightSurface0,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.coral,
          foregroundColor: AppColors.nightSurface0,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusButton)),
          textStyle: AppText.uiCta,
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.nightSurface0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: AppColors.coral, width: 1.5),
        ),
        hintStyle: AppText.uiBody.copyWith(color: AppColors.nightInk3),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.10), thickness: 1, space: 0,
      ),
    );
    return base;
  }

  // ══════════════════════════════════════════════════════════════
  // ADMIN THEME (Dark Blue & Orange)
  // ══════════════════════════════════════════════════════════════
  static ThemeData get admin {
    // Kontrollpanel: kald hvit arbeidsflate, navy sidemeny, blå primærfarge.
    // Radier/høyder følger «Admin – ryddigere design»: kort 12, kontroller 10, høyde 44.
    const double rAdminCard = 12.0;
    const double rControl = 10.0;
    final ui = GoogleFonts.schibstedGrotesk;
    final btnText = ui(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0);
    final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(rControl));

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent, // Background will be handled by builder
      primaryColor: AppColors.adminPrimary,
      colorScheme: const ColorScheme.light(
        primary:        AppColors.adminPrimary,
        secondary:      AppColors.adminPrimaryHover,
        surface:        AppColors.adminSurface,
        surfaceTint:    Colors.transparent,
        onPrimary:      Colors.white,
        onSurface:      AppColors.adminText,
        onSurfaceVariant: AppColors.adminTextSecondary,
        outline:        AppColors.adminOutline,
        outlineVariant: AppColors.adminDivider,
        error:          AppColors.adminDanger,
      ),
      textTheme: _adminTextTheme(),
      fontFamily: GoogleFonts.schibstedGrotesk().fontFamily,
      iconTheme: const IconThemeData(color: AppColors.adminTextMuted, size: 20),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.adminSurface,
        foregroundColor: AppColors.adminText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        shape: const Border(bottom: BorderSide(color: AppColors.adminOutline)),
        titleTextStyle: ui(fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.adminText),
        iconTheme: const IconThemeData(color: AppColors.adminText),
        actionsIconTheme: const IconThemeData(color: AppColors.adminTextMuted),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.adminSurface,
        selectedItemColor: AppColors.adminPrimary,
        unselectedItemColor: AppColors.adminTextSecondary,
        selectedLabelStyle: ui(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: ui(fontWeight: FontWeight.w500, fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.adminSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0x14111827),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rAdminCard),
            side: const BorderSide(color: AppColors.adminOutline, width: 1)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.adminPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.adminMuted,
          disabledForegroundColor: AppColors.adminTextSecondary,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: controlShape,
          textStyle: btnText,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.adminPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: controlShape,
          textStyle: btnText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.adminText,
          backgroundColor: AppColors.adminSurface,
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: controlShape,
          side: const BorderSide(color: AppColors.adminOutline),
          textStyle: btnText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.adminPrimary,
          shape: controlShape,
          textStyle: btnText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.adminTextSecondary,
          shape: controlShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.adminPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 2,
        shape: controlShape,
        extendedTextStyle: btnText,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.adminSurface,
        selectedColor: AppColors.adminSidebarBg,
        disabledColor: AppColors.adminMuted,
        labelStyle: ui(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.adminTextMuted),
        secondaryLabelStyle: ui(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
        side: const BorderSide(color: AppColors.adminOutline),
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.adminSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rAdminCard)),
        titleTextStyle: ui(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.adminText),
        contentTextStyle: ui(fontWeight: FontWeight.w400, fontSize: 14, color: AppColors.adminTextBody, height: 1.45),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.adminSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x24111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rAdminCard),
          side: const BorderSide(color: AppColors.adminOutline),
        ),
        textStyle: ui(fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.adminText),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.adminSurface),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.adminSidebarBg,
        contentTextStyle: ui(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rControl)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.adminPrimary,
        unselectedLabelColor: AppColors.adminTextSecondary,
        indicatorColor: AppColors.adminPrimary,
        dividerColor: AppColors.adminOutline,
        labelStyle: ui(fontWeight: FontWeight.w600, fontSize: 15),
        unselectedLabelStyle: ui(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.adminTextSecondary,
        titleTextStyle: ui(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.adminText),
        subtitleTextStyle: ui(fontWeight: FontWeight.w400, fontSize: 13, color: AppColors.adminTextSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rControl)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(AppColors.adminTableHead),
        headingTextStyle: ui(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.adminTextSecondary),
        dataTextStyle: ui(fontWeight: FontWeight.w400, fontSize: 14, color: AppColors.adminText),
        dividerThickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.adminPrimary,
        linearTrackColor: AppColors.adminMuted,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
        iconColor: AppColors.adminTextSecondary,
        collapsedIconColor: AppColors.adminTextSecondary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.adminSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rControl),
          borderSide: const BorderSide(color: AppColors.adminOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rControl),
          borderSide: const BorderSide(color: AppColors.adminOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rControl),
          borderSide: const BorderSide(color: AppColors.adminPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rControl),
          borderSide: const BorderSide(color: AppColors.adminDanger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rControl),
          borderSide: const BorderSide(color: AppColors.adminDanger, width: 1.5),
        ),
        hintStyle: ui(fontWeight: FontWeight.w400, fontSize: 14, color: AppColors.adminTextSecondary),
        labelStyle: ui(fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.adminTextSecondary),
        floatingLabelStyle: ui(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.adminPrimary),
        prefixIconColor: AppColors.adminTextSecondary,
        suffixIconColor: AppColors.adminTextSecondary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.adminOutline, thickness: 1, space: 0,
      ),
    );
    return base;
  }

  // ── Admin-tekst: Schibsted Grotesk gjennomgående (ingen Saira i kontrollpanelet) ──
  static TextTheme _adminTextTheme() {
    final ui = GoogleFonts.schibstedGrotesk;
    const c = AppColors.adminText;
    return TextTheme(
      displayLarge:  ui(fontWeight: FontWeight.w700, fontSize: 40, color: c, letterSpacing: -0.4),
      displayMedium: ui(fontWeight: FontWeight.w700, fontSize: 34, color: c, letterSpacing: -0.3),
      displaySmall:  ui(fontWeight: FontWeight.w700, fontSize: 30, color: c, letterSpacing: -0.3),
      headlineLarge: ui(fontWeight: FontWeight.w700, fontSize: 26, color: c),
      headlineMedium:ui(fontWeight: FontWeight.w700, fontSize: 22, color: c),
      headlineSmall: ui(fontWeight: FontWeight.w700, fontSize: 18, color: c),
      titleLarge:    ui(fontWeight: FontWeight.w700, fontSize: 18, color: c),
      titleMedium:   ui(fontWeight: FontWeight.w600, fontSize: 16, color: c),
      titleSmall:    ui(fontWeight: FontWeight.w600, fontSize: 14, color: c),
      bodyLarge:     ui(fontWeight: FontWeight.w400, fontSize: 16, color: c, height: 1.45),
      bodyMedium:    ui(fontWeight: FontWeight.w400, fontSize: 14, color: c, height: 1.45),
      bodySmall:     ui(fontWeight: FontWeight.w400, fontSize: 12, color: AppColors.adminTextSecondary, height: 1.3),
      labelLarge:    ui(fontWeight: FontWeight.w600, fontSize: 14, color: c),
      labelMedium:   GoogleFonts.ibmPlexMono(fontWeight: FontWeight.w500, fontSize: 12, color: c),
      labelSmall:    GoogleFonts.ibmPlexMono(fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 1.3, color: AppColors.adminTextSecondary),
    );
  }

  // ── shared text theme ─────────────────────────────────────────
  static TextTheme _textTheme(Color color) => TextTheme(
    displayLarge:  AppText.dispScore(48).copyWith(color: color),
    displayMedium: AppText.dispH1(34).copyWith(color: color),
    displaySmall:  AppText.dispH1(26).copyWith(color: color),
    headlineLarge: AppText.dispH2(24).copyWith(color: color),
    headlineMedium:AppText.dispH2(20).copyWith(color: color),
    headlineSmall: AppText.dispKicker(15).copyWith(color: color),
    titleLarge:    AppText.uiTitle.copyWith(fontSize: 18, color: color),
    titleMedium:   AppText.uiTitle.copyWith(fontSize: 16, color: color),
    titleSmall:    AppText.uiTitle.copyWith(fontSize: 14, color: color),
    bodyLarge:     AppText.uiBody.copyWith(fontSize: 16, color: color),
    bodyMedium:    AppText.uiBody.copyWith(color: color),
    bodySmall:     AppText.uiCaption.copyWith(color: color.withValues(alpha: 0.7)),
    labelLarge:    AppText.uiCta.copyWith(color: color),
    labelMedium:   AppText.monoMd.copyWith(color: color),
    labelSmall:    AppText.monoSm.copyWith(color: color),
  );
}
