import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    if (file.path.contains('app_theme.dart') || file.path.contains('app_colors.dart') || file.path.contains('app_text_styles.dart')) continue;
    
    var content = file.readAsStringSync();
    
    // Replace AppColors.blueGrey with AppColors.ink3
    content = content.replaceAll('AppColors.blueGrey', 'AppColors.ink3');
    
    // Fix AppColors.sand2[200] -> AppColors.sand2
    // My previous script might have left something like AppColors.sand2[200]
    content = content.replaceAll(RegExp(r'AppColors\.sand2\[\d+\]'), 'AppColors.sand2');
    content = content.replaceAll(RegExp(r'AppColors\.blue\[\d+\]'), 'AppColors.blue');
    content = content.replaceAll(RegExp(r'AppColors\.ink\[\d+\]'), 'AppColors.ink');
    content = content.replaceAll(RegExp(r'AppColors\.green\[\d+\]'), 'AppColors.green');
    content = content.replaceAll(RegExp(r'AppColors\.coral\[\d+\]'), 'AppColors.coral');
    content = content.replaceAll(RegExp(r'AppColors\.coralDeep\[\d+\]'), 'AppColors.coralDeep');
    
    file.writeAsStringSync(content);
  }
}
