import 'package:restaurant/database/food.dart';
import 'package:restaurant/database/ingredients.dart';

class CartProduct {
  late final String cartProductId;
  late final Food food;
  late final List<Ingredient> extraIngredients;
  late final List<Ingredient> removedIngredients;
  late int quantity;
  late double price;

  CartProduct(this.cartProductId, this.food, this.extraIngredients, this.removedIngredients, this.quantity, this.price);
}

