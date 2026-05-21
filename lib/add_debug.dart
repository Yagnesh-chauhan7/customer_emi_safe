import 'dart:io';

void main() {
  final dir = Directory('.');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    if (file.path.contains('add_debug.dart')) continue;

    final content = file.readAsStringSync();
    
    // Skip if no catch block
    if (!content.contains('catch (e) {') && !content.contains('catch(e) {') && !content.contains('catch (e, stack) {')) continue;

    final lines = content.split('\n');
    bool modified = false;

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('catch (e) {') || lines[i].contains('catch(e) {') || lines[i].contains('catch (e, stack) {')) {
        // check if next line already has debugPrint or print
        bool hasDebug = false;
        for (int j = i + 1; j < lines.length && j < i + 5; j++) {
          if (lines[j].contains('debugPrint') || lines[j].contains('print(') || lines[j].contains('throw ')) {
            hasDebug = true;
            break;
          }
        }
        if (!hasDebug) {
          // get indentation
          final indentMatch = RegExp(r'^(\s*)').firstMatch(lines[i]);
          final indent = indentMatch?.group(1) ?? '';
          lines.insert(i + 1, '$indent  debugPrint(\'Error: \$e\');');
          modified = true;
        }
      }
    }

    if (modified) {
      file.writeAsStringSync(lines.join('\n'));
      print('Updated: ${file.path}');
    }
  }
}
