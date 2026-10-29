import 'dart:convert';

import 'package:conviene/repositories/api_repository.dart';
import 'package:conviene/repositories/community_price_repository.dart';
import 'package:conviene/repositories/mock_repository.dart';
import 'package:conviene/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _live = bool.fromEnvironment('CONVIENE_LIVE_SEARCH');
const _apiUrl = String.fromEnvironment(
  'CONVIENE_LIVE_API_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

void main() {
  test('live search parses official responses and updates AppState', () async {
    final state = AppState(
      repository: ApiRepository(
        baseUrl: Uri.parse(_apiUrl),
        fallback: MockRepository(),
      ),
    );
    state.selectedStoreIds = {'coto', 'carrefour', 'lagallega'};
    await state.searchProducts('leche entera');
    expect(state.lastError, isNull);
    expect(state.searchResults, isNotEmpty);
    state.dispose();
  }, skip: !_live);

  test(
    'live search works through community wrapper and live discounts',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(<Object>[]),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final source = ApiRepository(
        baseUrl: Uri.parse(_apiUrl),
        fallback: MockRepository(),
      );
      final state = AppState(
        repository: CommunityPriceRepository(source, client),
      );
      state.selectedStoreIds = {'coto', 'carrefour', 'lagallega'};
      state.promotions = await source.getPromotions(DateTime.now());
      await state.searchProducts('leche entera');
      expect(state.lastError, isNull);
      expect(state.searchResults, isNotEmpty);
      state.dispose();
      client.dispose();
    },
    skip: !_live,
  );
}
