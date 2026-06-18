import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    if (file.path.contains('app_theme.dart') || file.path.contains('app_colors.dart') || file.path.contains('app_text_styles.dart')) continue;
    
    var content = file.readAsStringSync();
    
    content = content.replaceAll('AppColors.adminText87', 'AppColors.adminTextSecondary');
    content = content.replaceAll('AppColors.adminText60', 'AppColors.adminTextSecondary');
    
    file.writeAsStringSync(content);
  }
}
