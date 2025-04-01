import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'option.dart';

class WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Determine screen size
    var screenSize = MediaQuery
        .of(context)
        .size;
    bool isDesktop = screenSize.width >
        600; // Consider width > 600px as desktop

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                isDesktop
                    ? 'images/desktop_welcome2.jpg'
                    : 'images/desktop_welcome2.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: isDesktop
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Padding(
                padding: isDesktop ? EdgeInsets.only(left: 70) : EdgeInsets
                    .zero,
                child: Container(
                  width: 500,
                  height: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'EduAssist',
                        style: TextStyle(
                          fontSize: isDesktop ? 70 : 52,
                          color: Colors.white,
                          fontFamily: 'Game',
                        ),
                      ),
                      SizedBox(height: 0),
                      Padding(
                        padding: EdgeInsets.only(left: isDesktop ? 18 : 20),
                        child: Text(
                          'Your AI-Powered Classroom Companion with \nLess Paperwork and more Teaching...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: isDesktop ? 15 : 12,
                              color: Colors.lightBlue,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Sono'
                          ),
                        ),
                      ),
                      SizedBox(height: isDesktop ? 30 : 15),
                      Text(
                        'Continue as a Teacher or a Student?',
                        style: TextStyle(
                            fontSize: isDesktop ? 24 : 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Nexa'
                        ),
                      ),
                      SizedBox(height: 20),

                      // Teacher Button
                      _buildRoleButton(context, 'Teacher', OptionsPage()),

                      SizedBox(height: 10),

                      // Student Button
                      _buildRoleButton(context, 'Student', OptionsPage()),
                    ],
                  ),
                ),
              ),

              // Responsive SVG Image
              if (isDesktop)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 50.0),
                    child: Center(
                      child: SvgPicture.asset(
                        'images/desktop_welcome3.svg',
                        width: screenSize.width * 0.35,
                        // Adjust width based on screen size
                        height: screenSize.height * 0.6,
                        // Adjust height based on screen size
                        fit: BoxFit.contain,
                        placeholderBuilder: (context) =>
                            CircularProgressIndicator(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper function to create a hoverable button
// Helper function to create a hoverable button
  Widget _buildRoleButton(BuildContext context, String role, Widget page) {
    return SizedBox(
      width: 220,
      child: StatefulBuilder(
        builder: (context, setState) {
          bool isHovered = false;
          return GestureDetector( // Make entire button tappable
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
                padding: EdgeInsets.symmetric(vertical: 12),
                // Adjusted padding
                decoration: BoxDecoration(
                  color: isHovered ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  role,
                  style: TextStyle(
                    fontSize: 20,
                    color: isHovered ? Colors.white : Colors.blue,
                    fontFamily: 'Nexa',
                    fontWeight: FontWeight.w100,
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
