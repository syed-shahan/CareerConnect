import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:http/http.dart' as http;
import '../widgets/app_layout.dart';
import '../widgets/bottom_nav.dart';
// Adzuna credentials are supplied at build/run time via --dart-define and
// are never hard-coded here.
const String _adzunaAppId = String.fromEnvironment('ADZUNA_APP_ID');
const String _adzunaAppKey = String.fromEnvironment('ADZUNA_APP_KEY');
final HtmlUnescape _htmlUnescape = HtmlUnescape();
// Shared text cleanup used across every job source: strips HTML tags and
// decodes HTML entities so descriptions are actually human-readable.
String cleanJobText(String raw) {
  String text = _htmlUnescape.convert(raw);
  text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');
  text = text.replaceAll('&nbsp;', ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}
const List<String> knownSkillKeywords = [
  "flutter", "dart", "firebase", "python", "java", "kotlin", "react", "node",
  "api", "rest api", "mongodb", "sql", "machine learning", "ai",
  "data science", "figma", "ui/ux", "aws", "docker", "git", "cybersecurity",
  "tensorflow", "fastapi", "html", "css", "javascript",
];
List<String> extractRequirements(String description) {
  final lower = description.toLowerCase();
  return knownSkillKeywords.where((s) => lower.contains(s)).toList();
}
String? extractJobType(String title, String description) {
  final text = "$title $description".toLowerCase();
  if (text.contains("internship") || text.contains("intern ")) return null; // handled separately
  if (text.contains("full-time") || text.contains("full time")) return "Full time";
  if (text.contains("part-time") || text.contains("part time")) return "Part time";
  if (text.contains("contract")) return "Contract";
  if (text.contains("freelance")) return "Freelance";
  return null;
}
String? extractExperience(String description) {
  final lower = description.toLowerCase();
  final rangeMatch =
      RegExp(r'(\d+)\s*(?:-|to)\s*(\d+)\s*\\+?\s*years?').firstMatch(lower);
  if (rangeMatch != null) {
    return "${rangeMatch.group(1)}-${rangeMatch.group(2)} years";
  }
  final plusMatch = RegExp(r'(\d+)\s*\\+\s*years?').firstMatch(lower);
  if (plusMatch != null) {
    return "${plusMatch.group(1)}+ years";
  }
  final minMatch =
      RegExp(r'(?:minimum|min\\.?|at least)\s*(\d+)\s*years?').firstMatch(lower);
  if (minMatch != null) {
    return "${minMatch.group(1)}+ years";
  }
  if (lower.contains("fresher") ||
      lower.contains("entry level") ||
      lower.contains("entry-level") ||
      lower.contains("0-1 year")) {
    return "Fresher / Entry-level";
  }
  return null;
}
String? extractDeadline(String description) {
  final match = RegExp(
    r'(?:apply by|deadline|last date|closing date)[:\s]+([A-Za-z0-9,./ -]{4,25})',
    caseSensitive: false,
  ).firstMatch(description);
  return match?.group(1)?.trim();
}
String? extractStartDate(String description) {
  final match = RegExp(
    r'(?:start date|joining date|commencing)[:\s]+([A-Za-z0-9,./ -]{4,25})',
    caseSensitive: false,
  ).firstMatch(description);
  if (match != null) return match.group(1)?.trim();
  if (description.toLowerCase().contains("immediate joiner") ||
      description.toLowerCase().contains("immediate joining")) {
    return "Immediate";
  }
  return null;
}
bool detectInternship(String title, String description) {
  final text = "$title $description".toLowerCase();
  return text.contains("intern");
}
// India-priority tiers: 1 = Bengaluru/Greater Bengaluru, 2 = Karnataka,
// 3 = Other India, 4 = Remote, 5 = International.
const List<String> _indiaSignals = [
  "india", "mumbai", "delhi", "new delhi", "pune", "hyderabad", "chennai",
  "kolkata", "noida", "gurgaon", "gurugram", "ahmedabad", "jaipur", "kochi",
  "coimbatore", "chandigarh", "indore", "nagpur", "lucknow", "surat",
];
int computeLocationTier(String location, String description) {
  final text = "$location $description".toLowerCase();
  if (text.contains("bengaluru") || text.contains("bangalore")) return 1;
  if (text.contains("karnataka")) return 2;
  if (_indiaSignals.any((c) => text.contains(c))) return 3;
  if (text.contains("remote")) return 4;
  return 5;
}
class OpportunitiesScreen extends StatefulWidget {
  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}
class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  List<Map<String, dynamic>> jobs = [];
  bool isLoading = true;
  String lastUpdated = "";
  List<String> userSkills = [];
  String userName = "";
  String profileImage = "";
  @override
  void initState() {
    super.initState();
    loadUserData();
  }
  Future<void> loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    userName = (data["name"] ?? "User").toString();
    profileImage = (data["profileImage"] ?? data["photoUrl"] ?? "").toString();
    String skills = (data["skills"] ?? "").toString();
    userSkills = skills.toLowerCase().split(",");
    fetchJobs();
  }
  int calculateMatchScore(String title, String description) {
    title = title.toLowerCase();
    description = description.toLowerCase();
    int matchedSkills = 0;
    int totalSkills = userSkills.length;
    if (totalSkills == 0) return 0;
    for (var skill in userSkills) {
      skill = skill.trim();
      if (skill.isEmpty) continue;
      if (title.contains(skill) || description.contains(skill)) {
        matchedSkills++;
      }
    }
    double percentage = (matchedSkills / totalSkills) * 100;
    if (percentage > 100) percentage = 100;
    return percentage.toInt();
  }
  Widget quickStat(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue),
            SizedBox(height: 8),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
  Future<void> fetchJobs() async {
    setState(() => isLoading = true);
    try {
      List<Map<String, dynamic>> combinedJobs = [];
      // ================= REMOTEOK =================
      try {
        final remoteOkResponse = await http.get(
          Uri.parse("https://remoteok.com/api"),
          headers: {"Accept": "application/json"},
        );
        if (remoteOkResponse.statusCode == 200) {
          final remoteJobs = jsonDecode(remoteOkResponse.body);
          for (var job in remoteJobs.skip(1)) {
            String title = (job["position"] ?? "").toString();
            String description = cleanJobText((job["description"] ?? "").toString());
            int score = calculateMatchScore(title, description);
            DateTime? postedAt = DateTime.tryParse((job["date"] ?? "").toString());
            combinedJobs.add({
              "title": title,
              "company": (job["company"] ?? "Unknown").toString(),
              "location": "Remote",
              "stipend": "Not specified",
              "description": description,
              "applyLink": (job["url"] ?? "").toString(),
              "source": "RemoteOK",
              "matchScore": score,
              "jobType": extractJobType(title, description),
              "requirements": extractRequirements(description),
              "experience": extractExperience(description),
              "deadline": extractDeadline(description),
              "expectedStart": extractStartDate(description),
              "expectedEnd": null,
              "internship": detectInternship(title, description),
              "locationTier": computeLocationTier("Remote", description),
              "postedAt": postedAt,
            });
          }
        }
      } catch (e) {
        print("RemoteOK ERROR: $e");
      }
      // ================= ARBEITNOW =================
      try {
        final arbeitResponse =
            await http.get(Uri.parse("https://www.arbeitnow.com/api/job-board-api"));
        if (arbeitResponse.statusCode == 200) {
          final arbeitData = jsonDecode(arbeitResponse.body);
          for (var job in arbeitData["data"]) {
            String title = (job["title"] ?? "").toString();
            String description = cleanJobText((job["description"] ?? "").toString());
            String location = (job["location"] ?? "Remote").toString();
            int score = calculateMatchScore(title, description);
            DateTime? postedAt;
            final createdAtRaw = job["created_at"];
            if (createdAtRaw is int) {
              postedAt = DateTime.fromMillisecondsSinceEpoch(createdAtRaw * 1000);
            }
            String? jobType = (job["job_types"] is List && job["job_types"].isNotEmpty)
                ? job["job_types"].join(" • ").toString()
                : extractJobType(title, description);
            combinedJobs.add({
              "title": title,
              "company": (job["company_name"] ?? "Unknown").toString(),
              "location": location,
              "stipend": "Not specified",
              "description": description,
              "applyLink": (job["url"] ?? "").toString(),
              "source": "Arbeitnow",
              "matchScore": score,
              "jobType": jobType,
              "requirements": extractRequirements(description),
              "experience": extractExperience(description),
              "deadline": extractDeadline(description),
              "expectedStart": extractStartDate(description),
              "expectedEnd": null,
              "internship": detectInternship(title, description),
              "locationTier": computeLocationTier(location, description),
              "postedAt": postedAt,
            });
          }
        }
      } catch (e) {
        print("Arbeitnow ERROR: $e");
      }
      // ================= THE MUSE =================
      try {
        final museResponse =
            await http.get(Uri.parse("https://www.themuse.com/api/public/jobs?page=1"));
        if (museResponse.statusCode == 200) {
          final museData = jsonDecode(museResponse.body);
          for (var job in museData["results"]) {
            String title = (job["name"] ?? "").toString();
            String description = cleanJobText((job["contents"] ?? "").toString());
            String location = (job["locations"] != null && job["locations"].length > 0)
                ? job["locations"][0]["name"].toString()
                : "Remote";
            int score = calculateMatchScore(title, description);
            DateTime? postedAt =
                DateTime.tryParse((job["publication_date"] ?? "").toString());
            combinedJobs.add({
              "title": title,
              "company": (job["company"]?["name"] ?? "Unknown").toString(),
              "location": location,
              "stipend": "Not specified",
              "description": description,
              "applyLink": (job["refs"]?["landing_page"] ?? "").toString(),
              "source": "TheMuse",
              "matchScore": score,
              "jobType": extractJobType(title, description),
              "requirements": extractRequirements(description),
              "experience": extractExperience(description),
              "deadline": extractDeadline(description),
              "expectedStart": extractStartDate(description),
              "expectedEnd": null,
              "internship": detectInternship(title, description),
              "locationTier": computeLocationTier(location, description),
              "postedAt": postedAt,
            });
          }
        }
      } catch (e) {
        print("TheMuse ERROR: $e");
      }
      // ================= ADZUNA INDIA =================
      if (_adzunaAppId.isNotEmpty && _adzunaAppKey.isNotEmpty) {
        try {
          final skillQuery = userSkills
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .take(3)
              .join(' ');
          final adzunaUri = Uri.https(
            'api.adzuna.com',
            '/v1/api/jobs/in/search/1',
            {
              'app_id': _adzunaAppId,
              'app_key': _adzunaAppKey,
              'results_per_page': '30',
              'content-type': 'application/json',
              if (skillQuery.isNotEmpty) 'what': skillQuery,
            },
          );
          final adzunaResponse = await http.get(adzunaUri);
          if (adzunaResponse.statusCode == 200) {
            final adzunaData = jsonDecode(adzunaResponse.body);
            final results = adzunaData["results"] ?? [];
            for (var job in results) {
              String title = (job["title"] ?? "").toString();
              String description = cleanJobText((job["description"] ?? "").toString());
              String company = (job["company"]?["display_name"] ?? "Unknown").toString();
              String location = (job["location"]?["display_name"] ?? "India").toString();
              String stipend = "Not specified";
              final salMin = job["salary_min"];
              final salMax = job["salary_max"];
              if (salMin != null && salMax != null) {
                stipend =
                    "₹${(salMin as num).round()} - ₹${(salMax as num).round()} per annum (approx., as reported by Adzuna)";
              }
              String? jobType;
              final contractTime = (job["contract_time"] ?? "").toString();
              final contractType = (job["contract_type"] ?? "").toString();
              final typeParts = [contractTime, contractType]
                  .where((s) => s.isNotEmpty)
                  .map((s) => s.replaceAll('_', ' '))
                  .map((s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1))
                  .toList();
              if (typeParts.isNotEmpty) jobType = typeParts.join(' • ');
              jobType ??= extractJobType(title, description);
              DateTime? postedAt = DateTime.tryParse((job["created"] ?? "").toString());
              int score = calculateMatchScore(title, description);
              combinedJobs.add({
                "title": title,
                "company": company,
                "location": location,
                "stipend": stipend,
                "description": description,
                "applyLink": (job["redirect_url"] ?? "").toString(),
                "source": "Adzuna India",
                "matchScore": score,
                "jobType": jobType,
                "requirements": extractRequirements(description),
                "experience": extractExperience(description),
                "deadline": extractDeadline(description),
                "expectedStart": extractStartDate(description),
                "expectedEnd": null,
                "internship": detectInternship(title, description),
                "locationTier": computeLocationTier(location, description),
                "postedAt": postedAt,
              });
            }
          } else {
            print("Adzuna API failed: ${adzunaResponse.statusCode} ${adzunaResponse.body}");
          }
        } catch (e) {
          print("Adzuna ERROR: $e");
        }
      } else {
        print("Adzuna India skipped: ADZUNA_APP_ID / ADZUNA_APP_KEY not provided via --dart-define.");
      }
      // ================= DEDUP (title + company, keep best tier/score) =================
      final Map<String, Map<String, dynamic>> deduped = {};
      for (var job in combinedJobs) {
        final key =
            "${(job["title"] ?? "").toString().toLowerCase().trim()}|${(job["company"] ?? "").toString().toLowerCase().trim()}";
        if (key == "|") continue;
        if (!deduped.containsKey(key)) {
          deduped[key] = job;
        } else {
          final existing = deduped[key]!;
          final existingTier = existing["locationTier"] as int;
          final newTier = job["locationTier"] as int;
          final existingScore = existing["matchScore"] as int;
          final newScore = job["matchScore"] as int;
          if (newTier < existingTier || (newTier == existingTier && newScore > existingScore)) {
            deduped[key] = job;
          }
        }
      }
      combinedJobs = deduped.values.toList();
      // ================= SORT =================
      // skill match (desc) -> India/Bengaluru relevance (asc tier) ->
      // internship relevance -> freshness (desc) when available.
      combinedJobs.sort((a, b) {
        int scoreCompare = (b["matchScore"] as int).compareTo(a["matchScore"] as int);
        if (scoreCompare != 0) return scoreCompare;
        int tierCompare = (a["locationTier"] as int).compareTo(b["locationTier"] as int);
        if (tierCompare != 0) return tierCompare;
        bool aIntern = a["internship"] == true;
        bool bIntern = b["internship"] == true;
        if (aIntern != bIntern) return aIntern ? -1 : 1;
        DateTime? aDate = a["postedAt"] as DateTime?;
        DateTime? bDate = b["postedAt"] as DateTime?;
        if (aDate != null && bDate != null) return bDate.compareTo(aDate);
        if (aDate != null) return -1;
        if (bDate != null) return 1;
        return 0;
      });
      if (!mounted) return;
      setState(() {
        jobs = combinedJobs;
        lastUpdated = DateTime.now().toString();
        isLoading = false;
      });
    } catch (e) {
      print(e);
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNav(index: 0),
      body: AppLayout(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hello, $userName 👋",
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "AI matched opportunities for you",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: profileImage.isNotEmpty
                        ? NetworkImage(profileImage)
                        : null,
                    child: profileImage.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 24,
                            color: Colors.blue,
                          )
                        : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 7),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Recommended For You",
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    onPressed: fetchJobs,
                    icon: const Icon(Icons.refresh, size: 21),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : jobs.isEmpty
                      ? const Center(
                          child: Text(
                            "No opportunities found.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: jobs.length,
                          itemBuilder: (context, index) {
                            final job = jobs[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/detail',
                                    arguments: job,
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            job["title"],
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            "${job["matchScore"]}%",
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      "${job["company"]} • ${job["location"]}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      "Stipend: ${job["stipend"]}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 5,
                                      children: userSkills
                                          .take(3)
                                          .where(
                                            (skill) =>
                                                skill.trim().isNotEmpty,
                                          )
                                          .map(
                                            (skill) => Chip(
                                              label: Text(
                                                skill.trim(),
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                ),
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              padding: EdgeInsets.zero,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                    if ((job["matchScore"] ?? 0) > 40) ...[
                                      const SizedBox(height: 6),
                                      const Text(
                                        "⭐ Top Match",
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    const Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        "View Details →",
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}