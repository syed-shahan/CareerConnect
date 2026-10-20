import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/otp_service.dart';
import '../widgets/app_layout.dart';
import '../widgets/bottom_nav.dart';
class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}
class _ProfileScreenState extends State<ProfileScreen> {
  bool loading = true;
  String name = "";
  String email = "";
  String phone = "";
  String college = "";
  String branch = "";
  String year = "";
  String profileImage = "";
  List<String> skills = [];
  List<String> interests = [];
  List<dynamic> education = [];
  List<dynamic> experience = [];
  List<dynamic> projects = [];
  // ---- Delete-account flow ----
  bool showDeleteFlow = false;
  bool deleteOtpSent = false;
  bool sendingDeleteOtp = false;
  bool deletingAccount = false;
  final deleteOtpController = TextEditingController();
  @override
  void initState() {
    super.initState();
    loadProfile();
  }
  Future<void> loadProfile() async {
    setState(() => loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    setState(() {
      name = (data["name"] ?? "").toString();
      email = (data["email"] ?? "").toString();
      phone = (data["phone"] ?? "").toString();
      college = (data["college"] ?? "").toString();
      branch = (data["branch"] ?? data["department"] ?? "").toString();
      year = (data["year"] ?? "").toString();
      profileImage = (data["profileImage"] ?? data["photoUrl"] ?? "").toString();
      skills = (data["skills"] ?? "")
          .toString()
          .split(",")
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      interests = (data["interests"] ?? "")
          .toString()
          .split(",")
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      education = (data["education"] is List) ? data["education"] : [];
      experience = (data["experience"] is List) ? data["experience"] : [];
      projects = (data["projects"] is List) ? data["projects"] : [];
      loading = false;
    });
  }
  Future<void> logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Log out?"),
        content: Text("You'll need to log in again to access your account."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Log out")),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
  Future<void> openEditProfile() async {
    final result = await Navigator.pushNamed(context, '/edit_profile');
    if (result == true) {
      loadProfile();
    }
  }
  Future<void> sendDeleteOtp() async {
    setState(() => sendingDeleteOtp = true);
    final result = await OtpService.sendOtp(email: email, purpose: "delete");
    setState(() {
      sendingDeleteOtp = false;
      if (result.success) deleteOtpSent = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success ? "Code sent to $email" : (result.error ?? "Failed to send code"),
        ),
      ),
    );
  }
  Future<void> confirmDeleteAccount() async {
    final code = deleteOtpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter the 6-digit code from your email")),
      );
      return;
    }
    setState(() => deletingAccount = true);
    final result = await OtpService.verifyOtp(email: email, code: code, purpose: "delete");
    if (!result.success) {
      setState(() => deletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? "Incorrect code")),
      );
      return;
    }
    // Account and Firestore data are already gone on the backend at this
    // point. Just clean up the local session and leave.
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
  // ---------------- UI helpers ----------------
  Widget sectionCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
  Widget infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "Not specified" : value,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
  Widget chipList(List<String> items) {
    if (items.isEmpty) {
      return Text("Not specified", style: TextStyle(color: Colors.grey[500]));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: items
          .map((item) => Chip(
                label: Text(item),
                backgroundColor: Colors.blue.withOpacity(0.08),
              ))
          .toList(),
    );
  }
  Widget entryList(List<dynamic> entries, List<String> fieldOrder, String emptyText) {
    if (entries.isEmpty) {
      return Text(emptyText, style: TextStyle(color: Colors.grey[500]));
    }
    return Column(
      children: entries.map((raw) {
        final entry = Map<String, dynamic>.from(raw as Map);
        return Container(
          margin: EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fieldOrder
                .where((f) => (entry[f] ?? "").toString().trim().isNotEmpty)
                .map((f) => Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: Text((entry[f] ?? "").toString()),
                    ))
                .toList(),
          ),
        );
      }).toList(),
    );
  }
  Widget buildDeleteSection() {
    if (!showDeleteFlow) {
      return TextButton.icon(
        onPressed: () => setState(() => showDeleteFlow = true),
        icon: Icon(Icons.delete_forever, color: Colors.red),
        label: Text("Delete Account", style: TextStyle(color: Colors.red)),
      );
    }
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "This permanently deletes your account and all your data. This cannot be undone.",
            style: TextStyle(color: Colors.red[800]),
          ),
          SizedBox(height: 10),
          if (!deleteOtpSent)
            Row(
              children: [
                ElevatedButton(
                  onPressed: sendingDeleteOtp ? null : sendDeleteOtp,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: sendingDeleteOtp
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text("Send Verification Code"),
                ),
                SizedBox(width: 10),
                TextButton(
                  onPressed: () => setState(() => showDeleteFlow = false),
                  child: Text("Cancel"),
                ),
              ],
            ),
          if (deleteOtpSent)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Enter the code sent to $email"),
                SizedBox(height: 8),
                TextField(
                  controller: deleteOtpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    counterText: "",
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: deletingAccount ? null : confirmDeleteAccount,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: deletingAccount
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text("Confirm Permanent Delete"),
                    ),
                    SizedBox(width: 10),
                    TextButton(
                      onPressed: () => setState(() {
                        showDeleteFlow = false;
                        deleteOtpSent = false;
                        deleteOtpController.clear();
                      }),
                      child: Text("Cancel"),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNav(index: 1),
      body: AppLayout(
        child: loading
            ? Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadProfile,
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage:
                                profileImage.isNotEmpty ? NetworkImage(profileImage) : null,
                            child: profileImage.isEmpty
                                ? Icon(Icons.person, size: 44, color: Colors.blue)
                                : null,
                          ),
                          SizedBox(height: 10),
                          Text(
                            name.isEmpty ? "Unnamed User" : name,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(email, style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    sectionCard(
                      "Personal Details",
                      Column(
                        children: [
                          infoRow("Phone", phone),
                          infoRow("College", college),
                          infoRow("Branch", branch),
                          infoRow("Year", year),
                        ],
                      ),
                    ),
                    sectionCard("Skills", chipList(skills)),
                    sectionCard("Interests", chipList(interests)),
                    sectionCard(
                      "Education",
                      entryList(education, ["degree", "institution", "year"], "No education added yet"),
                    ),
                    sectionCard(
                      "Experience",
                      entryList(
                        experience,
                        ["role", "company", "duration", "description"],
                        "No experience added yet",
                      ),
                    ),
                    sectionCard(
                      "Projects",
                      entryList(
                        projects,
                        ["title", "description", "techStack"],
                        "No projects added yet",
                      ),
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: openEditProfile,
                        icon: Icon(Icons.edit),
                        label: Text("Edit Profile"),
                        style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: logout,
                        icon: Icon(Icons.logout),
                        label: Text("Log Out"),
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    SizedBox(height: 20),
                    Center(child: buildDeleteSection()),
                    SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}