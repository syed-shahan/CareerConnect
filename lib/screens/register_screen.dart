import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/otp_service.dart';

// One structured entry for the Education section of the resume builder.
class EducationEntry {
  final degree = TextEditingController();
  final institution = TextEditingController();
  final year = TextEditingController();

  bool get isEmpty => degree.text.trim().isEmpty && institution.text.trim().isEmpty;
}

// One structured entry for the Experience section.
class ExperienceEntry {
  final role = TextEditingController();
  final company = TextEditingController();
  final duration = TextEditingController();
  final description = TextEditingController();

  bool get isEmpty => role.text.trim().isEmpty && company.text.trim().isEmpty;
}

// One structured entry for the Projects section.
class ProjectEntry {
  final title = TextEditingController();
  final description = TextEditingController();
  final techStack = TextEditingController();

  bool get isEmpty => title.text.trim().isEmpty;
}

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ---- Step 1: personal details ----
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final phone = TextEditingController();
  final college = TextEditingController();
  final branch = TextEditingController();
  final year = TextEditingController();
  final otpController = TextEditingController();

  int step = 0; // 0 = personal details, 1 = resume details

  bool loading = false;
  bool sendingOtp = false;
  bool verifyingOtp = false;
  bool otpSent = false;
  bool emailVerified = false;

  // ---- Step 2: resume details ----
  final skillInput = TextEditingController();
  final interestInput = TextEditingController();
  List<String> skillsList = [];
  List<String> interestsList = [];

  List<EducationEntry> educationEntries = [EducationEntry()];
  List<ExperienceEntry> experienceEntries = [ExperienceEntry()];
  List<ProjectEntry> projectEntries = [ProjectEntry()];

  // ---------------- OTP logic (unchanged) ----------------

  Future<void> sendOtp() async {
    final emailText = email.text.trim();

    if (emailText.isEmpty || !emailText.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter a valid email address first")),
      );
      return;
    }

    setState(() => sendingOtp = true);

    final result = await OtpService.sendOtp(email: emailText, purpose: "register");

    setState(() {
      sendingOtp = false;
      if (result.success) otpSent = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success ? "Code sent! Check your email inbox." : (result.error ?? "Failed to send code"),
        ),
      ),
    );
  }

  Future<void> verifyOtpCode() async {
    final code = otpController.text.trim();

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter the 6-digit code from your email")),
      );
      return;
    }

    setState(() => verifyingOtp = true);

    final result = await OtpService.verifyOtp(
      email: email.text.trim(),
      code: code,
      purpose: "register",
    );

    setState(() {
      verifyingOtp = false;
      if (result.success) emailVerified = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.success ? "Email verified!" : (result.error ?? "Incorrect code"))),
    );
  }

  void editEmail() {
    setState(() {
      otpSent = false;
      emailVerified = false;
      otpController.clear();
    });
  }

  // ---------------- Step navigation ----------------

  void goToResumeStep() {
    if (!emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please verify your email with the code first")),
      );
      return;
    }

    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter your name")),
      );
      return;
    }

    if (password.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    setState(() => step = 1);
  }

  // ---------------- Chip helpers ----------------

  void addSkill() {
    final value = skillInput.text.trim();
    if (value.isEmpty || skillsList.contains(value)) return;

    setState(() {
      skillsList.add(value);
      skillInput.clear();
    });
  }

  void addInterest() {
    final value = interestInput.text.trim();
    if (value.isEmpty || interestsList.contains(value)) return;

    setState(() {
      interestsList.add(value);
      interestInput.clear();
    });
  }

  // ---------------- Final registration ----------------

  Future<void> register() async {
    try {
      setState(() => loading = true);

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      final uid = cred.user!.uid;

      final educationData = educationEntries
          .where((e) => !e.isEmpty)
          .map((e) => {
                "degree": e.degree.text.trim(),
                "institution": e.institution.text.trim(),
                "year": e.year.text.trim(),
              })
          .toList();

      final experienceData = experienceEntries
          .where((e) => !e.isEmpty)
          .map((e) => {
                "role": e.role.text.trim(),
                "company": e.company.text.trim(),
                "duration": e.duration.text.trim(),
                "description": e.description.text.trim(),
              })
          .toList();

      final projectsData = projectEntries
          .where((e) => !e.isEmpty)
          .map((e) => {
                "title": e.title.text.trim(),
                "description": e.description.text.trim(),
                "techStack": e.techStack.text.trim(),
              })
          .toList();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        "name": name.text.trim(),
        "email": email.text.trim(),
        "phone": phone.text.trim(),
        "college": college.text.trim(),
        "branch": branch.text.trim(),
        "year": year.text.trim(),
        "skills": skillsList.join(", "),
        "interests": interestsList.join(", "),
        "education": educationData,
        "experience": experienceData,
        "projects": projectsData,
        "photoUrl": "",
        "profileImage": "",
        "emailVerified": true,
      });

      print("REGISTER SUCCESS");

      // AuthGate (in main.dart) is listening to auth state and will likely
      // already have swapped to OpportunitiesScreen by the time this runs,
      // since account creation also signs the user in. Guard against
      // navigating/setState-ing on an already-unmounted screen.
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print("REGISTER ERROR: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registration failed")),
        );
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  // ---------------- Small UI helpers ----------------

  Widget input(TextEditingController c, String label,
      {bool isPass = false, int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        obscureText: isPass,
        maxLines: isPass ? 1 : maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget sectionTitle(String title, {VoidCallback? onAdd}) {
    return Padding(
      padding: EdgeInsets.only(top: 18, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (onAdd != null)
            TextButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.add),
              label: Text("Add"),
            ),
        ],
      ),
    );
  }

  Widget chipInputSection(String label, TextEditingController controller,
      List<String> list, VoidCallback onAdd) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onAdd(),
                decoration: InputDecoration(
                  labelText: label,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton(onPressed: onAdd, child: Text("Add")),
          ],
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: list
              .map((item) => Chip(
                    label: Text(item),
                    onDeleted: () => setState(() => list.remove(item)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget educationCard(int index, EducationEntry entry) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Education ${index + 1}", style: TextStyle(fontWeight: FontWeight.bold)),
                if (educationEntries.length > 1)
                  IconButton(
                    icon: Icon(Icons.delete_outline),
                    onPressed: () => setState(() => educationEntries.removeAt(index)),
                  ),
              ],
            ),
            input(entry.degree, "Degree / Course (e.g. B.Tech CSE)"),
            input(entry.institution, "Institution / College"),
            input(entry.year, "Year (e.g. 2022 - 2026)"),
          ],
        ),
      ),
    );
  }

  Widget experienceCard(int index, ExperienceEntry entry) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Experience ${index + 1}", style: TextStyle(fontWeight: FontWeight.bold)),
                if (experienceEntries.length > 1)
                  IconButton(
                    icon: Icon(Icons.delete_outline),
                    onPressed: () => setState(() => experienceEntries.removeAt(index)),
                  ),
              ],
            ),
            input(entry.role, "Role (e.g. Frontend Intern)"),
            input(entry.company, "Company / Organization"),
            input(entry.duration, "Duration (e.g. Jun 2025 - Aug 2025)"),
            input(entry.description, "What did you do? (short description)", maxLines: 3),
          ],
        ),
      ),
    );
  }

  Widget projectCard(int index, ProjectEntry entry) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Project ${index + 1}", style: TextStyle(fontWeight: FontWeight.bold)),
                if (projectEntries.length > 1)
                  IconButton(
                    icon: Icon(Icons.delete_outline),
                    onPressed: () => setState(() => projectEntries.removeAt(index)),
                  ),
              ],
            ),
            input(entry.title, "Project Title"),
            input(entry.description, "What does it do?", maxLines: 3),
            input(entry.techStack, "Tech Used (e.g. Flutter, Firebase)"),
          ],
        ),
      ),
    );
  }

  Widget buildEmailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: email,
                  enabled: !otpSent,
                  decoration: InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                    suffixIcon: emailVerified
                        ? Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  ),
                ),
              ),
              SizedBox(width: 8),
              if (!emailVerified)
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (sendingOtp || otpSent) ? null : sendOtp,
                    child: sendingOtp
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(otpSent ? "Sent" : "Send Code"),
                  ),
                ),
            ],
          ),
        ),
        if (otpSent && !emailVerified)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: "6-digit code",
                      border: OutlineInputBorder(),
                      counterText: "",
                    ),
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: verifyingOtp ? null : verifyOtpCode,
                    child: verifyingOtp
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text("Verify"),
                  ),
                ),
              ],
            ),
          ),
        if (otpSent && !emailVerified)
          TextButton(
            onPressed: editEmail,
            child: Text("Wrong email? Edit it"),
          ),
        if (emailVerified)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              "✓ Email verified",
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget buildStepOne() {
    return Column(
      children: [
        input(name, "Name"),
        buildEmailSection(),
        input(password, "Password", isPass: true),
        input(phone, "Phone", keyboardType: TextInputType.phone),
        input(college, "College"),
        input(branch, "Branch"),
        input(year, "Year"),
        SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: goToResumeStep,
            style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
            child: Text("Next: Resume Details"),
          ),
        ),
      ],
    );
  }

  Widget buildStepTwo() {
    return Column(
      children: [
        Text(
          "Now let's build your resume profile — this powers the AI resume generator later, and you can edit it anytime from your Profile page.",
          style: TextStyle(color: Colors.grey[700]),
        ),
        sectionTitle("Skills"),
        chipInputSection("Add a skill (e.g. Flutter)", skillInput, skillsList, addSkill),
        sectionTitle("Interests"),
        chipInputSection("Add an interest (e.g. Web Development)", interestInput, interestsList, addInterest),
        sectionTitle("Education", onAdd: () => setState(() => educationEntries.add(EducationEntry()))),
        ...educationEntries.asMap().entries.map((e) => educationCard(e.key, e.value)),
        sectionTitle("Experience", onAdd: () => setState(() => experienceEntries.add(ExperienceEntry()))),
        ...experienceEntries.asMap().entries.map((e) => experienceCard(e.key, e.value)),
        sectionTitle("Projects", onAdd: () => setState(() => projectEntries.add(ProjectEntry()))),
        ...projectEntries.asMap().entries.map((e) => projectCard(e.key, e.value)),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => step = 0),
                style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                child: Text("Back"),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: loading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: register,
                      style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                      child: Text("Register"),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(step == 0 ? "Register - Step 1 of 2" : "Register - Step 2 of 2"),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: step == 0 ? buildStepOne() : buildStepTwo(),
      ),
    );
  }
}