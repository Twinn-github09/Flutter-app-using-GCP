import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:html/parser.dart' as html_parser;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cat or Dog',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Cat or Dog'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _image;
  final picker = ImagePicker();
  String _prediction = '';
  String _percentage = '';
  String _error = '';

  Future getImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      } else {
        print('No image selected.');
      }
    });
  }

  Future uploadImage(File imageFile) async {
    try {
      var stream = http.ByteStream(imageFile.openRead());
      var length = await imageFile.length();
      var uri = Uri.parse("https://my-repo-lgcs2dkt6a-uc.a.run.app/upload");

      var request = http.MultipartRequest("POST", uri);
      var multipartFile = http.MultipartFile('photo', stream, length,
          filename: path.basename(imageFile.path));

      request.files.add(multipartFile);
      var response = await request.send();

      var responseData = await http.Response.fromStream(response);

      print('Response Status: ${responseData.statusCode}');
      print('Response Headers: ${responseData.headers}');
      print('Response Body: ${responseData.body}');

      if (responseData.statusCode == 200) {
        if (responseData.headers['content-type']?.contains('text/html') ?? false) {
          try {
            var document = html_parser.parse(responseData.body);

            // Debug: Print the entire parsed HTML document
            print('Parsed HTML Document:');
            print(document.outerHtml);

            var pElements = document.querySelectorAll('p');
            if (pElements.length >= 2) {
              var predictionElement = pElements[0].querySelector('strong');
              var percentageElement = pElements[1].querySelector('strong');

              if (predictionElement != null && percentageElement != null) {
                setState(() {
                  _prediction = predictionElement.text;
                  _percentage = percentageElement.text;
                  _error = '';
                });
              } else {
                setState(() {
                  _error = 'Could not find prediction or percentage in the response.';
                });
              }
            } else {
              setState(() {
                _error = 'Could not find enough <p> elements in the response.';
              });
            }
          } catch (e) {
            setState(() {
              _error = 'Error parsing HTML response: $e';
            });
          }
        } else {
          setState(() {
            _error = 'Unexpected content type: ${responseData.headers['content-type']}';
          });
        }
      } else {
        setState(() {
          _error = 'Server error: ${responseData.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error uploading image: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _image == null
                ? Text('No image selected.')
                : Image.file(_image!),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: getImage,
              child: Text('Pick Image'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_image != null) {
                  uploadImage(_image!);
                }
              },
              child: Text('Upload Image'),
            ),
            SizedBox(height: 20),
            Text(
              _error.isNotEmpty
                  ? 'Error: $_error'
                  : _prediction.isEmpty
                      ? ''
                      : 'Prediction: $_prediction\nConfidence: $_percentage',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
