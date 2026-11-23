// Card and zodiac helpers used on the phone. The sky itself is computed on the server
// (supabase/functions/_shared/sky.ts); these mirror its ids and tables.

const signs = [
  'aries', 'taurus', 'gemini', 'cancer', 'leo', 'virgo',
  'libra', 'scorpio', 'sagittarius', 'capricorn', 'aquarius', 'pisces',
];

const topics = ['love', 'family', 'money', 'health', 'growth'];

/// Major card for each sign (Golden Dawn). Same table as SIGN_CARD on the server.
const signCard = {
  'aries': 'm04',
  'taurus': 'm05',
  'gemini': 'm06',
  'cancer': 'm07',
  'leo': 'm08',
  'virgo': 'm09',
  'libra': 'm11',
  'scorpio': 'm13',
  'sagittarius': 'm14',
  'capricorn': 'm15',
  'aquarius': 'm17',
  'pisces': 'm18',
};

/// Sun sign from a birth date, using the usual date ranges. Cusp days can be off by one;
/// the server corrects `sun_sign` from the exact Sun position after sign-up.
String sunSignFor(DateTime d) {
  const starts = [
    // (month, day, sign starting that day)
    [1, 20, 'aquarius'], [2, 19, 'pisces'], [3, 21, 'aries'], [4, 20, 'taurus'],
    [5, 21, 'gemini'], [6, 21, 'cancer'], [7, 23, 'leo'], [8, 23, 'virgo'],
    [9, 23, 'libra'], [10, 23, 'scorpio'], [11, 22, 'sagittarius'], [12, 22, 'capricorn'],
  ];
  var sign = 'capricorn';
  for (final s in starts) {
    final m = s[0] as int, day = s[1] as int;
    if (d.month > m || (d.month == m && d.day >= day)) sign = s[2] as String;
  }
  return sign;
}

/// 0 = start, 1 = middle, 2 = end of the sign, for the mood one-liner.
int decanPart(int decan) => decan % 3;
String decanSign(int decan) => signs[decan ~/ 3];

/// Days in a month, for the date wheel (Feb 29 only in leap years).
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Roman numeral above the card's arch: majors 0–XXI, pips I–X, court cards none. Ids: m00, c03, p14.
String cardNumeral(String id) {
  final n = int.parse(id.substring(1));
  if (id[0] != 'm' && n > 10) return '';
  if (n == 0) return '0';
  const r = [(10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I')];
  final b = StringBuffer();
  var v = n;
  for (final (val, sym) in r) {
    while (v >= val) {
      b.write(sym);
      v -= val;
    }
  }
  return b.toString();
}
