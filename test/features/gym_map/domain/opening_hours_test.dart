import 'package:flutter_test/flutter_test.dart';
import 'package:gymmap/features/gym_map/domain/opening_hours.dart';

void main() {
  // 19/10/2026 é uma segunda-feira.
  DateTime at(int weekday, int hour, [int minute = 0]) =>
      DateTime(2026, 10, 18 + weekday, hour, minute);

  test('weekdays and Saturday, closed on Sunday', () {
    final hours = OpeningHours.tryParse('Mo-Fr 06:00-22:00; Sa 08:00-14:00')!;

    expect(hours.isOpenAt(at(DateTime.monday, 6)), isTrue);
    expect(hours.isOpenAt(at(DateTime.monday, 22)), isFalse);
    expect(hours.isOpenAt(at(DateTime.saturday, 13, 59)), isTrue);
    expect(hours.isOpenAt(at(DateTime.saturday, 14)), isFalse);
    expect(hours.isOpenAt(at(DateTime.sunday, 10)), isFalse);
    expect(hours.closingMinuteAt(at(DateTime.monday, 10)), 22 * 60);
    expect(hours.nextOpeningAfter(at(DateTime.saturday, 15)), (2, 6 * 60));
  });

  test('several ranges a day and later rules override earlier ones', () {
    final hours =
        OpeningHours.tryParse('Mo-Su 06:00-12:00,14:00-22:00; Su off')!;

    expect(hours.isOpenAt(at(DateTime.tuesday, 13)), isFalse);
    expect(hours.isOpenAt(at(DateTime.tuesday, 15)), isTrue);
    expect(hours.rangesOn(DateTime.sunday), isEmpty);
    expect(hours.nextOpeningAfter(at(DateTime.tuesday, 13)), (0, 14 * 60));
  });

  test('ranges past midnight belong to the next morning too', () {
    final hours = OpeningHours.tryParse('Fr 18:00-02:00')!;

    expect(hours.isOpenAt(at(DateTime.friday, 23)), isTrue);
    expect(hours.isOpenAt(at(DateTime.saturday, 1)), isTrue);
    expect(hours.isOpenAt(at(DateTime.saturday, 3)), isFalse);
  });

  test('24/7, time-only and holiday rules', () {
    expect(OpeningHours.tryParse('24/7')!.isOpenAt(at(1, 3)), isTrue);
    final daily = OpeningHours.tryParse('05:00-23:00')!;
    expect(daily.isOpenAt(at(DateTime.sunday, 5)), isTrue);
    final withHoliday = OpeningHours.tryParse('Mo-Fr 06:00-22:00; PH off')!;
    expect(withHoliday.isOpenAt(at(DateTime.friday, 7)), isTrue);
  });

  test('anything it does not understand is unknown, not guessed', () {
    for (final raw in <String?>[
      null,
      '',
      'Mo-Fr 06:00+',
      'sunrise-sunset',
      'Mo-Fr 6h às 22h',
      'Jan-Mar Mo 08:00-12:00',
    ]) {
      expect(OpeningHours.tryParse(raw), isNull, reason: '$raw');
    }
  });
}
