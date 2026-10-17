// Ferramenta de extração de textos para tradução.
//
//   dart run tool/l10n_add.dart textos.tsv
//
// Cada linha do TSV tem 5 colunas separadas por TAB:
//   chave  português  inglês  arquivo  trecho=>substituição[ || outro=>sub]
//
// - Placeholders `{nome}` viram parâmetros `String`; `{nome:int}` na coluna em
//   português declara um parâmetro inteiro.
// - A 5ª coluna é opcional: cada par `trecho=>substituição` troca o texto
//   exato no arquivo (`\n` representa quebra de linha). Um trecho que não for
//   encontrado é reportado e o processo termina com erro.
// - Linhas iniciadas por `#` são ignoradas.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final rows =
      File(args.single)
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty && !line.startsWith('#'))
          .map((line) => line.split('\t'))
          .toList();

  final pt = _read('lib/l10n/app_pt.arb');
  final en = _read('lib/l10n/app_en.arb');
  final placeholder = RegExp(r'\{(\w+)(?::(\w+))?\}');
  final sources = <String, String>{};
  var failures = 0;

  for (final row in rows) {
    if (row.length < 3) {
      stderr.writeln('Linha inválida: ${row.join(' | ')}');
      failures++;
      continue;
    }
    final key = row[0], ptText = row[1], enText = row[2];
    final types = <String, String>{
      for (final match in placeholder.allMatches(ptText))
        match.group(1)!: match.group(2) ?? 'String',
    };
    pt[key] = ptText.replaceAllMapped(placeholder, (m) => '{${m.group(1)}}');
    en[key] = enText;
    if (types.isNotEmpty) {
      pt['@$key'] = <String, Object>{
        'placeholders': <String, Object>{
          for (final entry in types.entries)
            entry.key: <String, String>{'type': entry.value},
        },
      };
    }

    if (row.length < 5 || row[4].trim().isEmpty) continue;
    final path = row[3];
    var source = sources[path] ??= File(path).readAsStringSync();
    final crlf = source.contains('\r\n');
    for (final pair in row[4].split(' || ')) {
      final arrow = pair.indexOf('=>');
      final parts =
          arrow < 0
              ? <String>[pair]
              : <String>[pair.substring(0, arrow), pair.substring(arrow + 2)];
      if (parts.length != 2) {
        stderr.writeln('[$key] par inválido: $pair');
        failures++;
        continue;
      }
      String unescape(String value) =>
          value.replaceAll(r'\n', crlf ? '\r\n' : '\n');
      final from = unescape(parts[0]);
      final to = unescape(parts[1]);
      if (!source.contains(from)) {
        stderr.writeln('[$key] trecho não encontrado em $path: ${parts[0]}');
        failures++;
        continue;
      }
      source = source.replaceAll(from, to);
    }
    sources[path] = source;
  }

  sources.forEach((path, source) => File(path).writeAsStringSync(source));
  _write('lib/l10n/app_pt.arb', pt);
  _write('lib/l10n/app_en.arb', en);
  stdout.writeln('${rows.length} textos processados, $failures falhas.');
  if (failures > 0) exitCode = 1;
}

Map<String, Object?> _read(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

void _write(String path, Map<String, Object?> data) {
  const encoder = JsonEncoder.withIndent('  ');
  File(path).writeAsStringSync('${encoder.convert(data)}\n');
}
