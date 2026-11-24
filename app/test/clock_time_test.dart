import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tarot_app/ui/widgets/common.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('Portuguese clock times use the Brazilian 6h / 14h20 style', () {
    expect(clockTime(DateTime(2026, 1, 1, 6), 'pt'), '6h');
    expect(clockTime(DateTime(2026, 1, 1, 14, 5), 'pt-BR'), '14h05');
  });
  test('English keeps 24-hour HH:mm', () {
    expect(clockTime(DateTime(2026, 1, 1, 6), 'en'), '06:00');
  });
}
