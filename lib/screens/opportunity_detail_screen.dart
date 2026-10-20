import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/resume_service.dart';

class OpportunityDetailScreen extends StatefulWidget {
  @override
  _OpportunityDetailScreenState createState() => _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  bool generatingResume = false;

  String? _value(Map<String, dynamic> job, String key) {
    final value = job[key];
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is List) {
      final items = value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty);
      return items.isEmpty ? null : items.join(", ");
    }

    return value.toString();
  }

  String? _jobTypeLabel(Map<String, dynamic> job) {
    if (job["internship"] == true) return "Internship";
    return _value(job, "jobType");
  }

  // Turns the raw job description into 7-8 short bullet points, purely by
  // splitting the real text on sentence boundaries — no invented content,
  // just the same information in a scannable form instead of one wall of
  // text.
  List<String> _extractBullets(String? description, {int max = 8}) {
    if (description == null || description.trim().isEmpty) return [];

    final sentences = description
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length > 20 && s.length < 220)
        .toList();

    if (sentences.isEmpty) {
      // Fallback: just chunk the raw text if it has no clean sentences.
      return [description.trim()];
    }

    return sentences.take(max).toList();
  }

  Future<void> generateResume(Map<String, dynamic> job) async {
    setState(() => generatingResume = true);

    try {
      await ResumeService.generateAndShare(job);
    } on ResumeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      print("RESUME ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Something went wrong generating your resume. Please try again.")),
        );
      }
    }

    if (mounted) setState(() => generatingResume = false);
  }

  Widget badge(String text, {Color color = Colors.blue}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final company = _value(job, "company");
    final location = _value(job, "location");
    final source = _value(job, "source");
    final matchScore = job["matchScore"];
    final jobType = _jobTypeLabel(job);
    final skills = _value(job, "requirements");
    final experience = _value(job, "experience");
    final salary = _value(job, "stipend");
    final deadline = _value(job, "deadline");
    final startDate = _value(job, "expectedStart");
    final bullets = _extractBullets(_value(job, "description"));

    return Scaffold(
      appBar: AppBar(title: Text("Opportunity Details")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job["title"] ?? "", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (company != null) badge(company, color: Colors.teal),
                if (location != null) badge(location, color: Colors.indigo),
                if (source != null) badge(source, color: Colors.blueGrey),
                if (matchScore != null) badge("Match $matchScore%", color: Colors.blue),
                if (jobType != null) badge(jobType, color: Colors.deepPurple),
                if (salary != null) badge(salary, color: Colors.green),
                if (experience != null) badge(experience, color: Colors.orange),
                if (deadline != null) badge("Deadline: $deadline", color: Colors.red),
                if (startDate != null) badge("Starts: $startDate", color: Colors.brown),
              ],
            ),
            if (skills != null) ...[
              SizedBox(height: 18),
              Text("Required Skills", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: skills.split(", ").map((s) => Chip(label: Text(s))).toList(),
              ),
            ],
            SizedBox(height: 20),
            Text("What You'll Do", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: bullets.isEmpty
                  ? Text("No description available.")
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: bullets
                          .map((b) => Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("•  ", style: TextStyle(fontSize: 15)),
                                    Expanded(child: Text(b, style: TextStyle(height: 1.4))),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
            ),
            SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () async {
                  String url = (job["applyLink"] ?? "").toString().trim();
                  if (url.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Invalid apply link")));
                    return;
                  }
                  if (!url.startsWith("http")) url = "https://$url";
                  try {
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Unable to open link")));
                  }
                },
                icon: Icon(Icons.open_in_new),
                label: Text("Apply Now", style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: generatingResume ? null : () => generateResume(job),
                icon: generatingResume
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(Icons.picture_as_pdf),
                label: Text(
                  generatingResume ? "Generating your resume..." : "Generate Tailored Resume",
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/ai', arguments: job),
                icon: Icon(Icons.smart_toy),
                label: Text("Ask AI Assistant", style: TextStyle(fontSize: 18)),
                style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}