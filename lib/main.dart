import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurant/food_list.dart';
import 'package:restaurant/shopping_cart.dart';
import 'database/food_type.dart';
import 'firebase_options.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuth.instance.signInWithEmailAndPassword(email: "flutter.app@gmail.com", password: "TestPassword1234");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      key: super.key,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      theme: const CupertinoThemeData(
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
        barBackgroundColor: CupertinoColors.systemGrey3,
        primaryColor: CupertinoColors.systemGrey6,
        primaryContrastingColor: CupertinoColors.systemGrey5,
        textTheme: CupertinoTextThemeData(
          primaryColor: CupertinoColors.systemBlue,
          textStyle: TextStyle(fontSize: 15.0, overflow: TextOverflow.ellipsis, color: CupertinoColors.secondaryLabel),
          actionTextStyle: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: CupertinoColors.label, overflow: TextOverflow.ellipsis),
          tabLabelTextStyle: TextStyle(fontSize: 15.0, color: CupertinoColors.secondaryLabel, overflow: TextOverflow.ellipsis),
          navTitleTextStyle: TextStyle(fontSize: 16.0, color: CupertinoColors.systemBlue, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis),
          navActionTextStyle: TextStyle(fontSize: 14.0, color: CupertinoColors.systemPurple)
        )
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('it'), // Italian
      ],
      home: HomePage(title: "Flutter Restaurant Homepage"),
    );
  }
}

class HomePage extends StatefulWidget {
  final FirebaseFirestore _firestoreDB = FirebaseFirestore.instance;
  final String title;

  HomePage({super.key, required this.title});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<FoodType>> _foodTypes;

  @override
  void initState() {super.initState(); _foodTypes = _getFoodTypes();}

  Future<List<FoodType>> _getFoodTypes() async {
    List<FoodType> list = List.empty(growable: true);
    const List<String> foodTypeNames = ["Classic pizzas", "Special pizzas", "Fried", "Sweets", "Drinks"];
    try {
      var result = await widget._firestoreDB.collection("food_types").get();
      for (var doc in result.docs) {
        list.add(FoodType(int.parse(doc.id), foodTypeNames[int.parse(doc.id)], imageUri: doc.data()["image_uri"]));
      }
    } catch (error) {
      if (kDebugMode) print("Error while retrieving food types data:\n$error");
      return List<FoodType>.empty();
    }
    return list;
  }

  Widget _buildMainBody(BuildContext context, AsyncSnapshot<List<FoodType>> snapshot) {
    switch (snapshot.connectionState) {
      case ConnectionState.waiting: {
        return const Column(mainAxisSize: MainAxisSize.max, mainAxisAlignment: MainAxisAlignment.center,
            children: [CupertinoActivityIndicator()]);
      }
      case ConnectionState.done: {
        if(snapshot.hasError) {
          if (kDebugMode) print("Error while retrieving food type data:\n${snapshot.error}");
          return Text("${snapshot.error}");
        }
        if(snapshot.hasData) {
          if (kDebugMode) print(snapshot.data!);
          return ListView.builder(itemCount: snapshot.data!.length, clipBehavior: Clip.hardEdge, itemBuilder: (BuildContext context, int index) {
            return Container(
              decoration: BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(10.0)),
              margin: const EdgeInsets.all(6.0), height: 150.0,
              child: CupertinoButton(
                  color: CupertinoTheme.of(context).primaryColor,
                  padding: EdgeInsets.zero,
                  onPressed: () {Navigator.push(context, CupertinoPageRoute(builder: (context) { return FoodList(snapshot.data![index].typeId);}));},
                  child: Row(
                      mainAxisSize: MainAxisSize.max, mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.0)),
                            clipBehavior: Clip.hardEdge,
                            child: Image.network(snapshot.data![index].imageUri,
                                fit: BoxFit.fill, width: 215.0, height: 150.0,
                                semanticLabel: AppLocalizations.of(context)!.foodTypeNames("${snapshot.data![index].typeId}")
                            )
                        ),
                        Expanded(
                          child: Text(AppLocalizations.of(context)!.foodTypeNames("${snapshot.data![index].typeId}"), textAlign: TextAlign.center, maxLines: 3, style: CupertinoTheme.of(context).textTheme.actionTextStyle),
                        )
                      ]
                  )
              ),
            );
          });
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
        middle: Text(AppLocalizations.of(context)!.titleSelectFoodType, style: CupertinoTheme.of(context).textTheme.navTitleTextStyle),
        backgroundColor: CupertinoTheme.of(context).barBackgroundColor
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(flex: 11,
              child: FutureBuilder(future: _foodTypes, builder: _buildMainBody),
            ),
            Expanded(flex: 1,
              child: CupertinoTabBar(currentIndex: 0, activeColor: CupertinoTheme.of(context).textTheme.navActionTextStyle.color,
                  onTap: _tabBarListener,
                  items: <BottomNavigationBarItem>[
                    BottomNavigationBarItem(
                        icon: Icon(CupertinoIcons.add_circled, semanticLabel: AppLocalizations.of(context)!.titleNewOrder),
                        label: AppLocalizations.of(context)!.titleNewOrder
                    ),
                    BottomNavigationBarItem(
                        icon: Icon(CupertinoIcons.shopping_cart, semanticLabel: AppLocalizations.of(context)!.titleShoppingCart),
                        label: AppLocalizations.of(context)!.titleShoppingCart
                    )
                  ]
              ),
            )
          ]
      )
    );
  }
}

class FoodTypeListTile extends StatelessWidget {
  final FoodType item;

  const FoodTypeListTile(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(10.0)),
      margin: const EdgeInsets.all(6.0), height: 150.0,
      child: CupertinoButton(
          color: CupertinoTheme.of(context).primaryColor,
          padding: EdgeInsets.zero,
          onPressed: () {Navigator.push(context, CupertinoPageRoute(builder: (context) { return FoodList(item.typeId);}));},
          child: Row(
              mainAxisSize: MainAxisSize.max, mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.0)),
                    clipBehavior: Clip.hardEdge,
                    child: Image.network(item.imageUri, fit: BoxFit.fill, semanticLabel: item.name, width: 215.0, height: 150.0)
                ),
                Expanded(
                  child: Text(item.name, textAlign: TextAlign.center, maxLines: 3, style: CupertinoTheme.of(context).textTheme.actionTextStyle),
                )
              ]
          )
      ),
    );
  }
}


