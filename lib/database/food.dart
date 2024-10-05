class Food {
  late final int foodId;
  late final String name;
  late final int type;
  late final String description;
  late final double unitPrice;
  String imageUri;

  Food(this.foodId, this.name, this.type, this.description, this.unitPrice, {this.imageUri = ""});

  @override
  String toString() => "Food ID: $foodId\nName: $name\nDescription: $description\nType: $type\nUnit price: $unitPrice\nImage URI: $imageUri\n";
}