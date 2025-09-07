import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TransactionView extends StatelessWidget {
  TransactionView({Key? key, required this.password}) : super(key: key);

  final String password;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet Transactions',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MwcTransactionView(
        title: 'Transactions',
        password: password,
      ),
    );
  }
}

class MwcTransactionView extends StatefulWidget {
  final String password;

  const MwcTransactionView(
      {Key? key, required this.title, required this.password})
      : super(key: key);

  final String title;

  @override
  State<MwcTransactionView> createState() => _MwcTransactionView();
}

class _MwcTransactionView extends State<MwcTransactionView> {
  String walletConfig = "";
  final storage = const FlutterSecureStorage();

  Future<void> _getWalletConfig() async {
    var config = await storage.read(key: "config");
    String strConf = json.encode(config);

    setState(() {
      walletConfig = strConf;
    });
  }

  @override
  Widget build(BuildContext context) {
    _getWalletConfig();
    String password = widget.password;

    // print("Wallet Config");
    // print(json.decode(walletConfig));
    String decodeConfig = json.decode(walletConfig);
    const refreshFromNode = 0;

    String walletInfo = "fixme";
    //  getWalletInfo(decodeConfig, password, refreshFromNode);
    var data = json.decode(walletInfo);

    var total = data['total'].toString();
    var awaitingFinalisation = data['amount_awaiting_finalization'].toString();
    var awaitingConfirmation = data['amount_awaiting_confirmation'].toString();
    var spendable = data['amount_currently_spendable'].toString();
    var locked = data['amount_locked'].toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Text("Total Amount : $total"),
            Text("Amount Awaiting Finalization : $awaitingFinalisation"),
            Text("Amount Awaiting Confirmation : $awaitingConfirmation"),
            Text("Amount Currently Spendable : $spendable"),
            Text("Amount Locked : $locked"),
          ],
        ),
      ),
    );
  }
}
