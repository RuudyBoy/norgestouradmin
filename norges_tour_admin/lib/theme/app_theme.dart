import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// SpikeDunk · Norges Tour — ThemeData for kontrollpanelet.
///
/// Brukes i main.dart: `MaterialApp(theme: AppTheme.admin, ...)`.
class AppTheme {
  AppTheme._();

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
}

