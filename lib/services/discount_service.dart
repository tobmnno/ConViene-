import '../models/discount.dart';
import '../repositories/conviene_repository.dart';
import 'discount_engine.dart';

class DiscountService {
  const DiscountService(this._repository, this.engine);

  final ConvieneRepository _repository;
  final DiscountEngine engine;

  Future<List<Promotion>> loadPromotions(DateTime date) {
    return _repository.getPromotions(date);
  }
}
