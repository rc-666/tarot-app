import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/config.dart';
import '../domain/cards.dart';
import '../domain/models.dart';
import 'local_store.dart';

enum SaveError { emailUsed, network, other }

enum SignInError { wrongPassword, network, other }

class AccountException implements Exception {
  AccountException(this.kind);
  final Object kind; // SaveError or SignInError
}

/// Sign-up, sign-in, password reset, profile and readings.
/// [SupabaseAccount] for real builds, [DemoAccount] for the demo build (account kept on the phone).
abstract class AccountApi {
  String? get userId;
  String? get email;
  @override
  Future<Profile> signUpWithDraft({required String email, required String password, required ProfileDraft draft, required String phoneTz});
  Future<Profile> signIn(String email, String password);
  Future<void> sendReset(String email);
  Future<void> setNewPassword(String password);
  Future<Profile?> fetchProfile();
  Future<Profile> updateProfile(Profile p, Map<String, dynamic> changes);
  Future<void> saveReading(ReadingRecord r);
  Future<void> deleteAccount();
}

Profile _profileFromDraft(String id, ProfileDraft draft, String phoneTz) => Profile(
      id: id,
      firstName: draft.firstName.trim(),
      birthDate: draft.birthDate!,
      birthTime: draft.birthTime,
      birthPlace: draft.birthPlace?.label,
      birthLat: draft.birthPlace?.lat,
      birthLon: draft.birthPlace?.lon,
      birthTz: draft.birthPlace?.tz,
      tz: phoneTz,
      sunSign: sunSignFor(draft.birthDate!),
      focusTopics: draft.focusTopics,
      language: draft.language,
    );

class SupabaseAccount implements AccountApi {
  SupabaseAccount(this._sb, this._store);
  final SupabaseClient _sb;
  final LocalStore _store;

  User? get user => _sb.auth.currentUser;
  @override
  String? get userId => user?.id;
  @override
  String? get email => user?.email;

  /// 3a: creates the account and the profile from the onboarding draft. No email verification.
  Future<Profile> signUpWithDraft({
    required String email,
    required String password,
    required ProfileDraft draft,
    required String phoneTz,
  }) async {
    try {
      final res = await _sb.auth.signUp(email: email, password: password, emailRedirectTo: AppConfig.authRedirect);
      final u = res.user;
      if (u == null) throw AccountException(SaveError.other);
      // Supabase returns a user with no identities when the email is already registered.
      if (u.identities != null && u.identities!.isEmpty) throw AccountException(SaveError.emailUsed);
      final p = _profileFromDraft(u.id, draft, phoneTz);
      await _sb.from('profiles').insert({...p.toRow(), 'is_adult': true});
      await _store.setProfile(p);
      final first = _store.firstReading;
      if (first != null) {
        await _sb.from('readings').upsert({'user_id': u.id, 'day': first.day, 'topic': first.topic, 'rating': first.rating});
      }
      await _store.clearDraft();
      return p;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('already registered') || e.statusCode == '422') {
        throw AccountException(SaveError.emailUsed);
      }
      throw AccountException(_isNetwork(e) ? SaveError.network : SaveError.other);
    } on AccountException {
      rethrow;
    } catch (e) {
      throw AccountException(_isNetwork(e) ? SaveError.network : SaveError.other);
    }
  }

  /// 3i: returning user on a new phone.
  @override
  Future<Profile> signIn(String email, String password) async {
    try {
      await _sb.auth.signInWithPassword(email: email, password: password);
      final p = await fetchProfile();
      if (p == null) throw AccountException(SignInError.other);
      return p;
    } on AuthException catch (e) {
      if (e.statusCode == '400' || e.message.toLowerCase().contains('invalid')) {
        throw AccountException(SignInError.wrongPassword);
      }
      throw AccountException(_isNetwork(e) ? SignInError.network : SignInError.other);
    } on AccountException {
      rethrow;
    } catch (e) {
      throw AccountException(_isNetwork(e) ? SignInError.network : SignInError.other);
    }
  }

  /// 3j: sends the reset email; the link opens the app (deep link) and fires passwordRecovery.
  @override
  Future<void> sendReset(String email) => _sb.auth.resetPasswordForEmail(email, redirectTo: AppConfig.authRedirect);

  /// 3l
  @override
  Future<void> setNewPassword(String password) => _sb.auth.updateUser(UserAttributes(password: password));

  @override
  Future<Profile?> fetchProfile() async {
    final u = user;
    if (u == null) return _store.profile;
    try {
      final r = await _sb.from('profiles').select().eq('id', u.id).maybeSingle();
      if (r == null) return null;
      final p = Profile.fromRow(r);
      await _store.setProfile(p);
      return p;
    } catch (_) {
      return _store.profile;
    }
  }

  @override
  Future<Profile> updateProfile(Profile p, Map<String, dynamic> changes) async {
    final r = await _sb.from('profiles').update(changes).eq('id', p.id).select().single();
    final np = Profile.fromRow(r);
    await _store.setProfile(np);
    return np;
  }

  @override
  Future<void> saveReading(ReadingRecord r) async {
    await _store.setReading(r);
    final u = user;
    if (u == null) return;
    try {
      await _sb.from('readings').upsert({'user_id': u.id, 'day': r.day, 'topic': r.topic, 'rating': r.rating});
    } catch (_) {
      // Rating is best effort; the local record is the one the UI shows.
    }
  }

  /// 6b: server function deletes the auth user; data goes by cascade.
  @override
  Future<void> deleteAccount() async {
    final res = await _sb.functions.invoke('delete-account', method: HttpMethod.post);
    if (res.status != 200) throw AccountException(SaveError.other);
    await _sb.auth.signOut();
    await _store.clearPersonal();
  }

  static bool _isNetwork(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('socket') || s.contains('network') || s.contains('failed host lookup') || s.contains('timed out');
  }
}

/// Demo build: the "account" is the profile saved on this phone. Any email/password signs up.
/// Sign-in works only if this phone already has a demo profile (otherwise it shows the
/// wrong-password state, so that screen can be seen too). Reset emails are not sent.
class DemoAccount implements AccountApi {
  DemoAccount(this._store);
  final LocalStore _store;
  static const _id = '00000000-0000-0000-0000-00000000d3d0';

  @override
  String? get userId => _store.profile?.id;
  @override
  String? get email => _store.profile == null ? null : 'demo@example.com';

  @override
  Future<Profile> signUpWithDraft({required String email, required String password, required ProfileDraft draft, required String phoneTz}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600)); // shows the "Saving…" state
    final p = _profileFromDraft(_id, draft, phoneTz);
    await _store.setProfile(p);
    await _store.clearDraft();
    return p;
  }

  @override
  Future<Profile> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final p = _store.profile;
    if (p == null) throw AccountException(SignInError.wrongPassword);
    return p;
  }

  @override
  Future<void> sendReset(String email) async {}
  @override
  Future<void> setNewPassword(String password) async {}
  @override
  Future<Profile?> fetchProfile() async => _store.profile;

  @override
  Future<Profile> updateProfile(Profile p, Map<String, dynamic> changes) async {
    final np = Profile.fromRow({...p.toRow(), ...changes});
    await _store.setProfile(np);
    return np;
  }

  @override
  Future<void> saveReading(ReadingRecord r) => _store.setReading(r);

  @override
  Future<void> deleteAccount() => _store.clearPersonal();
}
