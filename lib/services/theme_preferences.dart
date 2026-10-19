import 'user_data_store.dart';

class ThemePreferences {
  ThemePreferences({StringPreferences? preferences})
    : _preferences = preferences ?? SharedPreferencesStringStore();

  static const _storageKey = 'conviene.theme.v1';
  final StringPreferences _preferences;

  Future<bool> loadDarkMode() async =>
      await _preferences.getString(_storageKey) == 'dark';

  Future<void> saveDarkMode(bool dark) =>
      _preferences.setString(_storageKey, dark ? 'dark' : 'light');
}
