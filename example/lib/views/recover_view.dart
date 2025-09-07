import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_libmwc/mwc.dart';
import 'package:flutter_libmwc_example/views/transaction_view.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class RecoverWalletView extends StatelessWidget {
  RecoverWalletView({Key? key, required this.name}) : super(key: key);
  final String name;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet Name',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MwcRecoverWalletView(title: 'Recover from mnemonic', name: name),
    );
  }
}

class MwcRecoverWalletView extends StatefulWidget {
  const MwcRecoverWalletView(
      {Key? key, required this.title, required this.name})
      : super(key: key);

  final String name;

  final String title;

  @override
  State<MwcRecoverWalletView> createState() => _MwcRecoverWalletView();
}

class _MwcRecoverWalletView extends State<MwcRecoverWalletView> {
  String mnemonic = "";
  String password = "";
  String walletConfig = "";
  String recoverError = "";
  final storage = new FlutterSecureStorage();

  String walletDirectory = "";
  Future<String> createFolder(String folderName) async {
    Directory appDocDir = (await getApplicationDocumentsDirectory());
    if (Platform.isIOS) {
      appDocDir = (await getLibraryDirectory());
    }
    String appDocPath = appDocDir.path;
    print("Doc path is $appDocPath");

    Directory _appDocDir = (await getApplicationDocumentsDirectory());
    if (Platform.isIOS) {
      _appDocDir = (await getLibraryDirectory());
    }
    final Directory _appDocDirFolder =
        Directory('${_appDocDir.path}/$folderName/');

    if (await _appDocDirFolder.exists()) {
      // If folder already exists, return path.
      return "directory_exists";
    } else {
      // If folder not exists create folder and then return its path.
      final Directory _appDocDirNewFolder =
          await _appDocDirFolder.create(recursive: true);

      setState(() {
        walletDirectory = _appDocDirNewFolder.path;
      });
      return _appDocDirNewFolder.path;
    }
  }

  String _getWalletConfig(name) {
    var config = {};
    config["wallet_dir"] =
        "/data/user/0/com.example.flutter_libmwc_example/app_flutter/$name/";
    config["check_node_api_http_addr"] = "https://mwc713.mwc.mw:443";
    config["chain"] = "mainnet";
    config["account"] = "default";
    config["api_listen_port"] = 443;
    config["api_listen_interface"] = "mwc713.mwc.mw";

    String strConf = json.encode(config);
    return strConf;
  }

  bool _createWalletFolder(name) {
    // String nameToLower = name.
    createFolder(name.toLowerCase()).then((value) {
      if (value == "directory_exists") {
        return false;
      }
    });
    return true;
  }

  void _setMnemonic(value) {
    mnemonic = mnemonic + value;
  }

  void _setPassword(value) {
    print("Set password");
    setState(() {
      password = password + value;
    });
  }

  void _setRecoverError(value) {
    setState(() {
      recoverError = value;
    });
  }

  Future<void> _storeConfig(config) async {
    await storage.write(key: "config", value: config);
  }

  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    String name = widget.name;
    _createWalletFolder(name);

    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              Text(recoverError),
              TextFormField(
                decoration: InputDecoration(hintText: name),
                enabled: false,
              ),
              TextFormField(
                decoration: InputDecoration(hintText: "Recovery string"),
                maxLines: 10,
                // The validator receives the text that the user has entered.
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter wallet phrase';
                  }
                  _setMnemonic(value);
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(hintText: "Wallet Password"),
                // The validator receives the text that the user has entered.
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter wallet password';
                  }
                  _setPassword(value);
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: () {
                  // Validate returns true if the form is valid, or false otherwise.
                  if (_formKey.currentState!.validate()) {
                    String walletMnemonic = mnemonic;
                    String walletPassword = password;
                    String walletConfig = _getWalletConfig(name);

                    // String strConf = json.encode(walletConfig);
                    String recover =
                        recoverWallet(walletConfig, password, mnemonic, name);

                    if (recover == "recovered") {
                      _storeConfig(walletConfig);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TransactionView(
                                  password: password,
                                )),
                      );
                    } else {
                      _setRecoverError(recover);
                    }
                    // Store config and password in secure storage since we will need them again.
                  }
                },
                child: const Text('Next'),
              ),
              // Add TextFormFields and ElevatedButton here.
            ],
          ),
        ));
  }
}
