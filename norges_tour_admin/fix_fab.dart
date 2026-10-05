import 'dart:io';

void main() {
  final mainFile = File('lib/main.dart');
  String mainContent = mainFile.readAsStringSync();
  
  // Find the FAB section and replace the colors
  mainContent = mainContent.replaceAll(
    '          backgroundColor: AppColors.adminBg,\n          foregroundColor: AppColors.adminText,',
    '          backgroundColor: AppColors.adminPrimary,\n          foregroundColor: Colors.white,'
  );

  // While we are here, we should fix the AppBar if it also has foregroundColor: AppColors.adminText and we want it to remain AppColors.adminBg.
  // Actually, AppBar should have AppColors.adminBg (so it blends with the scaffold). 
  // Text should be AppColors.adminText (dark). That is correct.

  mainFile.writeAsStringSync(mainContent);
  print('Fixed FAB in main.dart');
}
