import '../models/price_quote.dart';
import '../repositories/conviene_repository.dart';

enum SearchSort { bestPrice, unitPrice, alphabetical }

class ProductSearchService {
  const ProductSearchService(this._repository);

  final ConvieneRepository _repository;

  Future<List<SearchResult>> search({
    required String query,
    required Set<String> storeIds,
    required SearchSort sort,
  }) async {
    final results = await _repository.searchProducts(
      query: query,
      storeIds: storeIds,
    );
    return sortResults(results, sort, query: query);
  }

  List<SearchResult> sortResults(
    List<SearchResult> results,
    SearchSort sort, {
    String query = '',
  }) {
    final sorted = [...results];
    final queryTokens = _queryTokens(query);
    sorted.sort((a, b) {
      final relevance = _compareRelevance(queryTokens, a, b);
      if (relevance != 0) {
        return relevance;
      }
      return switch (sort) {
        SearchSort.bestPrice => a.price.priceOriginal.compareTo(
          b.price.priceOriginal,
        ),
        SearchSort.unitPrice => a.price.priceUnitario.compareTo(
          b.price.priceUnitario,
        ),
        SearchSort.alphabetical => a.product.name.compareTo(b.product.name),
      };
    });
    return sorted;
  }

  int _compareRelevance(
    Set<String> queryTokens,
    SearchResult a,
    SearchResult b,
  ) {
    if (queryTokens.isEmpty) {
      return 0;
    }
    final aScore = _relevanceScore(queryTokens, a.product.name);
    final bScore = _relevanceScore(queryTokens, b.product.name);
    final missingComparison = aScore.missing.compareTo(bScore.missing);
    if (missingComparison != 0) {
      return missingComparison;
    }
    return bScore.matched.compareTo(aScore.matched);
  }

  _SearchRelevance _relevanceScore(
    Set<String> queryTokens,
    String productName,
  ) {
    final productTokens = _tokens(productName).toSet();
    var matched = 0;
    var missing = 0;
    for (final token in queryTokens) {
      if (productTokens.contains(token)) {
        matched++;
      } else {
        missing++;
      }
    }
    return _SearchRelevance(matched: matched, missing: missing);
  }

  Set<String> _queryTokens(String query) {
    return {
      for (final token in _tokens(query))
        if (!_ignoredQueryTokens.contains(token)) token,
    };
  }

  List<String> _tokens(String value) {
    final normalized = _normalize(value)
        .replaceAllMapped(RegExp(r'([0-9]+)([a-z]+)'), (match) {
          return '${match.group(1)} ${match.group(2)}';
        })
        .replaceAllMapped(RegExp(r'([a-z]+)([0-9]+)'), (match) {
          return '${match.group(1)} ${match.group(2)}';
        })
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return const [];
    }
    return [
      for (final token in normalized.split(RegExp(r'\s+')))
        if (token.length >= 3 || int.tryParse(token) != null)
          _singularToken(token),
    ];
  }

  String _singularToken(String token) {
    if (int.tryParse(token) != null) {
      return token;
    }
    if (token.length > 5 && token.endsWith('es')) {
      return token.substring(0, token.length - 2);
    }
    if (token.length > 5 && token.endsWith('s')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  static const _ignoredQueryTokens = {
    'aceite',
    'agua',
    'arroz',
    'azucar',
    'bebida',
    'cafe',
    'clasico',
    'crema',
    'de',
    'del',
    'dulce',
    'el',
    'galleta',
    'galletita',
    'gramo',
    'la',
    'las',
    'leche',
    'los',
    'pan',
    'queso',
    'sabor',
    'sin',
    'yerba',
  };
}

class _SearchRelevance {
  const _SearchRelevance({required this.matched, required this.missing});

  final int matched;
  final int missing;
}
