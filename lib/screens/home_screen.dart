import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_layout.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String username = "User";

  List opportunities = [
    {
      "title": "Python Developer Intern",
      "company": "Infosys",
      "location": "Bangalore",
      "match": 0.95
    },
    {
      "title": "Data Analyst Intern",
      "company": "TCS",
      "location": "Remote",
      "match": 0.90
    },
    {
      "title": "AI/ML Intern",
      "company": "Wipro",
      "location": "Hyderabad",
      "match": 0.92
    },
  ];

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    var doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();

    setState(() {
      username = doc["name"] ?? "User";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Text("CareerConnect", style: TextStyle(fontSize: 20)),
            ),
            ListTile(
              title: Text("Profile"),
              onTap: () {
                Navigator.pushNamed(context, '/profile');
              },
            ),
            ListTile(
              title: Text("Logout"),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: Text("Hello, $username 👋"),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: CircleAvatar(
              child: Icon(Icons.person),
            ),
          )
        ],
      ),

      body: ListView.builder(
        itemCount: opportunities.length,
        itemBuilder: (context, index) {
          var job = opportunities[index];

          return GestureDetector(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/opportunityDetail',
                arguments: job,
              );
            },
            child: Card(
              margin: EdgeInsets.all(10),
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job["title"],
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 5),
                    Text(job["company"]),
                    Text(job["location"]),

                    SizedBox(height: 10),

                    Text(
                      "Match: ${(job["match"] * 100).toInt()}%",
                      style: TextStyle(color: Colors.green),
                    ),

                    SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () {},
                          child: Text("Apply"),
                        ),

                        // 🔥 Ask AI Button
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/aiChat',
                              arguments: job,
                            );
                          },
                          child: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Text("AI"),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}