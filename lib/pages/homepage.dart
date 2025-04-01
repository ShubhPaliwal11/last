import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/material.dart';
class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String stringOutput = "Text Output";
  final TextEditingController _textController = TextEditingController();

  void geminiOutput() async {
    if (_textController.text.isEmpty) {
      return;
    }
    final content = [Content.text(_textController.text)];
    final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: "AIzaSyB5Scfwg7YUuBVwsqJpJCkbVbCEv7pHCv8");
    final response = await model.generateContent(content);
    print(response.text);

    setState(() {
      stringOutput = response.text!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Demo App"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
                child: SingleChildScrollView(
              child: Text(
                stringOutput,
              ),
            )),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: "Enter text",
              ),
              onChanged: (value) {
                setState(() {
                  print(_textController.text);
                });
              },
            ),
          ],
        ),
      ),
      floatingActionButton: ElevatedButton(
        onPressed: geminiOutput,
        child: Text("Gemini Api"),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
