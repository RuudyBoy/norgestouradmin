import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    if (file.path.contains('app_theme.dart') || file.path.contains('app_colors.dart') || file.path.contains('app_text_styles.dart')) continue;
    
    var content = file.readAsStringSync();
    
    // Quick fix for AppBar
    content = content.replaceAll('backgroundColor: Colors.blue[900],', '');
    content = content.replaceAll('foregroundColor: Colors.white,', '');
    
    content = content.replaceAll('Colors.blue[900]', 'AppColors.ink');
    content = content.replaceAll('Colors.blue[800]', 'AppColors.blue');
    content = content.replaceAll('Colors.blue[700]', 'AppColors.ink2');
    content = content.replaceAll('Colors.blue[50]', 'AppColors.sand2');
    content = content.replaceAll('Colors.blue[100]', 'AppColors.sand2');
    content = content.replaceAll('Colors.blue.shade50', 'AppColors.sand2');
    content = content.replaceAll('Colors.blue.shade100', 'AppColors.sand2');
    content = content.replaceAll('Colors.blue.shade200', 'AppColors.sand2');
    content = content.replaceAll('Colors.blue.shade700', 'AppColors.ink2');
    content = content.replaceAll('Colors.blue.shade800', 'AppColors.ink');
    content = content.replaceAll('Colors.blue.shade900', 'AppColors.ink');
    content = content.replaceAll('Colors.blue', 'AppColors.blue');
    
    content = content.replaceAll('Colors.green[800]', 'AppColors.green');
    content = content.replaceAll('Colors.green.shade800', 'AppColors.green');
    content = content.replaceAll('Colors.green[100]', 'AppColors.green.withOpacity(0.2)');
    content = content.replaceAll('Colors.green.shade100', 'AppColors.green.withOpacity(0.2)');
    content = content.replaceAll('Colors.green.shade50', 'AppColors.green.withOpacity(0.1)');
    content = content.replaceAll('Colors.green.shade300', 'AppColors.green');
    content = content.replaceAll('Colors.green', 'AppColors.green');
    
    content = content.replaceAll('Colors.red[800]', 'AppColors.coralDeep');
    content = content.replaceAll('Colors.red[700]', 'AppColors.coralDeep');
    content = content.replaceAll('Colors.red[100]', 'AppColors.coral.withOpacity(0.2)');
    content = content.replaceAll('Colors.red.shade100', 'AppColors.coral.withOpacity(0.2)');
    content = content.replaceAll('Colors.red.shade400', 'AppColors.coral');
    content = content.replaceAll('Colors.red.shade800', 'AppColors.coralDeep');
    content = content.replaceAll('Colors.red', 'AppColors.coral');
    
    content = content.replaceAll('Colors.orange[800]', 'AppColors.blueBright');
    content = content.replaceAll('Colors.orange', 'AppColors.coral');
    
    content = content.replaceAll('Colors.purple[800]', 'AppColors.blueBright');
    content = content.replaceAll('Colors.purple.shade100', 'AppColors.blueBright.withOpacity(0.2)');
    content = content.replaceAll('Colors.purple.shade800', 'AppColors.blueBright');
    content = content.replaceAll('Colors.amber.shade700', 'AppColors.blue');
    content = content.replaceAll('Colors.teal.shade700', 'AppColors.green');
    content = content.replaceAll('Colors.deepOrange.shade700', 'AppColors.coral');
    
    if (content.contains('AppColors.') && !content.contains('app_colors.dart')) {
      // Find the last import
      final importIdx = content.lastIndexOf(RegExp(r"import '.*';"));
      if (importIdx != -1) {
        final endOfImport = content.indexOf('\n', importIdx);
        content = content.substring(0, endOfImport + 1) + "import 'theme/app_colors.dart';\n" + content.substring(endOfImport + 1);
      } else {
        content = "import 'theme/app_colors.dart';\n" + content;
      }
    }
    
    file.writeAsStringSync(content);
  }
}
