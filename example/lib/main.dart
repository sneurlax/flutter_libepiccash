import 'package:flutter/material.dart';
import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'dart:ffi';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_libepiccash/flutter_libepiccash.dart';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:flutter_libepiccash/epic_cash.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  print("CALLING FUNCTION >>>>> MAIN");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
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
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  final greeting = "";

  Future<String> createFolder(String folderName) async {
    io.Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    print(appDocPath);

    final io.Directory _appDocDir = await getApplicationDocumentsDirectory();
    final io.Directory _appDocDirFolder =
        io.Directory('${_appDocDir.path}/$folderName/');

    if (await _appDocDirFolder.exists()) {
      //if folder already exists return path
      return _appDocDirFolder.path;
    } else {
      //if folder not exists create folder and then return its path
      final io.Directory _appDocDirNewFolder =
          await _appDocDirFolder.create(recursive: true);
      return _appDocDirNewFolder.path;
    }
  }

  void _incrementCounter() {
    // final String nameStr = "John Smith";
    // final Pointer<Utf8> charPointer = nameStr.toNativeUtf8();
    // print("- Calling rust_greeting with argument:  $charPointer");
    //
    // final Pointer<Utf8> resultPtr = rustGreeting(charPointer);
    // print("- Result pointer:  $resultPtr");
    //
    // final String greetingStr = resultPtr.toDartString();
    // print("- Response string:  $greetingStr");

    final Pointer<Utf8> mnemonicPtr = walletMnemonic();
    print("- Result pointer:  $mnemonicPtr");

    final String mnemonicString = mnemonicPtr.toDartString();
    print("- Mnemonic string:  $mnemonicString");

    // final Pointer<Utf8> walletInitPtr = initWallet();
    //
    // final String walletInitString = walletInitPtr.toDartString();
    // print("- Mnemonic string:  $walletInitString");

    var config = {};
    config["wallet_dir"] =
        "/data/user/0/com.example.flutter_libepiccash_example/app_flutter/test/";
    config["check_node_api_http_addr"] = "http://95.216.215.107:3413";
    config["chain"] = "mainnet";
    config["account"] = "default";
    config["api_listen_port"] = 3413;
    config["api_listen_interface"] = "95.216.215.107";

    String strConf = json.encode(config);
    final Pointer<Utf8> configPointer = strConf.toNativeUtf8();

    final String strMnemonic = mnemonicString;
    final Pointer<Utf8> mnemonicPointer = strMnemonic.toNativeUtf8();
    const String strPassword = "58498542";
    final Pointer<Utf8> passwordPointer = strPassword.toNativeUtf8();

    const String strName = "EpicStack";
    final Pointer<Utf8> namePointer = strName.toNativeUtf8();

    print("- Calling wallet_init with arguments:");

    final Pointer<Utf8> initWalletPtr = initWallet(
        configPointer, mnemonicPointer, passwordPointer, namePointer);
    print("- Result pointer:  $initWalletPtr");

    final String initWalletStr = initWalletPtr.toDartString();
    print("- Response string:  $initWalletStr");

    final Pointer<Utf8> walletInfoPtr =
        walletInfo(configPointer, passwordPointer);
    final String walletInfoStr = walletInfoPtr.toDartString();
    print("Wallet balances info is : $walletInfoStr");

    // const String recoveryPhrase =
    //     "leave rally pen marble wheat sell lumber asset wall blast later empty tape meat lady east expect badge cancel trust mosquito base trim marine";
    // final Pointer<Utf8> recoveryPhrasePointer = recoveryPhrase.toNativeUtf8();
    // final Pointer<Utf8> recoverWalletPtr =
    //     recoverWallet(configPointer, passwordPointer, recoveryPhrasePointer);
    // final String recoverWalletStr = recoverWalletPtr.toDartString();
    // print("Wallet recover is : $recoverWalletStr");
    // print("Wallet info now is : $walletInfoStr");

    final Pointer<Utf8> walletPhrasePtr =
        walletPhrase(configPointer, passwordPointer);
    final String walletPhraseStr = walletPhrasePtr.toDartString();
    print("Recovery phrase is  : $walletPhraseStr");

    final Pointer<Utf8> scanOutputsPtr =
        scanOutPuts(configPointer, passwordPointer);
    final String scanOutputsStr = scanOutputsPtr.toDartString();

    print("Calling wallet scanner  : $scanOutputsStr");

    // createFolder("test").then((value) {
    //   print(value);
    // });

    setState(() {
      // greeting = $gre
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
