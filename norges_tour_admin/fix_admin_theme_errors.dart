import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    if (file.path.contains('app_theme.dart') || file.path.contains('app_colors.dart') || file.path.contains('app_text_styles.dart')) continue;
    
    var content = file.readAsStringSync();
    
    // Fix Colors.grey[...] that were converted to AppColors.adminTextSecondary[...]
    content = content.replaceAll(RegExp(r'AppColors\.adminTextSecondary\[\d+\]\s*\!?'), 'AppColors.adminTextSecondary');
    content = content.replaceAll(RegExp(r'AppColors\.adminTextSecondary\.shade\d+'), 'AppColors.adminTextSecondary');
    content = content.replaceAll(RegExp(r'AppColors\.adminText\[\d+\]\s*\!?'), 'AppColors.adminText');
    content = content.replaceAll(RegExp(r'AppColors\.adminSurface\[\d+\]\s*\!?'), 'AppColors.adminSurface');
    content = content.replaceAll(RegExp(r'AppColors\.adminBg\[\d+\]\s*\!?'), 'AppColors.adminBg');
    content = content.replaceAll(RegExp(r'AppColors\.adminOrange\[\d+\]\s*\!?'), 'AppColors.adminOrange');
    content = content.replaceAll(RegExp(r'AppColors\.adminOrangeHover\[\d+\]\s*\!?'), 'AppColors.adminOrangeHover');
    
    content = content.replaceAll(RegExp(r'AppColors\.green\[\d+\]\s*\!?'), 'AppColors.green');
    content = content.replaceAll(RegExp(r'AppColors\.blue\[\d+\]\s*\!?'), 'AppColors.blue');
    
    // Fix undefined getters like adminText70 or adminTextSecondary.shade300
    content = content.replaceAll('AppColors.adminText70', 'AppColors.adminTextSecondary');
    content = content.replaceAll('AppColors.adminTextSecondary.shade300', 'AppColors.adminTextSecondary');
    content = content.replaceAll('AppColors.adminTextSecondary.shade100', 'AppColors.adminTextSecondary');
    content = content.replaceAll('AppColors.adminTextSecondary.shade200', 'AppColors.adminTextSecondary');
    
    file.writeAsStringSync(content);
  }
}
