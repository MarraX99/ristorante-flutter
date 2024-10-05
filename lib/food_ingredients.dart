import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurant/database/food.dart';
import 'package:restaurant/database/ingredient_quantity.dart';
import 'package:restaurant/database/ingredients.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FoodIngredients extends StatefulWidget {
  final Food food;
  final FirebaseFirestore firestoreDB = FirebaseFirestore.instance;
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  
  FoodIngredients(this.food, {super.key});
  
  @override
  State<FoodIngredients> createState() => _FoodIngredientsState();

}

class _FoodIngredientsState extends State<FoodIngredients> {
  late final Future<List<Ingredient>> _ingredientFuture;
  late List<Ingredient> _ingredientList;
  int _quantity = 1;
  late double _totalPrice;
  late final Map<int,IngredientQuantity> _ingredientQuantities;
  late final Map<int,bool> _ingredientDecrementsEnabled;
  late final Map<int,bool> _ingredientIncrementsEnabled;
  bool _buttonsActive = false;
  bool _buttonDecrementEnabled = false;
  late final NumberFormat _format = NumberFormat.currency(symbol: "€ ", locale: Localizations.localeOf(context).toString());
  late Map<String,dynamic> _ingredientNames;

  @override
  void initState() {
    super.initState();
    _totalPrice = widget.food.unitPrice;
    _ingredientFuture = _getIngredients();
    _ingredientFuture.then((result) {
      Map<int,IngredientQuantity> quantities = {};
      Map<int,bool> increments = {};
      Map<int,bool> decrements = {};
      for(Ingredient i in result) {
        quantities[i.ingredientId] = IngredientQuantity.normal;
        increments[i.ingredientId] = true;
        decrements[i.ingredientId] = true;
      }
      setState(() {
        _buttonsActive = !_buttonsActive;
        _ingredientQuantities = quantities;
        _ingredientIncrementsEnabled = increments;
        _ingredientDecrementsEnabled = decrements;
      });
    });
  }

  Future<List<Ingredient>> _getIngredients() async {
    List<Ingredient> list = List.empty(growable: true);
    try {
      var result = await widget.firestoreDB.collection("food_ingredients").where("food_id", isEqualTo: "${widget.food.foodId}").limit(1).get();
      List<String> ingredientIds = List.from(result.docs[0].data()["ingredient_ids"]);
      for (String id in ingredientIds) {
        var currentIngredient = await widget.firestoreDB.doc("ingredients/$id").get();
        list.add(Ingredient(int.parse(currentIngredient.id), currentIngredient.data()!["name"],
            currentIngredient.data()!["unit_price"] + 0.0, imageUri: currentIngredient.data()!["image_uri"]));
      }
      _ingredientList = list;
      String jsonNames = await DefaultAssetBundle.of(context).loadString("assets/strings/${Localizations.localeOf(context).toString()}/ingredient_names.json");
      _ingredientNames = jsonDecode(jsonNames);
    } catch (error) {
      if (kDebugMode) print("Error while retrieving ingredients data:\n$error");
      _ingredientList = List.empty();
      return List<Ingredient>.empty();
    }
    return list;
  }

