class FoodType {
  final int typeId;
  final String name;
  String imageUri;

  FoodType(this.typeId, this.name, {this.imageUri = ""});

  @override
  String toString() => "Type ID: $typeId\nName: $name\nImage URI: $imageUri\n";
}
