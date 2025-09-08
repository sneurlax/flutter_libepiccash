import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_libmwc/mwc.dart';
import 'package:flutter_libmwc_example/views/transaction_view.dart';
import 'package:flutter_libmwc_example/services/wallet_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class MnemonicView extends StatelessWidget {
  MnemonicView({Key? key, required this.name, required this.password})
      : super(key: key);

  final String name;
  final String password;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet mnemonic',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MwcMnemonicView(
        title: 'Wallet Recovery phrase',
        name: name,
        password: password,
      ),
    );
  }
}

class MwcMnemonicView extends StatefulWidget {
  final String name;
  final String password;

  const MwcMnemonicView(
      {Key? key,
      required this.title,
      required this.name,
      required this.password})
      : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MwcMnemonicView> createState() => _MwcMnemonicView();
}

class _MwcMnemonicView extends State<MwcMnemonicView> {
  var mnemonic = "";
  var walletConfig = "";
  final storage = new FlutterSecureStorage();
  bool _mnemonicLoaded = false;

  // void _getMnemonic() {
  //   final String mnemonicString = walletMnemonic();
  //
  //   setState(() {
  //     mnemonic = mnemonicString;
  //   });
  // }

  String walletDirectory = "";
  Future<String> createFolder(String folderName) async {
    Directory appDocDir = (await getApplicationDocumentsDirectory());
    if (Platform.isIOS) {
      appDocDir = (await getLibraryDirectory());
    }
    String appDocPath = appDocDir.path;
    print("Doc path is $appDocPath");

    final Directory _appDocDir = await getApplicationDocumentsDirectory();
    final Directory _appDocDirFolder =
        Directory('${_appDocDir.path}/$folderName/');

    if (await _appDocDirFolder.exists()) {
      //if folder already exists return path
      return "directory_exists";
    } else {
      //if folder not exists create folder and then return its path
      final Directory _appDocDirNewFolder =
          await _appDocDirFolder.create(recursive: true);

      setState(() {
        walletDirectory = _appDocDirNewFolder.path;
      });
      return _appDocDirNewFolder.path;
    }
  }

  Future<String> _getWalletConfig(name) async {
    var config = {};
    
    // Robust cross-platform path handling using path_provider.
    Directory baseDir;
    if (Platform.isIOS) {
      // On iOS, use Library directory for persistent app data.
      baseDir = await getLibraryDirectory();
    } else if (Platform.isAndroid) {
      // On Android, use application documents directory.
      baseDir = await getApplicationDocumentsDirectory();
    } else {
      // For other platforms (Linux, Windows, macOS), use application documents directory.
      baseDir = await getApplicationDocumentsDirectory();
    }
    
    config["wallet_dir"] = "${baseDir.path}/mwc/$name/";
    print("wallet dir ${config["wallet_dir"]}");
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

  Future<void> _storeConfig(config) async {
    await storage.write(key: "config", value: config);
  }

  Future<void> _loadStoredMnemonic() async {
    if (!_mnemonicLoaded) {
      final storedMnemonic = await WalletService.getWalletMnemonic(widget.name);
      if (storedMnemonic != null && storedMnemonic.isNotEmpty) {
        setState(() {
          mnemonic = storedMnemonic;
          _mnemonicLoaded = true;
        });
        print('Loaded stored mnemonic: ${storedMnemonic.split(' ').length} words');
      } else {
        print('No stored mnemonic found for wallet: ${widget.name}');
        // Only generate new mnemonic if none is stored.
        setState(() {
          mnemonic = walletMnemonic();
          _mnemonicLoaded = true;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStoredMnemonic();
  }

  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              Text("$mnemonic"),
              ElevatedButton(
                onPressed: () async {
                  print('Creating wallet: ${widget.name}');
                  
                  // Use WalletService to create the wallet properly
                  final result = await WalletService.createWallet(
                    walletName: widget.name,
                    password: widget.password,
                    customMnemonic: mnemonic.isEmpty ? null : mnemonic,
                  );

                  if (result.success) {
                    print('Wallet created successfully: ${widget.name}');
                    
                    // Refresh the stored mnemonic to show the final version
                    _mnemonicLoaded = false;
                    await _loadStoredMnemonic();
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TransactionView(
                                password: widget.password,
                              )),
                    );
                  } else {
                    print('Wallet creation failed: ${result.error}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create wallet: ${result.error}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Create Wallet'),
              ),
              // Add TextFormFields and ElevatedButton here.
            ],
          ),
        ));
    return Form(
      key: _formKey,
      child: Column(
        children: <Widget>[
          TextFormField(
            // The validator receives the text that the user has entered.
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter some text';
              }
              return null;
            },
          ),
          ElevatedButton(
            onPressed: () {
              // Validate returns true if the form is valid, or false otherwise.
              if (_formKey.currentState!.validate()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Processing Data')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
