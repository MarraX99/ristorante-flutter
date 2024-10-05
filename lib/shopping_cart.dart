import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurant/database/cart_product.dart';
import 'package:restaurant/database/ingredients.dart';
import 'package:intl/intl.dart';
import 'package:restaurant/food_ingredients.dart';
import 'database/food.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'order_note.dart';

final String uid = FirebaseAuth.instance.currentUser!.uid;
final FirebaseFirestore firestoreDB = FirebaseFirestore.instance;

class ShoppingCart extends StatefulWidget {

  const ShoppingCart({super.key});

  @override
  State<StatefulWidget> createState() => _ShoppingCartState();
}

class _ShoppingCartState extends State<ShoppingCart> {

  late Future<List<CartProduct>> _future;
  int _selectedIndexDay = -1;
  int _selectedIndexHour = -1;
  late int _selectedDateTime;
  bool _orderButtonActive = true;
  late final NumberFormat _format = NumberFormat.currency(symbol: "€ ", locale: Localizations.localeOf(context).toString());

  @override
  initState() {
    super.initState();
    _future = _getProducts();
  }

  Future<List<CartProduct>> _getProducts() async {
    List<CartProduct> list = List.empty(growable: true);
    try  {
      var productsRef = await firestoreDB.collection("users/$uid/shopping_cart").limit(1).get();
      if(productsRef.docs.isEmpty) setState(() => _orderButtonActive = false);
      productsRef = await firestoreDB.collection("users/$uid/shopping_cart").get();
      for(var doc in productsRef.docs) {
        List<Ingredient> extra = List.empty(growable: true);
        List<Ingredient> removed = List.empty(growable: true);
        for(DocumentReference element in doc.data()["extra_ingredients"]) {
          var tmp = await firestoreDB.doc("ingredients/${element.id}").get();
          extra.add(Ingredient(int.parse(element.id), tmp.data()!["name"], tmp.data()!["unit_price"] + 0.0));
        }
        for(DocumentReference element in doc.data()["removed_ingredients"]) {
          var tmp = await firestoreDB.doc("ingredients/${element.id}").get();
          removed.add(Ingredient(int.parse(element.id), tmp.data()!["name"], tmp.data()!["unit_price"] + 0.0));
        }
        var food = await firestoreDB.doc("foods/${(doc.data()["food"] as DocumentReference).id}").get();
        list.add(CartProduct(doc.id,
            Food(int.parse(food.id), food.data()!["name"], int.parse((food.data()!["type"] as DocumentReference).id), "Placeholder description",
            food.data()!["unit_price"] + 0.0, imageUri: food.data()!["image_uri"]),
            extra, removed, doc.data()["quantity"], doc.data()["price"] + 0.0));
      }
    } catch (error) {
      if (kDebugMode) print("Error while retrieving cart products data:\n$error");
      return List<CartProduct>.empty();
    }
    return list;
  }

