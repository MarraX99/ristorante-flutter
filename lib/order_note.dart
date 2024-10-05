import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class OrderNote extends StatefulWidget {
  final FirebaseFirestore firestoreDB = FirebaseFirestore.instance;
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  OrderNote({super.key});

  @override
  State<OrderNote> createState() => _OrderNoteState();
}

class _OrderNoteState extends State<OrderNote> {
  late final TextEditingController _textController;
  bool _buttonActive = false;

  @override
  void initState() {
    super.initState();
    _getOrderNote().then((onValue) => setState(() => _buttonActive = true));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<String> _getOrderNote() async {
    try {
      var user = await widget.firestoreDB.doc("users/${widget.uid}").get();
      return user.data()!["order_note"];
    } catch(error) {
      if(kDebugMode) print("Error while retrieving order note data\n$error");
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(AppLocalizations.of(context)!.titleAddNote, style: CupertinoTheme.of(context).textTheme.navTitleTextStyle),
        backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
      ),
      child: Column(
        children: [
          FutureBuilder(future: _getOrderNote(), builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
            switch(snapshot.connectionState) {
              case ConnectionState.done: {
                if (snapshot.hasError) _textController = TextEditingController();
                if (snapshot.hasData) _textController = TextEditingController(text: snapshot.data!);
                return Flexible(
                    child: Container(
                      margin: const EdgeInsets.all(12.0),
                      child: CupertinoTextField(
                        controller: _textController,
                        keyboardType: TextInputType.multiline,
                        decoration: BoxDecoration(color: CupertinoTheme.of(context).primaryColor, borderRadius: BorderRadius.circular(10.0)),
                        placeholder: AppLocalizations.of(context)!.placeholderAddNote,
                        maxLines: 10, maxLength: 200,
                        style: CupertinoTheme.of(context).textTheme.textStyle,
                        clearButtonMode: OverlayVisibilityMode.editing,
                        cursorColor: CupertinoTheme.of(context).textTheme.navTitleTextStyle.color
                      )
                    )
                );
              }
              default:return const Align(alignment: Alignment.center, child: CupertinoActivityIndicator());
            }
          }),
          CupertinoButton(
            color: CupertinoTheme.of(context).textTheme.navActionTextStyle.color,
            onPressed: _buttonActive ? () async {
              await widget.firestoreDB.doc("users/${widget.uid}").set({"order_note": _textController.text}, SetOptions(merge: true));
              Navigator.pop(context);
            } : null,
            child: Text(AppLocalizations.of(context)!.titleSave.toUpperCase(), style: CupertinoTheme.of(context).textTheme.actionTextStyle)
          )
        ]
      )
    );
  }
}