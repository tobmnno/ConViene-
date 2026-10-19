import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/screens/home_screen.dart';
import 'package:conviene/services/theme_preferences.dart';
import 'package:conviene/services/user_data_store.dart';
import 'package:conviene/state/app_scope.dart';
import 'package:conviene/state/app_state.dart';
import 'package:conviene/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPreferences implements StringPreferences {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  tearDown(() => AppColors.setDarkMode(false));

  test('restores the saved theme without affecting shopping data', () async {
    final preferences = _MemoryPreferences();
    final theme = ThemePreferences(preferences: preferences);

    expect(await theme.loadDarkMode(), isFalse);
    await theme.saveDarkMode(true);
    expect(
      await ThemePreferences(preferences: preferences).loadDarkMode(),
      isTrue,
    );
    await theme.saveDarkMode(false);
    expect(await theme.loadDarkMode(), isFalse);
  });

  test('dark palette keeps brand colors and darkens surfaces', () {
    final light = buildAppTheme();
    final lightSurface = AppColors.surface;
    final dark = buildAppTheme(dark: true);

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(AppColors.surface, isNot(lightSurface));
    expect(AppColors.deepBlue, isNot(AppColors.navy));
    expect(dark.bottomNavigationBarTheme.backgroundColor, AppColors.surface);
    expect(AppColors.blue, const Color(0xFF175CD3));
    expect(AppColors.green, const Color(0xFF16B364));
  });

  testWidgets('the home control exposes the opposite theme action', (
    tester,
  ) async {
    final state = AppState(repository: MockRepository());
    state.supermarkets = await MockRepository().getSupermarkets();
    state.selectedStoreIds = {'coto', 'carrefour', 'lagallega'};
    var toggled = false;
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(dark: true),
          home: Scaffold(
            body: HomeScreen(
              darkMode: true,
              onToggleDarkMode: () => toggled = true,
              onNavigateToSearch: () {},
              onNavigateToCart: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Activar modo claro'));
    expect(toggled, isTrue);
    state.dispose();
  });
}
