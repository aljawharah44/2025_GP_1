import 'package:flutter/material.dart';
import 'get_started_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> images = [
    'assets/images/onboarding1.png',
    'assets/images/onboarding2.png',
  ];

  final List<String> titles = [
    "Welcome to Munir",
    "Smart Assistance for You",
  ];

  final List<String> subtitles = [
    "Your AI-powered companion for easier daily life.",
    "Read text, recognize faces, and get real-time feedback.",
  ];

  void _nextPage() {
    if (_currentPage < images.length - 1) {
      _pageController.nextPage(duration: Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      );
    }
  }

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GetStartedScreen()),
    );
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: Duration(milliseconds: 300), curve: Curves.ease);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        itemCount: images.length,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                /// ✅ الصف العلوي: رقم الصفحة + زر Skip في نفس المستوى
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${index + 1}/${images.length}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        "Skip",
                        style: TextStyle(color: Colors.black, fontSize: 18),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                /// ✅ الصورة
                Expanded(
                  child: Image.asset(
                    images[index],
                    fit: BoxFit.contain,
                  ),
                ),

                /// ✅ العنوان
                Text(
                  titles[index],
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 10),

                /// ✅ الوصف
                Text(
                  subtitles[index],
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 30),

                /// ✅ Row الأزرار + dot indicators في النص
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // زر Previous
                    if (_currentPage > 0)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 219, 219, 219),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: _prevPage,
                        child: Text("Previous"),
                      )
                    else
                      SizedBox(width: 100), // حتى يحافظ على المساحة

                    // dot indicators في النص
                    Row(
                      children: List.generate(images.length, (i) {
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          width: i == _currentPage ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _currentPage ? Color(0xFFB14ABA) : Colors.grey[400],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),

                    // زر Next أو Get Started
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 176, 94, 184),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _nextPage,
                      child: Text(_currentPage == images.length - 1 ? "Get Started" : "Next"),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
