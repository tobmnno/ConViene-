import '../models/supermarket.dart';
import '../repositories/conviene_repository.dart';

class SupermarketService {
  const SupermarketService(this._repository);

  final ConvieneRepository _repository;

  Future<List<Supermarket>> loadSupermarkets() {
    return _repository.getSupermarkets();
  }
}
