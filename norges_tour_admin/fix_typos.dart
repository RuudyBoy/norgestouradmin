import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    if (file.path.contains('app_theme.dart') || file.path.contains('app_colors.dart') || file.path.contains('app_text_styles.dart')) continue;
    
    var content = file.readAsStringSync();
    
    content = content.replaceAll('AppAppColors.blue', 'AppColors.blue');
    content = content.replaceAll('AppAppColors.green', 'AppColors.green');
    content = content.replaceAll('AppAppColors.coral', 'AppColors.coral');
    content = content.replaceAll('AppAppColors.ink', 'AppColors.ink');
    
    file.writeAsStringSync(content);
  }
}
