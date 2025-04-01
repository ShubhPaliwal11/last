import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'login.dart';
import 'signup.dart';

class OptionsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;
    bool isDesktop = screenSize.width > 600; // Consider width > 600px as desktop

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/desktop_welcome2.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Row(
          mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            // Left side - SVG Image
            if (isDesktop)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 50.0),
                  child: Center(
                    child: SvgPicture.asset(
                      'images/options.svg',
                      width: screenSize.width * 0.35,
                      height: screenSize.height * 0.6,
                      fit: BoxFit.contain,
                      placeholderBuilder: (context) => CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),

            // Right side - Login box
            Padding(
              padding: isDesktop ? EdgeInsets.only(right: 200) : EdgeInsets.zero,
              child: Container(
                width: isDesktop ? 450 : 350, // Adjust width for responsiveness
                padding: EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                  // boxShadow: [
                  //   BoxShadow(
                  //     color: Colors.blueAccent.withOpacity(0.2),
                  //     blurRadius: 10,
                  //     spreadRadius: 2,
                  //   ),
                  // ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Bringing AI to Your Education Journey!\nLogin to Smarter Learning.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isDesktop ? 15 : 12,
                        color: Colors.lightBlue,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Sono',
                      ),
                    ),
                    SizedBox(height: 20),

                    Text(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                        fontFamily: 'Nexa',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),

                    // Login Button
                    _buildRoleButton(context, 'Login', LoginPage(), Colors.blue),
                    SizedBox(height: 15),

                    // Sign Up Prompt
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Not signed up yet? ",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blueGrey,
                            fontFamily: 'Nexa',
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SignupPage()),
                            );
                          },
                          child: Text(
                            "Sign up",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.lightBlueAccent,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Nexa',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to create hoverable button
  Widget _buildRoleButton(BuildContext context, String text, Widget page, Color borderColor) {
    return SizedBox(
      width: double.infinity,
      child: StatefulBuilder(
        builder: (context, setState) {
          bool isHovered = false;
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => page),
              );
            },
            child: MouseRegion(
              onEnter: (_) => setState(() => isHovered = true),
              onExit: (_) => setState(() => isHovered = false),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isHovered ? borderColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: borderColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 20,
                    color: isHovered ? Colors.white : borderColor,
                    fontFamily: 'Nexa',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
