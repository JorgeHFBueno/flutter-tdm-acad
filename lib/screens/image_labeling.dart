import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ImageLabelingScreen extends StatefulWidget {
  const ImageLabelingScreen({Key? key}) : super(key: key);

  @override
  State<ImageLabelingScreen> createState() => _ImageLabelingScreenState();
}

class _ImageLabelingScreenState extends State<ImageLabelingScreen> {
  InputImage? inputImage;
  bool isScanning = false;
  XFile? imageFile;
  String result = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green,
          title: const Text('Image Labeling in Flutter App'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              imageFile == null
                  ? Container(
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 2.0),
                    borderRadius: BorderRadius.circular(8.0)),
                width: 200,
                height: 200,
                child: Image.asset('assets/placeholder.png'),
              )
                  : Image.file(File(imageFile!.path)),
              const SizedBox(
                height: 40.0,
              ),
              Text(result),
              const SizedBox(
                height: 40.0,
              ),
              SizedBox(
                  width: MediaQuery.of(context).size.width / 2,
                  child: ElevatedButton(
                      onPressed: () {
                        showImageSourceDialog(context);
                      },
                      child: Text("Start")))
            ],
          ),
        ));
  }

  void pickImage(ImageSource source) async {
    var pickedImage = await ImagePicker()
        .pickImage(source: source, maxHeight: 200, maxWidth: 200);
    Navigator.of(context).pop();
    try {
      if (pickedImage != null) {
        imageFile = pickedImage;
        setState(() {});
        processImage(pickedImage);
      }
    } catch (e) {
      isScanning = false;
      imageFile = null;
      result = "Error!!";
      setState(() {});
      debugPrint("Exception $e");
    }
  }

  Future<void> processImage(XFile image) async {
    final inputImage = InputImage.fromFilePath(image.path);
    ImageLabeler imageLabeler =
    ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.75));
    List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
    StringBuffer sb = StringBuffer();
    for (ImageLabel imgLabel in labels) {
      String lblText = imgLabel.label;
      double confidence = imgLabel.confidence;
      sb.write(lblText);
      sb.write(" : ");
      sb.write((confidence * 100).toStringAsFixed(2));
      sb.write("%\n");
    }
    imageLabeler.close();
    result = sb.toString();
    isScanning = false;
    setState(() {});
  }

  showImageSourceDialog(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Select Image From",
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
              ),
              GestureDetector(
                onTap: () {
                  pickImage(ImageSource.gallery);
                },
                child: const ListTile(
                  leading: Icon(Icons.photo),
                  title: Text('Gallery'),
                ),
              ),
              GestureDetector(
                onTap: () {
                  pickImage(ImageSource.camera);
                },
                child: const ListTile(
                  leading: Icon(Icons.camera),
                  title: Text('Camera'),
                ),
              ),
            ],
          );
        });
  }
}