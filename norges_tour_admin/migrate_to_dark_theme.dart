import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    if (file.path.contains('app_theme.dart') || file.path.contains('app_colors.dart') || file.path.contains('app_text_styles.dart')) continue;
    
    var content = file.readAsStringSync();
    
    content = content.replaceAll('AppColors.ink', 'AppColors.adminText');
    content = content.replaceAll('AppColors.adminText2', 'AppColors.adminTextSecondary'); // In case ink2 -> adminText2
    content = content.replaceAll('AppColors.adminText3', 'AppColors.adminTextSecondary'); 
    
    // Wait, ink2 would become adminText2, let's just do them explicitly
    // Since AppColors.ink is a substring of AppColors.ink2, replacing ink first creates adminText2.
    // So 'AppColors.ink2' became 'AppColors.adminText2'
    
    content = content.replaceAll('AppColors.sand0', 'AppColors.adminSurface');
    content = content.replaceAll('AppColors.sand2', 'AppColors.adminSurfaceElevated');
    content = content.replaceAll('AppColors.coralDeep', 'AppColors.adminOrangeHover');
    content = content.replaceAll('AppColors.coral', 'AppColors.adminOrange');
    content = content.replaceAll('AppColors.blueBright', 'AppColors.adminOrangeHover');
    content = content.replaceAll('AppColors.blue', 'AppColors.adminOrange');
    
    // Some texts had explicit color: Colors.black. We want White on dark.
    content = content.replaceAll('Colors.black', 'AppColors.adminText');
    content = content.replaceAll('Colors.white', 'AppColors.adminText'); // just use adminText
    content = content.replaceAll('Colors.grey', 'AppColors.adminTextSecondary');
    
    file.writeAsStringSync(content);
  }
}
