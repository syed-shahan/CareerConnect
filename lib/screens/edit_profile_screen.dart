import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/otp_service.dart';
import 'register_screen.dart' show EducationEntry, ExperienceEntry, ProjectEntry;
class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}
class _EditProfileScreenState extends State<EditProfileScreen> {
  bool loading = true;
  bool saving = false;
  String userEmail = "";
  String? profilePhotoUrl;
  bool uploadingPhoto = false;
  final name = TextEditingController();
  final phone = TextEditingController();
  final college = TextEditingController();
  final branch = TextEditingController();
  final year = TextEditingController();
  final skillInput = TextEditingController();
  final interestInput = TextEditingController();
  List<String> skillsList = [];
  List<String> interestsList = [];
  List<EducationEntry> educationEntries = [EducationEntry()];
  List<ExperienceEntry> experienceEntries = [ExperienceEntry()];
  List<ProjectEntry> projectEntries = [ProjectEntry()];
  bool otpSent = false;
  bool sendingOtp = false;
  bool verifyingOtp = false;
  final otpController = TextEditingController();
  @override
  void initState() {
    super.initState();
    loadProfile();
  }
  Future<void> loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    name.text = (data["name"] ?? "").toString();
    userEmail = (data["email"] ?? "").toString();
    phone.text = (data["phone"] ?? "").toString();
    college.text = (data["college"] ?? "").toString();
    branch.text = (data["branch"] ?? data["department"] ?? "").toString();
    year.text = (data["year"] ?? "").toString();
    profilePhotoUrl = (data["photoUrl"] ?? data["profileImage"] ?? data["profilePhotoUrl"] ?? "").toString();
    if (profilePhotoUrl!.isEmpty) profilePhotoUrl = null;
    skillsList = (data["skills"] ?? "")
        .toString()
        .split(",")
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    interestsList = (data["interests"] ?? "")
        .toString()
        .split(",")
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final educationRaw = (data["education"] is List) ? data["education"] as List : [];
    if (educationRaw.isNotEmpty) {
      educationEntries = educationRaw.map((raw) {
        final e = Map<String, dynamic>.from(raw as Map);
        final entry = EducationEntry();
        entry.degree.text = (e["degree"] ?? "").toString();
        entry.institution.text = (e["institution"] ?? "").toString();
        entry.year.text = (e["year"] ?? "").toString();
        return entry;
      }).toList();
    }
    final experienceRaw = (data["experience"] is List) ? data["experience"] as List : [];
    if (experienceRaw.isNotEmpty) {
      experienceEntries = experienceRaw.map((raw) {
        final e = Map<String, dynamic>.from(raw as Map);
        final entry = ExperienceEntry();
        entry.role.text = (e["role"] ?? "").toString();
        entry.company.text = (e["company"] ?? "").toString();
        entry.duration.text = (e["duration"] ?? "").toString();
        entry.description.text = (e["description"] ?? "").toString();
        return entry;
      }).toList();
    }
    final projectsRaw = (data["projects"] is List) ? data["projects"] as List : [];
    if (projectsRaw.isNotEmpty) {
      projectEntries = projectsRaw.map((raw) {
        final e = Map<String, dynamic>.from(raw as Map);
        final entry = ProjectEntry();
        entry.title.text = (e["title"] ?? "").toString();
        entry.description.text = (e["description"] ?? "").toString();
        entry.techStack.text = (e["techStack"] ?? "").toString();
        return entry;
      }).toList();
    }
    setState(() => loading = false);
  }
  Future<void> pickAndUploadProfilePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (image == null) return;
    setState(() => uploadingPhoto = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance
          .ref()
          .child("profile_photos")
          .child("$uid.jpg");
      await ref.putData(
        await image.readAsBytes(),
        SettableMetadata(contentType: "image/jpeg"),
      );
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        "photoUrl": url,
        "profileImage": url,
      });
      if (mounted) {
        setState(() {
          profilePhotoUrl = url;
          uploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profile photo updated")),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload profile photo")),
        );
      }
    }
  }
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
  Future<void> requestCommit() async {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Name cannot be empty")),
      );
      return;
    }
    setState(() => sendingOtp = true);
    final result = await OtpService.sendOtp(email: userEmail, purpose: "edit");
    setState(() {
      sendingOtp = false;
      if (result.success) otpSent = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? "Code sent to $userEmail to confirm these changes"
              : (result.error ?? "Failed to send code"),
        ),
      ),
    );
  }
  Future<void> verifyAndSave() async {
    final code = otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter the 6-digit code from your email")),
      );
      return;
    }
    setState(() => verifyingOtp = true);
    final result = await OtpService.verifyOtp(email: userEmail, code: code, purpose: "edit");
    if (!result.success) {
      setState(() => verifyingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? "Incorrect code")),
      );
      return;
    }
    setState(() => saving = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
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
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        "photoUrl": profilePhotoUrl,
        "profileImage": profilePhotoUrl,
        "name": name.text.trim(),
        "phone": phone.text.trim(),
        "college": college.text.trim(),
        "branch": branch.text.trim(),
        "year": year.text.trim(),
        "skills": skillsList.join(", "),
        "interests": interestsList.join(", "),
        "education": educationData,
        "experience": experienceData,
        "projects": projectsData,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        saving = false;
        verifyingOtp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save changes")),
      );
    }
  }
  Widget input(TextEditingController c, String label,
      {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
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
            TextButton.icon(onPressed: onAdd, icon: Icon(Icons.add), label: Text("Add")),
        ],
      ),
    );
  }
  Widget chipInputSection(
      String label, TextEditingController controller, List<String> list, VoidCallback onAdd) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onAdd(),
                decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
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
            input(entry.degree, "Degree / Course"),
            input(entry.institution, "Institution / College"),
            input(entry.year, "Year"),
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
            input(entry.role, "Role"),
            input(entry.company, "Company / Organization"),
            input(entry.duration, "Duration"),
            input(entry.description, "Description", maxLines: 3),
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
            input(entry.techStack, "Tech Used"),
          ],
        ),
      ),
    );
  }
  Widget buildCommitSection() {
    if (!otpSent) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: sendingOtp ? null : requestCommit,
          style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
          child: sendingOtp
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text("Commit Changes"),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Enter the code sent to $userEmail to confirm these changes"),
        SizedBox(height: 8),
        TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: "6-digit code",
            border: OutlineInputBorder(),
            counterText: "",
          ),
        ),
        SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (verifyingOtp || saving) ? null : verifyAndSave,
            style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
            child: (verifyingOtp || saving)
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text("Verify & Commit Changes"),
          ),
        ),
        TextButton(
          onPressed: () => setState(() {
            otpSent = false;
            otpController.clear();
          }),
          child: Text("Cancel"),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Edit Profile")),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: profilePhotoUrl != null
                              ? NetworkImage(profilePhotoUrl!)
                              : null,
                          child: profilePhotoUrl == null
                              ? Icon(Icons.person, size: 52, color: Colors.grey.shade600)
                              : null,
                        ),
                        Material(
                          color: Theme.of(context).colorScheme.primary,
                          shape: CircleBorder(),
                          child: InkWell(
                            customBorder: CircleBorder(),
                            onTap: uploadingPhoto ? null : pickAndUploadProfilePhoto,
                            child: Padding(
                              padding: EdgeInsets.all(9),
                              child: uploadingPhoto
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      Icons.camera_alt,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: uploadingPhoto ? null : pickAndUploadProfilePhoto,
                    icon: Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      profilePhotoUrl == null
                          ? "Add Profile Photo"
                          : "Change Profile Photo",
                    ),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Email: $userEmail (cannot be changed)",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                  input(name, "Name"),
                  input(phone, "Phone", keyboardType: TextInputType.phone),
                  input(college, "College"),
                  input(branch, "Branch"),
                  input(year, "Year"),
                  sectionTitle("Skills"),
                  chipInputSection("Add a skill", skillInput, skillsList, addSkill),
                  sectionTitle("Interests"),
                  chipInputSection("Add an interest", interestInput, interestsList, addInterest),
                  sectionTitle("Education",
                      onAdd: () => setState(() => educationEntries.add(EducationEntry()))),
                  ...educationEntries.asMap().entries.map((e) => educationCard(e.key, e.value)),
                  sectionTitle("Experience",
                      onAdd: () => setState(() => experienceEntries.add(ExperienceEntry()))),
                  ...experienceEntries.asMap().entries.map((e) => experienceCard(e.key, e.value)),
                  sectionTitle("Projects",
                      onAdd: () => setState(() => projectEntries.add(ProjectEntry()))),
                  ...projectEntries.asMap().entries.map((e) => projectCard(e.key, e.value)),
                  SizedBox(height: 20),
                  buildCommitSection(),
                  SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}