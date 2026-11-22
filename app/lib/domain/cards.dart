// Card and zodiac helpers used on the phone. The sky itself is computed on the server
// (supabase/functions/_shared/sky.ts); these mirror its ids and tables.

const signs = [
  'aries', 'taurus', 'gemini', 'cancer', 'leo', 'virgo',
  'libra', 'scorpio', 'sagittarius', 'capricorn', 'aquarius', 'pisces',
];

const topics = ['love', 'family', 'money', 'health', 'growth'];

/// Major card for each sign (Golden Dawn). Same table as SIGN_CARD on the server.
const signCard = {
  'aries': 'major_04_emperor',
  'taurus': 'major_05_hierophant',
  'gemini': 'major_06_lovers',
  'cancer': 'major_07_chariot',
  'leo': 'major_08_strength',
  'virgo': 'major_09_hermit',
  'libra': 'major_11_justice',
  'scorpio': 'major_13_death',
  'sagittarius': 'major_14_temperance',
  'capricorn': 'major_15_devil',
  'aquarius': 'major_17_star',
  'pisces': 'major_18_moon',
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
