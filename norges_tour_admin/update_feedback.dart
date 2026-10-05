import 'dart:io';

void main() {
  // 1. Update app_colors.dart
  final colorsFile = File('lib/theme/app_colors.dart');
  String colorsContent = colorsFile.readAsStringSync();
  colorsContent = colorsContent.replaceAll(
    'static const Color adminPrimary = Color(0xFF4318FF);',
    'static const Color adminPrimary = Color(0xFF2563EB);' // standard blue
  );
  colorsContent = colorsContent.replaceAll(
    'static const Color adminText = Color(0xFF2B3674);',
    'static const Color adminText = Color(0xFF111827);' // dark near black
  );
  colorsContent = colorsContent.replaceAll(
    'static const Color adminTextSecondary = Color(0xFFA3AED0);',
    'static const Color adminTextSecondary = Color(0xFF6B7280);' // plain grey
  );
  colorsFile.writeAsStringSync(colorsContent);

  // 2. Update main.dart (AppBar & FAB)
  final mainFile = File('lib/main.dart');
  String mainContent = mainFile.readAsStringSync();
  mainContent = mainContent.replaceAll(
    'backgroundColor: Colors.blue[800],',
    'backgroundColor: AppColors.adminBg,',
  );
  mainContent = mainContent.replaceAll(
    'foregroundColor: AppColors.adminText,\n        automaticallyImplyLeading:',
    'foregroundColor: AppColors.adminText,\n        elevation: 0,\n        automaticallyImplyLeading:',
  );
  // Re-replace the second one (FAB) because the first one hit the AppBar.
  mainContent = mainContent.replaceAll(
    'icon: const Icon(Icons.add),\n        backgroundColor: AppColors.adminBg,\n        foregroundColor: AppColors.adminText,',
    'icon: const Icon(Icons.add),\n        backgroundColor: AppColors.adminPrimary,\n        foregroundColor: Colors.white,'
  );
  // Just in case it was Colors.blue[800] for FAB still:
  mainContent = mainContent.replaceAll(
    'icon: const Icon(Icons.add),\n        backgroundColor: Colors.blue[800],\n        foregroundColor: AppColors.adminText,',
    'icon: const Icon(Icons.add),\n        backgroundColor: AppColors.adminPrimary,\n        foregroundColor: Colors.white,'
  );
  mainFile.writeAsStringSync(mainContent);

  // 3. Update admin_dashboard_overview.dart (Stats plain colors)
  final dashboardFile = File('lib/admin_dashboard_overview.dart');
  String dashboardContent = dashboardFile.readAsStringSync();
  
  dashboardContent = dashboardContent.replaceAll(
    'color: Colors.green,',
    'color: AppColors.adminText,'
  );
  dashboardContent = dashboardContent.replaceAll(
    'color: AppColors.adminPrimary,',
    'color: AppColors.adminText,' // For the 'Frist' value in stat column
  );
  dashboardContent = dashboardContent.replaceAll(
    'color: isOpen ? Colors.green : Colors.red,',
    'color: AppColors.adminText,'
  );
  
  // Also, button in the card: "Administrer"
  // It has a button. Let's make sure its text is white.
  // Wait, elevated button text is white by default in AppTheme.
  // Let's check how the 'Administrer' button is rendered.
  dashboardFile.writeAsStringSync(dashboardContent);

  print('Updates completed');
}
