class Ingredient {
  late final int ingredientId;
  late final String name;
  late final double unitPrice;
  String imageUri;

  Ingredient(this.ingredientId, this.name, this.unitPrice, {this.imageUri = ""});

  @override
  String toString() => "Ingredient ID: $ingredientId\nName: $name\nUnit price: $unitPrice\nImage URI: $imageUri\n";
}