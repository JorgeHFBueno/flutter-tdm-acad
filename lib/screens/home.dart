import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class Home extends StatefulWidget {
  Home();
  @override
  State<Home> createState() {
    return HomeState();
  }
}

class HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 243, 243, 243),
      resizeToAvoidBottomInset: true,
      body: Form(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                SizedBox(
                  height: 200,
                  child: ClipOval(
                    child: Image.asset('assets/logos/logo.jpg'),
                  ),
                ),
                Text(
                  "Título APP",
                  style: GoogleFonts.lobsterTwo(
                      fontSize: 30,
                      color: Colors.teal.shade900,
                      shadows: [
                        BoxShadow(color: Colors.black38, blurRadius: 10)
                      ]),
                ),
                const SizedBox(height: 10),
                Text(
                  'Uma plataforma interativa antibullying.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Conecte-se numa cultura de paz por uma sociedade mais justa!',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
