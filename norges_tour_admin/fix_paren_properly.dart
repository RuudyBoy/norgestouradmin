import 'dart:io';

void main() {
  final file = File('lib/tournament_control_page.dart');
  var text = file.readAsStringSync();
  
  // Revert the paren removal if it exists
  text = text.replaceFirst("                  ),\n\n              ),", "                  ),\n                ),\n              ),");
  
  // Now carefully fix the end of _buildScheduleCard
  // I will just use string replacement on the exact end block.
  String badEnd = """              ),
            ],
          ),
        ),
      ),
    );
  }

  //  UI shell """;
  
  String goodEnd = """              ),
            ],
          ),
      ),
    );
  }

  //  UI shell """;

  if (text.contains(badEnd)) {
    text = text.replaceFirst(badEnd, goodEnd);
    print("Fixed badEnd.");
  }

  file.writeAsStringSync(text);
}
