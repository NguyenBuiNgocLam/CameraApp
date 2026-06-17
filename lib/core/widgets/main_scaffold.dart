import 'package:flutter/material.dart';

import '../../app/routes.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({
    required this.currentIndex,
    required this.child,
    this.appBar,
    super.key,
  });

  final int currentIndex;
  final Widget child;
  final PreferredSizeWidget? appBar;

  static const _routes = [
    AppRoutes.home,
    AppRoutes.scan,
    AppRoutes.vocabulary,
    AppRoutes.dictationHome,
    AppRoutes.profile,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: SafeArea(child: child),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex) return;
          Navigator.pushReplacementNamed(context, _routes[index]);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_rounded),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Vocabulary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.subtitles_rounded),
            label: 'Dictation',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