  Widget _buildMainBody(BuildContext context, AsyncSnapshot<List<Ingredient>> snapshot) {
    switch (snapshot.connectionState) {
      case ConnectionState.waiting: {
        return const Flexible(fit: FlexFit.tight, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CupertinoActivityIndicator()]));
      }
      case ConnectionState.done: {
        if(snapshot.hasError) {
          if (kDebugMode) print("Error while retrieving ingredients data:\n${snapshot.error}");
          return Flexible(fit: FlexFit.tight, child: Text("${snapshot.error}",
              style: const TextStyle(color: CupertinoDynamicColor.withBrightness(color: CupertinoColors.destructiveRed, darkColor: CupertinoColors.destructiveRed))));
        }
        if(snapshot.hasData) {
          return Container(margin: const EdgeInsets.all(6.0),
              child: ListView.builder(itemCount: snapshot.data!.length, clipBehavior: Clip.hardEdge, itemBuilder: (BuildContext context, int index) {
                return Container(
                  margin: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(10.0),
                      color: CupertinoTheme.of(context).primaryColor
                  ),
                  height: 100.0,
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.0)),
                          margin: EdgeInsets.zero, padding: EdgeInsets.zero,
                          clipBehavior: Clip.hardEdge,
                          child: Image.network(snapshot.data![index].imageUri, fit: BoxFit.fill, semanticLabel: snapshot.data![index].name, width: 150.0, height: 100)
                      ),
                      Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(
                                  child: Align(alignment: Alignment.center,
                                      child: _ingredientQuantities[snapshot.data![index].ingredientId] == IngredientQuantity.removed ?
                                      Text(_ingredientNames["${snapshot.data![index].ingredientId}"]!,
                                          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, decoration: TextDecoration.lineThrough,
                                              color: CupertinoTheme.of(context).textTheme.actionTextStyle.color
                                          )
                                      ) :
                                      Text(_ingredientNames["${snapshot.data![index].ingredientId}"]!, style: CupertinoTheme.of(context).textTheme.actionTextStyle),
                                  )
                              ),
                              Expanded(flex: 2,
                                  child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                          child: Container(margin: const EdgeInsets.symmetric(horizontal: 6.0),
                                            child: _ingredientQuantities[snapshot.data![index].ingredientId] == IngredientQuantity.extra ?
                                            Text(AppLocalizations.of(context)!.ingredientUnitPrice(_format.format(snapshot.data![index].unitPrice)), style: CupertinoTheme.of(context).textTheme.navTitleTextStyle) :
                                            const Text(""),
                                          )
                                      ),
                                      SizedBox(width: 50.0, height: 50.0,
                                        child: CupertinoButton(
                                            color: CupertinoColors.systemCyan,
                                            padding: EdgeInsets.zero,
                                            onPressed: _ingredientDecrementsEnabled[snapshot.data![index].ingredientId]! ? () {
                                              switch(_ingredientQuantities[snapshot.data![index].ingredientId]!) {
                                                case IngredientQuantity.removed: break;
                                                case IngredientQuantity.normal: {
                                                  setState(() {
                                                    _ingredientQuantities[snapshot.data![index].ingredientId] = IngredientQuantity.removed;
                                                    _ingredientDecrementsEnabled[snapshot.data![index].ingredientId] = false;
                                                  });
                                                  break;
                                                }
                                                case IngredientQuantity.extra: {
                                                  setState(() {
                                                    _ingredientQuantities[snapshot.data![index].ingredientId] = IngredientQuantity.normal;
                                                    _totalPrice -= (snapshot.data![index].unitPrice * _quantity);
                                                    _ingredientIncrementsEnabled[snapshot.data![index].ingredientId] = true;
                                                  });
                                                }
                                              }
                                            } : null,
                                            child: Icon(CupertinoIcons.minus_circle, size: 30.0, color: CupertinoTheme.of(context).scaffoldBackgroundColor)
                                        ),
                                      ),
                                      Container(width: 50.0, height: 50.0, margin: const EdgeInsets.only(right: 6.0, left: 6.0),
                                        child: CupertinoButton(
                                            color: CupertinoColors.systemCyan,
                                            padding: EdgeInsets.zero,
                                            onPressed: _ingredientIncrementsEnabled[snapshot.data![index].ingredientId]! ? () {
                                              switch(_ingredientQuantities[snapshot.data![index].ingredientId]!) {
                                                case IngredientQuantity.extra: break;
                                                case IngredientQuantity.normal: {
                                                  setState(() {
                                                    _ingredientQuantities[snapshot.data![index].ingredientId] = IngredientQuantity.extra;
                                                    _ingredientIncrementsEnabled[snapshot.data![index].ingredientId] = false;
                                                    _totalPrice += (snapshot.data![index].unitPrice * _quantity);
                                                  });
                                                  break;
                                                }
                                                case IngredientQuantity.removed: {
                                                  setState(() {
                                                    _ingredientQuantities[snapshot.data![index].ingredientId] = IngredientQuantity.normal;
                                                    _ingredientDecrementsEnabled[snapshot.data![index].ingredientId] = true;
                                                  });
                                                }
                                              }
                                            } : null,
                                            child: Icon(CupertinoIcons.add_circled, size: 30.0, color: CupertinoTheme.of(context).scaffoldBackgroundColor)
                                        ),
                                      )
                                    ],
                                  )
                              )
                            ],
                          )
                      )
                    ],
                  ),
                );
              })
          );
        } else {return const Flexible(fit: FlexFit.tight, child: SizedBox());}
      }
      default: {return Flexible(fit: FlexFit.tight, child: Text("No action", style: CupertinoTheme.of(context).textTheme.textStyle));}
    }
  }

  void _decrementFoodQuantity() {
    double toRemove = widget.food.unitPrice;
    _ingredientQuantities.forEach((key, value) {
      if(value == IngredientQuantity.extra) {toRemove += _ingredientList.firstWhere((it) => it.ingredientId == key).unitPrice;}
    });
    setState(() {
      _quantity == --_quantity;
      _totalPrice -= toRemove;
      if(_quantity == 1) _buttonDecrementEnabled = false;
    });
  }

  void _incrementFoodQuantity() {
    double toAdd = widget.food.unitPrice;
    _ingredientQuantities.forEach((key, value) {
      if(value == IngredientQuantity.extra) {toAdd += _ingredientList.firstWhere((it) => it.ingredientId == key).unitPrice;}
    });
    setState(() {
      _quantity == ++_quantity;
      _buttonDecrementEnabled = true;
      _totalPrice += toAdd;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
        navigationBar: CupertinoNavigationBar(
          middle: Text(AppLocalizations.of(context)!.titleCustomizeFood),
          backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(flex: 11,
                child: Column(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(margin: const EdgeInsets.only(top: 6.0),
                        child: Text(widget.food.name, style: CupertinoTheme.of(context).textTheme.actionTextStyle)
                    ),
                    Container(
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.0)),
                        clipBehavior: Clip.hardEdge, margin: const EdgeInsets.only(top: 6.0),
                        child: Image.network(widget.food.imageUri, fit: BoxFit.fill, semanticLabel: widget.food.name, width: 200.0, height: 200.0)
                    ),
                    Container(margin: const EdgeInsets.fromLTRB(20.0, 6.0, 20.0, 0.0),
                      child: Text(widget.food.description, style: CupertinoTheme.of(context).textTheme.textStyle),
                    ),
                    Container(margin: const EdgeInsets.only(top: 6.0),
                      child: Text(AppLocalizations.of(context)!.titleQuantity, style: CupertinoTheme.of(context).textTheme.actionTextStyle),
                    ),
                    const Divider(marginTop: 6.0, marginLeft: 12.0, marginRight: 12.0),
                    Container(margin: const EdgeInsets.only(top: 6.0, bottom: 6.0),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(width: 50.0, height: 50.0,
                            child: CupertinoButton(
                                color: CupertinoColors.systemCyan,
                                padding: EdgeInsets.zero,
                                onPressed: _buttonDecrementEnabled && _buttonsActive && _quantity > 1 ? _decrementFoodQuantity : null,
                                child: Icon(CupertinoIcons.minus_circle, size: 30.0, color: CupertinoTheme.of(context).scaffoldBackgroundColor)
                            ),
                          ),
                          Text("$_quantity", style: CupertinoTheme.of(context).textTheme.actionTextStyle),
                          SizedBox(width: 50.0, height: 50.0,
                            child: CupertinoButton(
                                color: CupertinoColors.systemCyan,
                                padding: EdgeInsets.zero,
                                onPressed: _buttonsActive ? _incrementFoodQuantity : null,
                                child: Icon(CupertinoIcons.add_circled, size: 30.0, color: CupertinoTheme.of(context).scaffoldBackgroundColor)
                            ),
                          )
                        ],
                      ),
                    ),
                    Text(AppLocalizations.of(context)!.titleCustomizeIngredients, style: CupertinoTheme.of(context).textTheme.actionTextStyle),
                    const Divider(marginTop: 6.0, marginLeft: 12.0, marginRight: 12.0),
                    Expanded(child: FutureBuilder(future: _ingredientFuture, builder: _buildMainBody))
                  ],
                ),
              ),
              Expanded(flex: 1,
                  child: Container(margin: const EdgeInsets.fromLTRB(12.0, 6.0, 12.0, 0.0),
                    child: CupertinoButton(
                      padding: const EdgeInsets.all(6.0),
                      color: CupertinoTheme.of(context).textTheme.navActionTextStyle.color,
                      onPressed: _buttonsActive ? () async {
                        setState(() => _buttonsActive = false);
                        List<DocumentReference> extra = List.empty(growable: true);
                        List<DocumentReference> removed = List.empty(growable: true);
                        _ingredientQuantities.forEach((key, value) {
                          switch(value) {
                            case IngredientQuantity.normal: break;
                            case IngredientQuantity.extra: {
                              extra.add(widget.firestoreDB.doc("ingredients/$key"));
                              break;
                            }
                            case IngredientQuantity.removed: removed.add(widget.firestoreDB.doc("ingredients/$key"));
                          }
                        });
                        var cartRef = widget.firestoreDB.collection("users/${widget.uid}/shopping_cart");
                        var similarQuery = cartRef.where("food", isEqualTo: widget.firestoreDB.doc("foods/${widget.food.foodId}"));
                        if(extra.isNotEmpty) similarQuery = similarQuery.where("extra_ingredients", arrayContains: extra);
                        if(removed.isNotEmpty) similarQuery = similarQuery.where("removed_ingredients", arrayContains: removed).limit(1);
                        var similar = await similarQuery.get();
                        if(similar.docs.isEmpty) {
                          await cartRef.doc().set({
                            "food": widget.firestoreDB.doc("foods/${widget.food.foodId}"),
                            "price": _totalPrice,
                            "quantity": _quantity,
                            "extra_ingredients": extra,
                            "removed_ingredients": removed
                          });
                        } else {
                          await similar.docs.first.reference.set({
                            "quantity": similar.docs.first.data()["quantity"] + _quantity,
                            "price": similar.docs.first.data()["price"] + _totalPrice
                          }, SetOptions(merge: true));
                        }
                        Navigator.pop(context);
                      } : null,
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(AppLocalizations.of(context)!.shoppingCartAddProducts(_quantity).toUpperCase(), style: CupertinoTheme.of(context).textTheme.actionTextStyle),
                            Text(_format.format(_totalPrice), style: CupertinoTheme.of(context).textTheme.actionTextStyle),
                          ]
                      ),
                    ),
                  )
              )
            ]
        )
    );
  }
}

class Divider extends StatelessWidget {
  final double marginLeft;
  final double marginTop;
  final double marginRight;
  final double marginBottom;
  final double maxHeight;
  const Divider({super.key, this.marginTop = 0.0, this.marginBottom = 0.0, this.marginLeft = 0.0, this.marginRight = 0.0, this.maxHeight = 1.0});

  @override
  Widget build(BuildContext context) {
    return Container(margin: EdgeInsets.fromLTRB(marginLeft, marginTop, marginRight, marginBottom), constraints: BoxConstraints(maxHeight: maxHeight),
        color: const CupertinoDynamicColor.withBrightness(color: CupertinoColors.separator, darkColor: CupertinoColors.opaqueSeparator)
    );
  }
}