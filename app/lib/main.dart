import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/config.dart';
import 'app/router.dart';
import 'data/local_store.dart';
import 'l10n/app_localizations.dart';
import 'services/analytics.dart';
import 'services/notifications.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';
import 'ui/widgets/ad_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // draw under status and gesture bars

  if (AppConfig.hasBackend) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  }
  final prefs = await SharedPreferences.getInstance();
  final store = LocalStore(prefs);

  // First launch: language from the phone locale (1a), EN / PT / ES, Portuguese otherwise.
  if (store.draft.firstName.isEmpty && store.profile == null) {
    final phone = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    await store.setDraft(store.draft.copyWith(language: const ['en', 'pt', 'es'].contains(phone) ? phone : 'pt'));
  }

  final notifications = NotificationService();
  final tzName = await notifications.init();
  final analytics = Analytics();
  await analytics.init();
  // Ads start after the first frame so they never delay startup on budget phones.
  WidgetsBinding.instance.addPostFrameCallback((_) => Ads.init());

  runApp(ProviderScope(
    overrides: [
      storeProvider.overrideWithValue(store),
      notificationsProvider.overrideWithValue(notifications),
      analyticsProvider.overrideWithValue(analytics),
      phoneTzProvider.overrideWithValue(tzName),
    ],
    child: const TarotApp(),
  ));
}

class TarotApp extends ConsumerWidget {
  const TarotApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return MaterialApp.router(
      onGenerateTitle: (_) => 'App name', // placeholder until the app name is decided
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
