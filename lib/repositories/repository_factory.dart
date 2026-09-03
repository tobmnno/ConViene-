import 'api_repository.dart';
import 'conviene_repository.dart';
import 'mock_repository.dart';

enum RepositoryMode { mock, api }

ConvieneRepository createRepository({
  RepositoryMode mode = RepositoryMode.api,
  Uri? apiBaseUrl,
}) {
  final mockRepository = MockRepository();
  return switch (mode) {
    RepositoryMode.mock => mockRepository,
    RepositoryMode.api => ApiRepository(
      baseUrl:
          apiBaseUrl ??
          Uri.parse(
            const String.fromEnvironment(
              'CONVIENE_API_BASE_URL',
              defaultValue: 'http://127.0.0.1:8000',
            ),
          ),
      fallback: mockRepository,
    ),
  };
}