  Widget _buildProductsList(BuildContext context, AsyncSnapshot<List<CartProduct>> snapshot) {
    switch (snapshot.connectionState) {
      case ConnectionState.waiting: {
        return const Column(mainAxisAlignment: MainAxisAlignment.center, children: [CupertinoActivityIndicator()]);
      }
      case ConnectionState.done: {
        if(snapshot.hasError) {
          if (kDebugMode) print("Error while retrieving cart products data:\n${snapshot.error}");
          return Text("${snapshot.error}");
        }
        if(snapshot.hasData) {
          StringBuffer buffer = StringBuffer("");
          return Container(margin: const EdgeInsets.all(6.0),
              child: ListView.builder(itemCount: snapshot.data!.length, clipBehavior: Clip.hardEdge, itemBuilder: (BuildContext context, int index) {
                String extraIngredientsLabel = "";
                String removedIngredientsLabel = "";
                if(snapshot.data![index].extraIngredients.isNotEmpty) {
                  for (Ingredient i in snapshot.data![index].extraIngredients) {buffer.writeln(AppLocalizations.of(context)!.shoppingCartExtraIngredient(i.name));}
                  extraIngredientsLabel = buffer.toString().substring(0, buffer.length - 1);
                  buffer.clear();
                }
                if(snapshot.data![index].removedIngredients.isNotEmpty) {
                  for(Ingredient i in snapshot.data![index].removedIngredients) {buffer.writeln(i.name);}
                  removedIngredientsLabel = buffer.toString().substring(0, buffer.length - 1);
                  buffer.clear();
                }
                return Container(
                  margin: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(10.0),
                      color: CupertinoTheme.of(context).primaryColor,
                  ),
                  height: null, width: null,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                  margin: const EdgeInsets.all(6.0),
                                  child: Text(snapshot.data![index].food.name, style: CupertinoTheme.of(context).textTheme.actionTextStyle)
                              ),
                              Image.network(snapshot.data![index].food.imageUri, fit: BoxFit.fill, semanticLabel: snapshot.data![index].food.name, width: 150.0, height: 100.0,),
                              Container(
                                  margin: const EdgeInsets.all(6.0),
                                  child: Text(AppLocalizations.of(context)!.productQuantity(snapshot.data![index].quantity), style: CupertinoTheme.of(context).textTheme.textStyle)
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                  margin: const EdgeInsets.all(6.0),
                                  child: Text(extraIngredientsLabel, style: CupertinoTheme.of(context).textTheme.textStyle, maxLines: 10)
                              ),
                              Container(
                                margin: const EdgeInsets.all(6.0),
                                child: Text(removedIngredientsLabel, style: CupertinoTheme.of(context).textTheme.textStyle, maxLines: 10),
                              ),
                              Container(
                                margin: const EdgeInsets.all(6.0),
                                child: Text(_format.format(snapshot.data![index].price), style: CupertinoTheme.of(context).textTheme.actionTextStyle),
                              ),
                              Row(mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(margin: const EdgeInsets.all(6.0), width: 50.0, height: 50.0,
                                        child: CupertinoButton(
                                            color: CupertinoColors.systemCyan,
                                            padding: EdgeInsets.zero,
                                            onPressed: () async {
                                              await firestoreDB.doc("users/$uid/shopping_cart/${snapshot.data![index].cartProductId}").delete();
                                              setState(() => snapshot.data!.removeAt(index));
                                              if(snapshot.data!.isEmpty) Navigator.pop(context);
                                            },
                                            child: Icon(CupertinoIcons.trash, size: 30.0, color: CupertinoTheme.of(context).scaffoldBackgroundColor)
                                        )
                                    )
                                  ]
                              )
                            ],
                          ),
                        )
                      ]
                  ),
                );
              })
          );
        } else {return const SizedBox();}
      }
      default: {return const Text("No action");}
    }
  }

  Widget _buildDayList(BuildContext context, AsyncSnapshot<List<CartProduct>> snapshot) {
    switch (snapshot.connectionState) {
      case ConnectionState.waiting: {
        return const Column(mainAxisAlignment: MainAxisAlignment.center, children: [CupertinoActivityIndicator()]);
      }
      case ConnectionState.done: {
        if(snapshot.hasError) {return const SizedBox();}
        if(snapshot.hasData) {
          List<int> days = List.empty(growable: true);
          DateTime currentDay = DateTime.now();
          if(currentDay.hour <= 22 || (currentDay.hour == 23 && currentDay.minute <= 15)) days.add(currentDay.millisecondsSinceEpoch);
          for(int i = 1; i <= 4; ++i) {
            int tmp = currentDay.millisecondsSinceEpoch + 86400000; // 1 day = 86400000 milliseconds
            currentDay = DateTime.fromMillisecondsSinceEpoch(tmp);
            days.add(currentDay.millisecondsSinceEpoch);
          }
          DateFormat format = DateFormat("dd MMMM", Localizations.localeOf(context).toString());
          return ListView.builder(itemCount: days.length, clipBehavior: Clip.hardEdge, scrollDirection: Axis.horizontal, itemBuilder: (BuildContext context, int index) {
            return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndexDay = index;
                    _selectedIndexHour = -1;
                    _selectedDateTime = days[index];
                  });
                },
                child: Container(
                    decoration: BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(10.0),
                        color: _selectedIndexDay == index ? CupertinoTheme.of(context).primaryContrastingColor : CupertinoTheme.of(context).primaryColor
                    ),
                    constraints: const BoxConstraints(minWidth: 50.0, minHeight: 20.0),
                    padding: const EdgeInsets.all(6.0),
                    margin: const EdgeInsets.symmetric(horizontal: 6.0), clipBehavior: Clip.hardEdge,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _selectedIndexDay == index ? Icon(CupertinoIcons.checkmark_alt, color: CupertinoTheme.of(context).textTheme.navTitleTextStyle.color) : const SizedBox(),
                          Text(format.format(DateTime.fromMillisecondsSinceEpoch(days[index], isUtc: false))),
                        ]
                    )
                )
            );
          });
        } else {return const SizedBox();}
      }
      default: {return const Text("No action");}
    }
  }

  Widget _buildHourList(int day) {
    List<int> hours = List.empty(growable: true);
    DateTime startHour = DateTime.now();
    DateTime currentDay = DateTime.fromMillisecondsSinceEpoch(day);
    if(currentDay.day == startHour.day) {
      switch(startHour.hour) {
        case >= 0 && <= 17: {startHour = DateTime(currentDay.year, currentDay.month, currentDay.day, 18, 30); break;}
        case >= 18 && <= 22: {
          switch(startHour.minute) {
            case >= 0 && <= 15: {startHour = DateTime(currentDay.year, currentDay.month, currentDay.day, startHour.hour, 30); break;}
            case >= 16 && <= 30: {startHour = DateTime(currentDay.year, currentDay.month, currentDay.day, startHour.hour, 45); break;}
            case >= 31 && <= 45: {startHour = DateTime(currentDay.year, currentDay.month, currentDay.day, startHour.hour + 1); break;}
            default: startHour = DateTime(currentDay.year, currentDay.month, currentDay.day, startHour.hour + 1, 15);
          } break;
        }
        case 23: startHour = DateTime(currentDay.year, currentDay.month, currentDay.day, startHour.hour, 30);
      }
      hours.add(startHour.millisecondsSinceEpoch);
      while(startHour.hour <= 22) { // from startHour until 23:00 if hour != 23
        startHour = DateTime.fromMillisecondsSinceEpoch(startHour.millisecondsSinceEpoch + 900000); // 15 minutes = 900000 milliseconds
        hours.add(startHour.millisecondsSinceEpoch);
      }
      startHour = DateTime.fromMillisecondsSinceEpoch(startHour.millisecondsSinceEpoch + 900000); // adding 23:15
      hours.add(startHour.millisecondsSinceEpoch);
    } else {
      startHour = DateTime(currentDay.year, currentDay.month, currentDay.day, 18, 30);
      hours.add(startHour.millisecondsSinceEpoch);
      while(startHour.hour <= 22) { // from 18:45 until 23:00
        startHour = DateTime.fromMillisecondsSinceEpoch(startHour.millisecondsSinceEpoch + 900000);
        hours.add(startHour.millisecondsSinceEpoch);
      }
      startHour = DateTime.fromMillisecondsSinceEpoch(startHour.millisecondsSinceEpoch + 900000);
      hours.add(startHour.millisecondsSinceEpoch);
    }
    DateFormat format = DateFormat("kk:mm");
    return ListView.builder(itemCount: hours.length, clipBehavior: Clip.hardEdge, scrollDirection: Axis.horizontal, itemBuilder: (BuildContext context, int index) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndexHour = index;
            _selectedDateTime = hours[index];
          });
        },
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(10.0),
              color: _selectedIndexHour == index ? CupertinoTheme.of(context).primaryContrastingColor : CupertinoTheme.of(context).primaryColor
          ),
          constraints: const BoxConstraints(minWidth: 50.0, minHeight: 20.0), margin: const EdgeInsets.symmetric(horizontal: 6.0),
          clipBehavior: Clip.hardEdge,
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _selectedIndexHour == index ? Icon(CupertinoIcons.checkmark_alt, color: CupertinoTheme.of(context).textTheme.navTitleTextStyle.color) : const SizedBox(),
              Text(format.format(DateTime.fromMillisecondsSinceEpoch(hours[index], isUtc: false)))
            ]
          )
        )
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(AppLocalizations.of(context)!.titleShoppingCart, style: CupertinoTheme.of(context).textTheme.navTitleTextStyle),
        backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(flex: 11,
            child: Column(mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Flexible(fit: FlexFit.loose, child: FutureBuilder(future: _future, builder: _buildProductsList)),
                const Divider(marginTop: 6.0, marginLeft: 12.0, marginRight: 12.0, marginBottom: 6.0),
                GestureDetector(
                  onTap: () {Navigator.push(context, CupertinoPageRoute(builder: (context) {return OrderNote();}));},
                  child: Container(
                    padding: EdgeInsets.zero, margin: const EdgeInsets.only(left: 6.0),
                    child: Row(mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const Icon(CupertinoIcons.doc, color: CupertinoColors.systemCyan),
                        Text(AppLocalizations.of(context)!.titleAddNote, style: const TextStyle(fontSize: 18.0, color: CupertinoColors.systemCyan))
                      ],
                    ),
                  ),
                ),
                const Divider(marginTop: 6.0, marginLeft: 12.0, marginRight: 12.0, marginBottom: 6.0),
                Container(
                  margin: const EdgeInsets.only(left: 6.0),
                  child: Text(AppLocalizations.of(context)!.titleDeliveryDatetime, style: CupertinoTheme.of(context).textTheme.actionTextStyle),
                ),
                const Divider(marginTop: 6.0, marginLeft: 12.0, marginRight: 12.0),
                Container(
                  constraints: const BoxConstraints(maxHeight: 40.0),
                  margin: const EdgeInsets.all(6.0),
                  child: FutureBuilder(future: _future, builder: _buildDayList),
                ),
                const Divider(marginTop: 6.0, marginLeft: 12.0, marginRight: 12.0),
                Container(
                  margin: const EdgeInsets.fromLTRB(6.0, 6.0, 6.0, 15.0),
                  constraints: const BoxConstraints(maxHeight: 40.0),
                  child:  _selectedIndexDay > -1 ? _buildHourList(_selectedDateTime) : const SizedBox(),
                )
              ]
            )
          ),
          Expanded(flex: 1,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12.0, 6.0, 12.0, 0.0),
              height: null, width: null,
              child: CupertinoButton(
                padding: const EdgeInsets.all(6.0),
                color: CupertinoTheme.of(context).textTheme.navActionTextStyle.color,
                onPressed: _orderButtonActive ? () {
                  if(_selectedIndexDay == -1 && _selectedIndexHour == -1) return;
                  setState(() => _orderButtonActive = false);
                  var order = firestoreDB.collection("orders").doc();
                  double totalPrice = 0.0;
                  _future.then((values) async {
                    try {
                      order.collection("products");
                      for(CartProduct product in values) {
                        List<DocumentReference> extra = List.empty(growable: true);
                        List<DocumentReference> removed = List.empty(growable: true);
                        for(Ingredient ingredient in product.extraIngredients) {extra.add(firestoreDB.doc("ingredients/${ingredient.ingredientId}"));}
                        for(Ingredient ingredient in product.removedIngredients) {removed.add(firestoreDB.doc("ingredients/${ingredient.ingredientId}"));}
                        firestoreDB.collection("orders/${order.id}/products").doc().set({
                          "food": firestoreDB.doc("foods/${product.food.foodId}"),
                          "quantity": product.quantity,
                          "price": product.price,
                          "extra_ingredients": extra,
                          "removed_ingredients": removed
                        });
                        totalPrice += product.price;
                      }
                      var user = await firestoreDB.doc("users/$uid").get();
                      await order.set({
                        "order_date_time": FieldValue.serverTimestamp(),
                        "delivery_date_time": Timestamp.fromMillisecondsSinceEpoch(_selectedDateTime),
                        "delivery_address": null,
                        "note": user.data()!["note"],
                        "user": user.reference,
                        "total_price": totalPrice
                      });
                      firestoreDB.doc("users/$uid").set({"order_note": ""}, SetOptions(merge: true));
                    } catch(error) {
                      if(kDebugMode) print("Error while creating new order\n$error");
                      await firestoreDB.doc("orders/${order.id}").delete();
                      setState(() => _orderButtonActive = true);
                      Navigator.pop(context);
                    }
                    try {
                      var products = await firestoreDB.collection("users/$uid/shopping_cart").get();
                      for(var product in products.docs) {await product.reference.delete();}
                      if(kDebugMode) print("User's shopping cart successfully deleted");
                    } catch(error) {if(kDebugMode) print("Error while deleting user's shopping cart\n$error");}
                    Navigator.pop(context);
                  });
                } : null,
                child: Text(AppLocalizations.of(context)!.orderOrderNow.toUpperCase(), style: CupertinoTheme.of(context).textTheme.actionTextStyle),
              ),
            )
          )
        ],
      ),
    );
  }
}
