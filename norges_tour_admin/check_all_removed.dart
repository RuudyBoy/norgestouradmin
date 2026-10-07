import 'dart:io';
void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  void checkRegex(String name, RegExp regex, String replacement) {
    var match = regex.firstMatch(text);
    if (match != null) {
      var removed = match.group(0)!;
      int oRem = removed.split('{').length - 1;
      int cRem = removed.split('}').length - 1;
      int oRep = replacement.split('{').length - 1;
      int cRep = replacement.split('}').length - 1;
      print("\$name -> removed: \${oRem - cRem}, replacement: \${oRep - cRep}");
    } else {
      print("\$name not found");
    }
  }

  checkRegex("autoSched", RegExp(r"Future<void> _autoScheduleForCategory\([^]*?\}\s*\}", multiLine: true), "{}");
  checkRegex("pubBatch", RegExp(r"Future<void> _publishCategory\(\).*?void _deleteCategory", dotAll: true), "{}");
  checkRegex("inlineBtn", RegExp(r"Widget _buildPublishButtonInline\(\).*?Widget _buildCategoryMenu", dotAll: true), "{}");
}
