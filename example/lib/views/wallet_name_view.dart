import 'package:flutter/material.dart';
import 'package:flutter_libmwc_example/views/password_view.dart';
import 'package:flutter_libmwc_example/views/recover_view.dart';

class WalletNameView extends StatelessWidget {
  const WalletNameView({Key? key, required this.recover}) : super(key: key);
  final bool recover;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet Name',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MwcWalletNameView(
          title: 'Please enter wallet name', recover: recover),
    );
  }
}

class MwcWalletNameView extends StatefulWidget {
  const MwcWalletNameView(
      {Key? key, required this.title, required this.recover})
      : super(key: key);
  final bool recover;

  final String title;

  @override
  State<MwcWalletNameView> createState() => _MwcWalletNameView();
}

class _MwcWalletNameView extends State<MwcWalletNameView> {
  var name = "";

  void _setWalletName(value) {
    setState(() {
      name = name + value;
    });
  }

  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                // The validator receives the text that the user has entered.
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }

                  _setWalletName(value);

                  return null;
                },
              ),
              ElevatedButton(
                onPressed: () {
                  print("Name is $name");
                  bool isRecover = widget.recover;
                  // Validate returns true if the form is valid, or false otherwise.
                  if (_formKey.currentState!.validate()) {
                    print("Name is still $name");
                    print("Wallet recover is  $isRecover");
                    if (isRecover == true) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => RecoverWalletView(
                                  name: name,
                                )),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => PasswordView(
                                  name: name,
                                )),
                      );
                    }
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
