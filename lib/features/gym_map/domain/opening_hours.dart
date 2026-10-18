/// Horário de funcionamento lido da etiqueta `opening_hours` do
/// OpenStreetMap.
///
/// Entende os formatos mais comuns (`24/7`, `Mo-Fr 06:00-22:00; Sa 08:00-14:00;
/// Su off`, vários intervalos por dia, horário que passa da meia-noite). O que
/// não entende devolve `null` em [tryParse]: o app mostra "horário não
/// informado", nunca um chute.
class OpeningHours {
  const OpeningHours._(this._rangesByWeekday, {this.alwaysOpen = false});

  /// Intervalos de cada dia (1 = segunda ... 7 = domingo) em minutos desde
  /// 0h; o fim passa de 1440 quando o horário vai além da meia-noite.
  final Map<int, List<(int, int)>> _rangesByWeekday;
  final bool alwaysOpen;

  static const Map<String, int> _days = <String, int>{
    'mo': DateTime.monday,
    'tu': DateTime.tuesday,
    'we': DateTime.wednesday,
    'th': DateTime.thursday,
    'fr': DateTime.friday,
    'sa': DateTime.saturday,
    'su': DateTime.sunday,
  };

  static final RegExp _timeRange = RegExp(
    r'^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$',
  );

  static OpeningHours? tryParse(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    if (text == '24/7') {
      return const OpeningHours._(<int, List<(int, int)>>{}, alwaysOpen: true);
    }
    final byDay = <int, List<(int, int)>>{};
    for (final rawRule in text.split(RegExp(r';|\|\|'))) {
      final rule = rawRule.trim();
      if (rule.isEmpty) {
        continue;
      }
      final parsed = _parseRule(rule);
      if (parsed == null) {
        return null;
      }
      // Regras seguintes valem por cima das anteriores nos dias que citam.
      for (final day in parsed.$1) {
        byDay[day] = parsed.$2;
      }
    }
    if (byDay.isEmpty) {
      return null;
    }
    return OpeningHours._(byDay);
  }

  /// (dias, intervalos) de uma regra; `null` se não entender.
  static (Set<int>, List<(int, int)>)? _parseRule(String rule) {
    final parts = rule.split(RegExp(r'\s+'));
    var days = <int>{for (var d = 1; d <= 7; d++) d};
    var timePart = rule;
    final first = parts.first.toLowerCase();
    if (RegExp(r'^[a-z]').hasMatch(first) && !_isOff(first)) {
      final selected = _parseDays(first);
      if (selected == null) {
        return null;
      }
      // Regra só de feriados (PH): não muda os dias da semana.
      if (selected.isEmpty) {
        return (<int>{}, const <(int, int)>[]);
      }
      days = selected;
      timePart = parts.skip(1).join(' ');
    }
    final times = timePart.trim().toLowerCase();
    if (_isOff(times)) {
      return (days, const <(int, int)>[]);
    }
    final ranges = <(int, int)>[];
    for (final piece in times.split(',')) {
      final match = _timeRange.firstMatch(piece.trim());
      if (match == null) {
        return null;
      }
      final start = int.parse(match[1]!) * 60 + int.parse(match[2]!);
      var end = int.parse(match[3]!) * 60 + int.parse(match[4]!);
      if (start >= 1440 || end > 1440 || int.parse(match[2]!) > 59) {
        return null;
      }
      if (end <= start) {
        end += 1440;
      }
      ranges.add((start, end));
    }
    return (days, ranges);
  }

  static bool _isOff(String value) => value == 'off' || value == 'closed';

  /// Dias de `Mo-Fr,Sa`; `PH`/`SH` são ignorados. `null` se não entender.
  static Set<int>? _parseDays(String selector) {
    final days = <int>{};
    for (final token in selector.split(',')) {
      final part = token.trim();
      if (part == 'ph' || part == 'sh') {
        continue;
      }
      final bounds = part.split('-');
      if (bounds.length > 2) {
        return null;
      }
      final from = _days[bounds.first];
      final to = _days[bounds.last];
      if (from == null || to == null) {
        return null;
      }
      var day = from;
      while (true) {
        days.add(day);
        if (day == to) {
          break;
        }
        day = day == 7 ? 1 : day + 1;
      }
    }
    return days;
  }

  List<(int, int)> rangesOn(int weekday) =>
      _rangesByWeekday[weekday] ?? const <(int, int)>[];

  /// Minuto (desde 0h de [time]) em que fecha o intervalo aberto agora, ou
  /// `null` se está fechada. Pode passar de 1440.
  int? closingMinuteAt(DateTime time) {
    if (alwaysOpen) {
      return null;
    }
    final minute = time.hour * 60 + time.minute;
    for (final (start, end) in rangesOn(time.weekday)) {
      if (minute >= start && minute < end) {
        return end;
      }
    }
    final yesterday = time.weekday == 1 ? 7 : time.weekday - 1;
    for (final (_, end) in rangesOn(yesterday)) {
      if (end > 1440 && minute < end - 1440) {
        return end - 1440;
      }
    }
    return null;
  }

  bool isOpenAt(DateTime time) => alwaysOpen || closingMinuteAt(time) != null;

  /// Próxima abertura a partir de [time]: (dias à frente, minuto do dia), ou
  /// `null` se não abre na próxima semana.
  (int, int)? nextOpeningAfter(DateTime time) {
    final minute = time.hour * 60 + time.minute;
    for (var ahead = 0; ahead <= 7; ahead++) {
      final weekday = (time.weekday - 1 + ahead) % 7 + 1;
      for (final (start, _) in rangesOn(weekday)) {
        if (ahead > 0 || start > minute) {
          return (ahead, start);
        }
      }
    }
    return null;
  }
}
