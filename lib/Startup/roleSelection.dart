import 'package:flutter/material.dart';
import '../Startup/routes.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Background tiles
            ..._buildBackgroundTiles(),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Decorative image
                  Image.asset(
                    "assets/college.png",
                    height: 225,
                    width: 225,
                  ),

                  const SizedBox(height: 75),

                  const Text(
                    "CHOOSE YOUR ROLE",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF36454F),
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 75),

                  // STUDENT Role Button
                  RoleButton(
                    icon: Image.asset("assets/cap.png", height: 300, width: 30),
                    text: "STUDENT",
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.studentLogin);
                    },
                  ),


                  const SizedBox(height: 20),

                  // FACULTY Role Button
                  RoleButton(
                    icon: Image.asset("assets/stick.png", height: 10000, width: 1000),
                    text: "FACULTY",
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.facultyLogin);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBackgroundTiles() {
    List<Offset> positions = [
      const Offset(180, 0),
      const Offset(260, 100),
      const Offset(350, 70),
      const Offset(35, 45),
      const Offset(85, 130),
      const Offset(0, 230),
      const Offset(340, 230),
      const Offset(365, 430),
      const Offset(90, 400),
    ];

    return positions.map((pos) {
      return Positioned(
        top: pos.dy,
        left: pos.dx,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Color(0xFFD3D3D3).withOpacity(0.15),
          ),
        ),
      );
    }).toList();
  }
}

class RoleButton extends StatelessWidget {
  final Widget icon;
  final String text;
  final VoidCallback onTap;

  const RoleButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF36454F),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 24, height: 24, child: icon),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
