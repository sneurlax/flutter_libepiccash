import 'package:flutter/material.dart';
import 'package:flutter_libmwc_example/views/mnemonic_view.dart';
import 'package:numeric_keyboard/numeric_keyboard.dart';

class PasswordView extends StatelessWidget {
  PasswordView({Key? key, required this.name}) : super(key: key);
  final String name;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MWC wallet',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MwcPasswordView(
        title: 'Please enter password',
        name: name,
      ),
    );
  }
}

class MwcPasswordView extends StatefulWidget {
  final String name;
  const MwcPasswordView({Key? key, required this.title, required this.name})
      : super(key: key);

  final String title;

  @override
  State<MwcPasswordView> createState() => _MwcPasswordView();
}

class _MwcPasswordView extends State<MwcPasswordView> {
  var text = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Please enter password'),
        ),
        body: Center(
          child: NumericKeyboard(
              onKeyboardTap: (String value) {
                print("Pressed");
                print(widget.name);
                setState(() {
                  text = text + value;
                  if (text.length == 4) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => MnemonicView(
                                name: widget.name,
                                password: text,
                              )),
                    );
                  }
                });
              },
              textColor: Colors.red,
              rightButtonFn: () {
                setState(() {
                  text = text.substring(0, text.length - 1);
                });
              },
              rightIcon: Icon(
                Icons.backspace,
                color: Colors.red,
              ),
              leftButtonFn: () {
                print('left button clicked');
                print('$text');
              },
              leftIcon: Icon(
                Icons.check,
                color: Colors.red,
              ),
              mainAxisAlignment: MainAxisAlignment.spaceEvenly),
        ));
  }
}
