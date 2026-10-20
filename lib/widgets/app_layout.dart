import 'package:flutter/material.dart';

class AppLayout extends StatelessWidget {
  final Widget child;

  const AppLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.1,
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.cover,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}