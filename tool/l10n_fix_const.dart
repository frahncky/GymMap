// Remove `const` que ficaram inválidos depois de trocar textos fixos por
// traduções. Roda `dart analyze`, procura erros de constante e apaga o
// `const` mais próximo antes do ponto do erro; repete até não sobrar nenhum.
//
//   dart run tool/l10n_fix_const.dart
import 'dart:io';

const _codes = <String>{
  'invalid_constant',
  'const_with_non_constant_argument',
  'non_constant_list_element',
  'non_constant_map_value',
  'const_initialized_with_non_constant_value',
  'const_eval_method_invocation',
  'const_with_non_const',
};

void main() {
  for (var round = 1; round <= 30; round++) {
    final result = Process.runSync('dart', [
      'analyze',
      '--format=machine',
      'lib',
    ], runInShell: true);
    final errors = <String, List<(int, int)>>{};
    for (final line in '${result.stdout}\n${result.stderr}'.split('\n')) {
      final fields = line.split('|');
      if (fields.length < 8 || fields[0] != 'ERROR') continue;
      if (!_codes.contains(fields[2].toLowerCase())) continue;
      errors.putIfAbsent(fields[3], () => []).add((
        int.parse(fields[4]),
        int.parse(fields[5]),
      ));
    }
    if (errors.isEmpty) {
      stdout.writeln('Sem erros de const (rodada $round).');
      return;
    }
    var removed = 0;
    errors.forEach((path, positions) {
      final file = File(path);
      final eol = file.readAsStringSync().contains('\r\n') ? '\r\n' : '\n';
      final lines = file.readAsLinesSync();
      // Do fim para o começo, para as posições anteriores continuarem válidas.
      positions.sort((a, b) => b.$1 != a.$1 ? b.$1 - a.$1 : b.$2 - a.$2);
      final done = <int>{};
      for (final (lineNo, column) in positions) {
        var l = lineNo - 1;
        var limit = column - 1;
        while (l >= 0) {
          final text = lines[l];
          final upTo = limit.clamp(0, text.length);
          final index = text
              .substring(0, upTo)
              .lastIndexOf(RegExp(r'\bconst '));
          if (index >= 0) {
            if (done.add(l * 100000 + index)) {
              // `const x = ...` vira `final x = ...`; nos demais casos o
              // `const` só é removido.
              final isDeclaration = RegExp(r'^\s*const \w+ =').hasMatch(text);
              lines[l] = text.replaceRange(
                index,
                index + 6,
                isDeclaration ? 'final ' : '',
              );
              removed++;
            }
            break;
          }
          l--;
          if (l >= 0) limit = lines[l].length;
        }
      }
      file.writeAsStringSync('${lines.join(eol)}$eol');
    });
    stdout.writeln('Rodada $round: $removed const removidos.');
    if (removed == 0) return;
  }
}
