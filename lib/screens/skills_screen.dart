import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SkillsScreen extends StatefulWidget {
  @override
  State<SkillsScreen> createState() =>
      _SkillsScreenState();
}

class _SkillsScreenState
    extends State<SkillsScreen> {

  final TextEditingController skillsController =
      TextEditingController();

  bool isLoading = false;

  Future<void> saveSkills() async {

    String skills =
        skillsController.text.trim();

    if (skills.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    final uid =
        FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .update({

      "skills": skills,
    });

    setState(() {
      isLoading = false;
    });

    Navigator.pushReplacementNamed(
      context,
      '/opportunities',
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: SafeArea(

        child: Padding(

          padding: EdgeInsets.all(24),

          child: Column(

            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              SizedBox(height: 40),

              Text(

                "Add Your Skills",

                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 12),

              Text(

                "These skills help us recommend AI matched opportunities.",

                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),

              SizedBox(height: 30),

              TextField(

                controller: skillsController,

                maxLines: 5,

                decoration: InputDecoration(

                  hintText:
                      "Example:\nFlutter, Firebase, Python, AI, APIs",

                  filled: true,

                  fillColor:
                      Colors.grey.shade100,

                  border:
                      OutlineInputBorder(

                    borderRadius:
                        BorderRadius.circular(16),

                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),

              SizedBox(height: 30),

              SizedBox(

                width: double.infinity,

                height: 55,

                child: ElevatedButton(

                  onPressed:
                      isLoading
                          ? null
                          : saveSkills,

                  style: ElevatedButton.styleFrom(

                    shape:
                        RoundedRectangleBorder(

                      borderRadius:
                          BorderRadius.circular(
                              14),
                    ),
                  ),

                  child: isLoading

                      ? CircularProgressIndicator(
                          color: Colors.white,
                        )

                      : Text(
                          "Continue",
                          style: TextStyle(
                            fontSize: 18,
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
}