import 'dart:io';

void main() {
  final file = File('lib/admin_shell.dart');
  String content = file.readAsStringSync();

  // Desktop sidebar background
  content = content.replaceAll(
    'width: 260,\n      color: AppColors.adminSurface,', 
    'width: 260,\n      color: AppColors.adminSidebarBg,'
  );

  // Mobile drawer background
  content = content.replaceAll(
    'backgroundColor: AppColors.adminSurface,\n      child: ListView(', 
    'backgroundColor: AppColors.adminSidebarBg,\n      child: ListView('
  );
  
  // Drawer header decoration
  content = content.replaceAll(
    'color: AppColors.adminSurfaceElevated,', 
    'color: Colors.transparent,'
  );

  // Sidebar text colors
  // Since admin_shell.dart is essentially JUST the sidebar, we can safely replace AppColors.adminText with AppColors.adminSidebarText inside this file.
  content = content.replaceAll('AppColors.adminText,', 'AppColors.adminSidebarText,');
  content = content.replaceAll('AppColors.adminTextSecondary', 'AppColors.adminSidebarTextSecondary');
  
  // AppColors.adminText in ternary operators without commas
  content = content.replaceAll('AppColors.adminText :', 'AppColors.adminSidebarText :');
  content = content.replaceAll('AppColors.adminText\n', 'AppColors.adminSidebarText\n');
  content = content.replaceAll('AppColors.adminText)', 'AppColors.adminSidebarText)');

  // Hover backgrounds for sidebar items
  content = content.replaceAll(
    '? AppColors.adminSurfaceElevated', 
    '? AppColors.adminSidebarText.withValues(alpha: 0.1)'
  );

  file.writeAsStringSync(content);
  print('Updated admin_shell.dart');
}
