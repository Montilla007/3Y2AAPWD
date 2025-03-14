import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: AppBar(
            elevation: 0,
            leading: IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              color: const Color(0xFF6750A4),
            ),
            title: const Text(
              'About',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What is Accessability?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.grey,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                "Accessability is an innovative GPS navigation application created as part of a student capstone project to support persons with disabilities (PWD). Designed with inclusivity and accessibility at its core, Accessability aims to empower individuals by providing reliable, user-friendly navigation tools that enhance mobility and independence. Whether navigating city streets, public transportation, or unfamiliar locations, this app is tailored to meet the unique needs of PWD, offering a seamless and supportive experience.\n\nDeveloped by a dedicated student passionate about creating meaningful solutions, Accessability integrates advanced features such as voice-guided navigation, step-free route suggestions, and real-time accessibility updates for paths, buildings, and transit systems. The app's customizable interface ensures it caters to a diverse range of disabilities, making it a versatile and practical tool for everyday use. As a capstone project, Accessability reflects a commitment to leveraging technology to address real-world challenges and improve lives.\n\nAccessability is more than just a navigation tool—it’s a testament to the power of innovation and determination in creating a more inclusive world. By prioritizing safety, accessibility, and convenience, this project aims to redefine mobility for PWD, demonstrating how student-driven initiatives can have a lasting, positive impact.",
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Proponents',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.grey,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (var proponent in [
                    {
                      "name": "Jaydeebryann E. Ang",
                      "role": "Project Manager",
                      "email": "jaes.ang.up@phinmaed.com",
                      "image": "assets/images/others/jaydee.jpg"
                    },
                    {
                      "name": "Janylle A. Borje",
                      "role": "System Analyst",
                      "email": "jaaq.borje.up@phinmaed.com",
                      "image": "assets/images/others/janil.jpg"
                    },
                    {
                      "name": "Jem Harold S. Centino",
                      "role": "System Integrator",
                      "email": "jeso.centino.up@phinmaed.com",
                      "image": "assets/images/others/jem.jpg"
                    },
                    {
                      "name": "Christer Dale M. Reyes",
                      "role": "System Integrator",
                      "email": "chmo.reyes.up@phinmaed.com",
                      "image": "assets/images/others/dale.jpg"
                    },
                    {
                      "name": "Lance Kian F. Flores",
                      "role": "System Integrator",
                      "email": "lafa.flores.up@phinmaed.com",
                      "image": "assets/images/others/kian.png"
                    },
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: AssetImage(proponent['image']!),
                          ),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                proponent['name']!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                '${proponent['role']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                '${proponent['email']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}