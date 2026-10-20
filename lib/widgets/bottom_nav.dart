import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int index;

  const BottomNav({required this.index});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: index,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      onTap: (i) {
        if (i == 0) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          Navigator.pushReplacementNamed(context, '/profile');
        }
      },
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.work), label: "Jobs"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}