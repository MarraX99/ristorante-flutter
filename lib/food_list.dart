import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:restaurant/database/food.dart';
import 'package:restaurant/food_ingredients.dart';
import 'package:restaurant/shopping_cart.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FoodList extends StatefulWidget {
  final FirebaseFirestore _firestoreDB = FirebaseFirestore.instance;
  final int typeId;

  FoodList(this.typeId, {super.key});

  @override
  State<FoodList> createState() => _FoodListState();
}

class _FoodListState extends State<FoodList> {
  late Future<List<Food>> _foodList;
  late Map<String,dynamic> _foodNames;
  late Map<String,dynamic> _foodDescriptions;

  @override
  void initState() {
    super.initState();
    _foodList = _getFoodList();
  }

  Future<List<Food>> _getFoodList() async{
    List<Food> list = List.empty(growable: true);
    try {
      DocumentReference foodTypeRef = widget._firestoreDB.doc("food_types/${widget.typeId}");
      var result = await widget._firestoreDB.collection("foods").where("type", isEqualTo: foodTypeRef).get();
      for(var doc in result.docs) {
        var data = doc.data();
        list.add(Food(int.parse(doc.id), data["name"], widget.typeId, "Placeholder description", data["unit_price"] + 0.0, imageUri: data["image_uri"]));
        String jsonNames = await DefaultAssetBundle.of(context).loadString("assets/strings/${Localizations.localeOf(context).toString()}/food_names.json");
        String jsonDescriptions = await DefaultAssetBundle.of(context).loadString("assets/strings/${Localizations.localeOf(context).toString()}/food_descriptions.json");
        _foodNames = jsonDecode(jsonNames);
        _foodDescriptions = jsonDecode(jsonDescriptions);
      }
    } catch(error) {
      if(kDebugMode) print("Error while retrieving food data:\n$error");
      return List<Food>.empty();
    }
    return list;
  }

  Widget _buildMainBody(BuildContext context, AsyncSnapshot<List<Food>> snapshot) {
    switch (snapshot.connectionState) {
      case ConnectionState.waiting: {
        return const Column(mainAxisSize: MainAxisSize.max, mainAxisAlignment: MainAxisAlignment.center,
            children: [CupertinoActivityIndicator()]);
      }
      case ConnectionState.done: {
        if(snapshot.hasError) {
          if (kDebugMode) print("Error while retrieving food data:\n${snapshot.error}");
          return Text("${snapshot.error}");
        }
        if(snapshot.hasData) {
          if (kDebugMode) print(snapshot.data!);
          NumberFormat format = NumberFormat.currency(symbol: "€ ", locale: Localizations.localeOf(context).toString());
          return ListView.builder(itemCount: snapshot.data!.length, clipBehavior: Clip.hardEdge, itemBuilder: (BuildContext context, int index) {
            return Container(
              decoration: BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(10.0)),
              margin: const EdgeInsets.all(6.0), height: 150.0,
              child: CupertinoButton(
                  color: CupertinoTheme.of(context).primaryColor,
                  padding: EdgeInsets.zero,
                  onPressed: () {Navigator.push(context, CupertinoPageRoute(builder: (context) { return FoodIngredients(snapshot.data![index]);}));},
                  child: Row(
                      mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.0)),
                            clipBehavior: Clip.hardEdge,
                            child: Image.network(snapshot.data![index].imageUri, fit: BoxFit.fill,
                                semanticLabel: _foodNames["${snapshot.data![index].foodId}"]!, width: 200.0, height: 150.0
                            )
                        ),
                        Expanded(
                          child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Text(_foodNames["${snapshot.data![index].foodId}"]!, style: CupertinoTheme.of(context).textTheme.actionTextStyle),
                              Padding(padding: EdgeInsets.only(left: 6.0),
                                child: Text(_foodDescriptions["${snapshot.data![index].foodId}"]!, style: CupertinoTheme.of(context).textTheme.textStyle, maxLines: 10),
                              ),
                              Align(alignment: Alignment.centerRight,
                                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                    child: Text(format.format(snapshot.data![index].unitPrice), style: CupertinoTheme.of(context).textTheme.actionTextStyle),
                                  )
                              )
                            ],
                          ),
                        ),
                      ]
                  )
              ),
            );
          }
          );
        } else {return const SizedBox(width: null, height: null);}
      }
      default: {return const Text("No action");}
    }
  }

  void _tabBarListener(int index) {
    switch(index) {
      case 0: return;
      case 1: {Navigator.push(context, CupertinoPageRoute(builder: (context) { return const ShoppingCart();})); break;}
      default: return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
        backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
        navigationBar: CupertinoNavigationBar(
          middle: Text(AppLocalizations.of(context)!.titleSelectFood, style: CupertinoTheme.of(context).textTheme.navTitleTextStyle),
          backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.start, mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(flex: 11,
                child: FutureBuilder(future: _foodList, builder: _buildMainBody),
              ),
              Expanded(flex: 1,
                child: CupertinoTabBar(currentIndex: 0, activeColor: CupertinoTheme.of(context).textTheme.navActionTextStyle.color,
                    items: <BottomNavigationBarItem>[
                      BottomNavigationBarItem(
                          icon: Icon(CupertinoIcons.add_circled, semanticLabel: AppLocalizations.of(context)!.titleNewOrder),
                          label: AppLocalizations.of(context)!.titleNewOrder
                      ),
                      BottomNavigationBarItem(
                          icon: Icon(CupertinoIcons.shopping_cart, semanticLabel: AppLocalizations.of(context)!.titleShoppingCart),
                          label: AppLocalizations.of(context)!.titleShoppingCart
                      )
                    ],
                  onTap: _tabBarListener
                ),
              )
            ]
        )
    );
  }
}


