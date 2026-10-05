import 'dart:io';

void main() {
  final file = File('lib/admin_shell.dart');
  String content = file.readAsStringSync();
  
  // Desktop sidebar item selection
  content = content.replaceAll(
    'itemColor = AppColors.adminPrimary;',
    'itemColor = AppColors.adminSidebarText;' // White text/icon when selected
  );
  content = content.replaceAll(
    'bgColor = AppColors.adminPrimary.withValues(alpha: 0.15);',
    'bgColor = AppColors.adminPrimary;' // Solid blue background for selected item
  );

  // Mobile drawer selection text/icon colors
  // Replace the ternary operator returns for selectedIndex == X
  // ? AppColors.adminPrimary
  content = content.replaceAll(
    '? AppColors.adminPrimary\n                  : AppColors.adminSidebarTextSecondary,',
    '? AppColors.adminSidebarText\n                  : AppColors.adminSidebarTextSecondary,'
  );
  content = content.replaceAll(
    '? AppColors.adminPrimary\n                    : AppColors.adminSidebarText,',
    '? AppColors.adminSidebarText\n                    : AppColors.adminSidebarText,'
  );

  // Mobile drawer selectedTileColor
  content = content.replaceAll(
    'selectedTileColor: AppColors.adminPrimary.withValues(alpha: 0.12),',
    'selectedTileColor: AppColors.adminPrimary,'
  );
  
  // Remove the border that was adminPrimary with 0.3 alpha, since background is now solid.
  // Wait, I can just leave the border as transparent or same color.
  content = content.replaceAll(
    'color: AppColors.adminPrimary.withValues(alpha: 0.3),',
    'color: Colors.transparent,'
  );

  file.writeAsStringSync(content);
  print('Sidebar selection colors updated');
}
