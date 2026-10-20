import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const String _geminiModelName = 'gemini-flash-latest';

class ResumeException implements Exception {
  final String message;

  ResumeException(this.message);

  @override
  String toString() => message;
}

class ResumeService {
  static Future<Map<String, dynamic>> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw ResumeException(
        "You must be logged in to generate a resume.",
      );
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final data = doc.data();

    if (data == null) {
      throw ResumeException(
        "Couldn't load your profile data. Please try again.",
      );
    }

    return data;
  }

  static String _field(
    Map<String, dynamic> job,
    String key,
  ) {
    final value = job[key];

    if (value == null) {
      return "Not specified";
    }

    if (value is String) {
      return value.trim().isEmpty
          ? "Not specified"
          : value.trim();
    }

    if (value is List) {
      final items = value
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();

      return items.isEmpty
          ? "Not specified"
          : items.join(", ");
    }

    return value.toString();
  }

  static String _profileField(
    Map<String, dynamic> profile,
    String key,
  ) {
    final value = profile[key];

    if (value == null) {
      return "";
    }

    if (value is String) {
      return value.trim();
    }

    if (value is List) {
      return value
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .join(", ");
    }

    return value.toString();
  }

  static List<dynamic> _profileList(
    Map<String, dynamic> profile,
    String key,
  ) {
    final value = profile[key];

    if (value is List) {
      return value;
    }

    return [];
  }

  static Future<GenerateContentResponse> _generateWithRetry(
    GenerativeModel model,
    String prompt,
  ) async {
    const maxAttempts = 3;

    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await model.generateContent([
          Content.text(prompt),
        ]);
      } catch (e) {
        lastError = e;

        final errorText = e.toString().toLowerCase();

        final isOverloaded =
            errorText.contains('503') ||
            errorText.contains('unavailable') ||
            errorText.contains('high demand');

        if (!isOverloaded || attempt == maxAttempts) {
          rethrow;
        }

        await Future.delayed(
          Duration(seconds: attempt * 2),
        );
      }
    }

    throw lastError ??
        ResumeException(
          "Failed to generate resume content.",
        );
  }

  static Future<Map<String, dynamic>> _generateTailoredContent({
    required Map<String, dynamic> userProfile,
    required Map<String, dynamic> job,
  }) async {
    if (_geminiApiKey.isEmpty) {
      throw ResumeException(
        "AI resume generation isn't configured — no Gemini API key was provided at launch.",
      );
    }

    final model = GenerativeModel(
      model: _geminiModelName,
      apiKey: _geminiApiKey,
    );

    final skillsRaw =
        (userProfile["skills"] ?? "").toString();

    final userSkills = skillsRaw
        .split(",")
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final education =
        _profileList(userProfile, "education");

    final experience =
        _profileList(userProfile, "experience");

    final projects =
        _profileList(userProfile, "projects");

    final volunteer =
        _profileList(userProfile, "volunteer");

    final achievements =
        _profileList(userProfile, "achievements");

    final languages =
        _profileList(userProfile, "languages");

    final interests =
        _profileField(userProfile, "interests");

    if (userSkills.isEmpty &&
        education.isEmpty &&
        experience.isEmpty &&
        projects.isEmpty &&
        volunteer.isEmpty &&
        achievements.isEmpty) {
      throw ResumeException(
        "Your profile doesn't have enough information to create a resume. Add skills, education, experience, or projects from the Profile page first.",
      );
    }

    final prompt = """
You are an expert resume strategist, ATS optimization specialist, and AI-screening resume writer.

Create a highly tailored professional resume for the specific job opportunity below.

The resume will potentially be evaluated by:
1. ATS keyword matching systems.
2. AI resume screening systems.
3. Recruiters and hiring managers.

Your goal is NOT to create a generic resume.

Your goal is to create the strongest truthful version of THIS USER'S resume specifically for THIS opportunity.

========================
ABSOLUTE TRUTH RULE
========================

Use ONLY information that exists in USER DATA.

NEVER invent:
- skills
- technologies
- frameworks
- programming languages
- companies
- job titles
- internships
- projects
- achievements
- metrics
- responsibilities
- dates
- certifications
- qualifications
- degrees
- awards
- tools
- experience

Do not assume that the user knows a technology merely because the JOB requires it.

If a job asks for something the user does not have, do NOT falsely add it.

You MAY:
- reorder existing skills according to job relevance
- select the most relevant existing projects and experience
- rewrite existing descriptions
- strengthen wording
- use professional action verbs
- emphasize technically relevant details already present
- connect an existing project to a job requirement when the connection is truthful
- use terminology from the job description when it accurately describes the user's existing experience
- make bullets more ATS-readable
- remove repetition
- combine closely related facts when they remain truthful
- turn existing descriptions into stronger resume bullets
- elaborate truthfully on an existing fact with reasonable, obviously-implied technical detail (e.g. a project said to use "Flutter and Firebase" may truthfully mention standard aspects of that combination, such as state management or cloud data sync, ONLY if this does not claim a new unlisted tool or outcome)

========================
FILLING A SPARSE PROFILE (CRITICAL)
========================

Some users will have very little profile data (e.g. only 1-2 skills, one short project, no experience).

In that case, you must NOT produce a short, sparse resume.

Instead, you must EXPAND every existing truthful fact into fuller, richer, more detailed professional bullets so the final resume still reads as a complete, substantial ONE-PAGE document.

Techniques to expand truthfully (use only real facts, never new ones):
- break one short project description into 3-5 separate detailed bullets covering different real aspects already implied by the description (e.g. the problem it solves, the technologies used, the user's role, the architecture/approach, the outcome if stated)
- write a longer, richer SUMMARY (4-6 sentences instead of 3) that elaborates on the user's real background, domain interest, and the real skills/projects/education supplied
- for EDUCATION, if coursework, specialization, or relevant subjects are implied by the degree name, you may mention the degree's real focus area truthfully (e.g. "B.E. Computer Science (Data Science) with coursework spanning data analysis and machine learning fundamentals" is acceptable if the degree name says Data Science; do not invent specific course names not implied)
- expand on SKILLS by grouping and contextualizing them (e.g. "Proficient in Python and Dart for full-stack and data-driven application development" instead of a bare list) without adding skills not supplied
- if the user has very few projects, give each relevant project 5-6 substantial bullets rather than inventing additional projects
- if the user has experience, give each relevant experience entry 4-5 substantial bullets
- if the user has volunteer/leadership entries, give each relevant entry 3-4 substantial bullets
- write each bullet as a complete, information-rich sentence, normally 18-28 words when the available facts allow it
- for each project, cover different truthful dimensions such as problem solved, implementation, architecture, technologies, data/workflow, integration, testing, deployment, or user-facing functionality when those details are supported by the supplied project data
- for each experience entry, cover responsibilities, methods, technologies, deliverables, collaboration, and outcomes only when supported by the supplied data
- expand short descriptions by combining and explaining facts already present; do not merely repeat the same sentence with synonyms
- NEVER add fake metrics, employers, responsibilities, technologies, achievements, or outcomes just to increase length
- never pad with generic, information-free filler sentences ("hardworking and dedicated team player with strong communication skills") unless the user's own interests/profile data actually supports a specific, concrete claim

The final resume must look like a complete, professionally dense ONE-PAGE resume even when the underlying profile is minimal, through richer truthful elaboration — never through invention.

========================
ATS / AI SCREENING
========================

Analyze the job description carefully.

Identify:
- important technical keywords
- required technologies
- responsibilities
- role-specific terminology
- important soft skills
- domain terminology
- tools and frameworks
- concepts mentioned repeatedly
- qualifications that can truthfully match the user's profile

Where the user's real data supports a job keyword, naturally incorporate that terminology.

Prioritize truthful keyword alignment.

Do NOT keyword-stuff the resume.

Do NOT repeat the same keyword unnaturally.

Do NOT add keywords that are unsupported by USER DATA.

The resulting resume should sound like a strong human-written resume, not an AI-generated keyword list.

========================
BULLET WRITING
========================

Write strong, specific resume bullets.

Prefer this general structure when the available data supports it:

ACTION → TECHNOLOGY / METHOD → RESULT / IMPACT

Example style:

"Developed an AI-powered application using TensorFlow and Keras to classify gemstone categories from a custom image dataset."

Do not manufacture an impact or metric if the user data does not provide one.

When metrics exist in the user's data, preserve them because they strengthen the resume.

Avoid weak generic phrases such as:
- Responsible for
- Worked on
- Helped with
- Participated in
- Learned
- Basic knowledge of

Use strong verbs where truthful:
- Developed
- Built
- Designed
- Implemented
- Engineered
- Integrated
- Deployed
- Automated
- Optimized
- Trained
- Created
- Led
- Coordinated
- Managed

========================
CONTENT DENSITY
========================

Do NOT use arbitrary limits on:
- number of projects
- number of experience entries
- number of bullets
- number of skills
- number of education entries
- number of volunteer entries

There are NO hard content caps.

However, this is still a ONE-PAGE resume.

Therefore, intelligently prioritize information based on relevance to the specific job.

Use as much relevant information as can reasonably fit on one page.

If the underlying profile data is limited, follow the "FILLING A SPARSE PROFILE" rules above to still produce a full, dense one-page resume through truthful elaboration.

Do NOT make the resume artificially short.

Do NOT remove useful technical details simply to make it look sparse.

Do NOT include irrelevant information merely to fill space.

The final resume should feel information-rich and professionally balanced, normally using the entire available page.

If the user has several relevant projects, use several.

If the user has several relevant experience entries, use several.

If the user has multiple relevant bullets for an item, preserve them.

If something is clearly irrelevant to this opportunity, it can be omitted.

========================
SECTION PRIORITY
========================

Use standard ATS-friendly sections.

Possible sections include:

SUMMARY
SKILLS
EXPERIENCE
PROJECTS
EDUCATION
VOLUNTEER
ACHIEVEMENTS
LANGUAGES

Only include a section when meaningful data exists.

Do NOT create a Certifications section.

Do NOT invent certifications.

The ordering should prioritize the user's strongest evidence for this particular job.

For a technical role, technical skills and relevant technical projects/experience should receive strong emphasis.

For a leadership, management, communication, or event-related opportunity, relevant leadership and volunteer experience may receive stronger emphasis.

Adapt the resume to the opportunity.

========================
SUMMARY
========================

Write a strong 4-6 sentence summary (longer and richer if the rest of the profile is sparse).

It should be specifically tailored to the job.

Mention the user's strongest relevant:
- technical background
- projects
- experience
- technologies
- domain interests
- achievements

Only mention information supported by USER DATA.

Avoid generic filler.

========================
SKILLS
========================

Select and order the user's actual skills based on relevance to the job.

Do not add missing job requirements.

Do not unnecessarily remove legitimate skills.

Keep skills ATS-readable.

========================
PROJECTS
========================

Projects are important evidence of technical ability.

For relevant projects:
- preserve meaningful technical details
- mention actual technologies
- mention actual scale or metrics
- mention deployment when present
- mention notable recognition when present
- emphasize responsibilities relevant to the job
- if the project description is short, expand it into 4-6 detailed truthful bullets per the "FILLING A SPARSE PROFILE" rules

Do not fabricate results.

========================
EXPERIENCE
========================

Use the user's actual experience.

Rewrite descriptions into strong professional bullets.

Emphasize responsibilities and technologies relevant to the target job.

Expand short entries into multiple detailed bullets per the "FILLING A SPARSE PROFILE" rules.

Do not create employment that is not in USER DATA.

========================
EDUCATION
========================

Preserve actual degree, institution, dates, grades, location, and other educational information supplied by the user.

Do not invent grades or academic achievements.

========================
VOLUNTEER / LEADERSHIP
========================

Use relevant volunteer or leadership information if supplied.

Do not ignore meaningful leadership experience when it supports the target opportunity.

========================
ACHIEVEMENTS
========================

Use actual achievements and awards when supplied.

Do not manufacture awards.

========================
LANGUAGES
========================

Include languages only when supplied by the user.

========================
ONE-PAGE CONTENT TARGET
========================

The PDF renderer is designed for a dense professional one-page resume. Generate enough substantive content to naturally use most of the A4 page.

Target, when the corresponding data exists:
- Summary: 5-6 sentences.
- Skills: all relevant real skills, ordered by job relevance.
- Each relevant project: 5-6 strong bullets.
- Each relevant experience: 4-5 strong bullets.
- Each relevant volunteer/leadership entry: 3-4 strong bullets.
- Education: include all supplied education details.
- Achievements and languages: include all supplied relevant entries.

Do not solve sparse data by inventing facts. Instead, extract and elaborate every distinct truthful detail already present in the user's profile and project descriptions. The final result should look intentionally complete, not padded.

========================
OUTPUT
========================

Return ONLY valid JSON.

No markdown.

No ```json.

No explanation.

Use exactly this JSON structure:

{
  "summary": "",
  "skills": [],
  "education": [],
  "experience": [],
  "projects": [],
  "volunteer": [],
  "achievements": [],
  "languages": []
}

Education objects:

{
  "degree": "",
  "institution": "",
  "year": "",
  "location": "",
  "grade": ""
}

Experience objects:

{
  "role": "",
  "company": "",
  "duration": "",
  "location": "",
  "bullets": []
}

Project objects:

{
  "title": "",
  "techStack": "",
  "duration": "",
  "bullets": []
}

Volunteer objects:

{
  "role": "",
  "organization": "",
  "duration": "",
  "bullets": []
}

Achievement objects:

{
  "title": "",
  "description": ""
}

Languages should be strings.

========================
USER DATA
========================

Name:
${userProfile["name"] ?? "Not specified"}

Email:
${userProfile["email"] ?? "Not specified"}

Phone:
${userProfile["phone"] ?? "Not specified"}

College:
${userProfile["college"] ?? "Not specified"}

LinkedIn:
${_profileField(userProfile, "linkedin")}

GitHub:
${_profileField(userProfile, "github")}

Portfolio:
${_profileField(userProfile, "portfolio")}

Skills:
${userSkills.join(", ")}

Interests:
${interests.isEmpty ? "Not specified" : interests}

Education:
${jsonEncode(education)}

Experience:
${jsonEncode(experience)}

Projects:
${jsonEncode(projects)}

Volunteer:
${jsonEncode(volunteer)}

Achievements:
${jsonEncode(achievements)}

Languages:
${jsonEncode(languages)}

========================
JOB DATA
========================

Title:
${_field(job, "title")}

Company:
${_field(job, "company")}

Location:
${_field(job, "location")}

Job Type:
${_field(job, "jobType")}

Required Skills:
${_field(job, "requirements")}

Experience Requirement:
${_field(job, "experience")}

Full Description:
${_field(job, "description")}
""";

    final response = await _generateWithRetry(
      model,
      prompt,
    );

    final text = response.text ?? "";

    var cleaned = text.trim();

    if (cleaned.startsWith("```json")) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith("```")) {
      cleaned = cleaned.substring(3);
    }

    if (cleaned.endsWith("```")) {
      cleaned = cleaned.substring(
        0,
        cleaned.length - 3,
      );
    }

    cleaned = cleaned.trim();

    try {
      final decoded = jsonDecode(cleaned);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          "Unexpected response shape",
        );
      }

      return decoded;
    } catch (_) {
      throw ResumeException(
        "The AI response couldn't be understood. Please try again.",
      );
    }
  }

  static pw.Widget _sectionTitle(
    String title, [
    double fontSize = 10.5,
  ]) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(
        top: 8,
        bottom: 4,
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _bulletList(
    List<dynamic> bullets,
    double fontSize,
  ) {
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: bullets
          .map(
            (bullet) => pw.Padding(
              padding: const pw.EdgeInsets.only(
                bottom: 2.0,
              ),
              child: pw.Row(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "- ",
                    style: pw.TextStyle(
                      fontSize: fontSize,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      bullet.toString(),
                      style: pw.TextStyle(
                        fontSize: fontSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static Future<Uint8List> _buildPdfWithAutoFit({
    required Map<String, dynamic> content,
    required Map<String, dynamic> userProfile,
  }) async {
    Object? lastError;

    /*
     * No entries or bullets are removed at any stage.
     *
     * The entire tailored resume is preserved.
     * If necessary, only the visual scale is reduced so that
     * the complete resume remains on one A4 page.
     */
    const scales = [
      1.0,
      0.96,
      0.92,
      0.88,
      0.84,
      0.80,
      0.76,
      0.72,
      0.68,
      0.64,
    ];

    for (final scale in scales) {
      try {
        return await _buildPdf(
          content: content,
          userProfile: userProfile,
          scale: scale,
        );
      } catch (e) {
        lastError = e;
      }
    }

    throw lastError ??
        Exception(
          "Could not generate the resume PDF.",
        );
  }

  static Future<Uint8List> _buildPdf({
    required Map<String, dynamic> content,
    required Map<String, dynamic> userProfile,
    double scale = 1.0,
  }) async {
    final doc = pw.Document();

    final name =
        (userProfile["name"] ?? "").toString();

    final email =
        (userProfile["email"] ?? "").toString();

    final phone =
        (userProfile["phone"] ?? "").toString();

    final college =
        (userProfile["college"] ?? "").toString();

    final linkedin =
        _profileField(userProfile, "linkedin");

    final github =
        _profileField(userProfile, "github");

    final portfolio =
        _profileField(userProfile, "portfolio");

    final skills =
        content["skills"] is List
            ? (content["skills"] as List)
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList()
            : <String>[];

    final education =
        content["education"] is List
            ? content["education"] as List
            : <dynamic>[];

    final experience =
        content["experience"] is List
            ? content["experience"] as List
            : <dynamic>[];

    final projects =
        content["projects"] is List
            ? content["projects"] as List
            : <dynamic>[];

    final volunteer =
        content["volunteer"] is List
            ? content["volunteer"] as List
            : <dynamic>[];

    final achievements =
        content["achievements"] is List
            ? content["achievements"] as List
            : <dynamic>[];

    final languages =
        content["languages"] is List
            ? (content["languages"] as List)
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList()
            : <String>[];

    final summary =
        (content["summary"] ?? "").toString();

    double fs(double value) => value * scale;

    double spacing(double value) =>
        value * scale;

    pw.Widget buildExperience(
      Map<String, dynamic> map,
    ) {
      final role =
          (map["role"] ?? "").toString();

      final company =
          (map["company"] ?? "").toString();

      final duration =
          (map["duration"] ?? "").toString();

      final location =
          (map["location"] ?? "").toString();

      final heading = [
        role,
        company,
      ]
          .where(
            (s) => s.trim().isNotEmpty,
          )
          .join(" | ");

      final rightText = [
        duration,
        location,
      ]
          .where(
            (s) => s.trim().isNotEmpty,
          )
          .join(" - ");

      final bullets =
          map["bullets"] is List
              ? map["bullets"] as List
              : <dynamic>[];

      return pw.Padding(
        padding: pw.EdgeInsets.only(
          bottom: spacing(5),
        ),
        child: pw.Column(
          crossAxisAlignment:
              pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    heading,
                    style: pw.TextStyle(
                      fontSize: fs(9.8),
                      fontWeight:
                          pw.FontWeight.bold,
                    ),
                  ),
                ),
                if (rightText.isNotEmpty)
                  pw.Text(
                    rightText,
                    style: pw.TextStyle(
                      fontSize: fs(8.2),
                      color:
                          PdfColors.grey700,
                    ),
                  ),
              ],
            ),
            if (bullets.isNotEmpty)
              _bulletList(
                bullets,
                fs(8.7),
              ),
          ],
        ),
      );
    }

    pw.Widget buildProject(
      Map<String, dynamic> map,
    ) {
      final title =
          (map["title"] ?? "").toString();

      final techStack =
          (map["techStack"] ?? "").toString();

      final duration =
          (map["duration"] ?? "").toString();

      final heading = title.trim().isEmpty
          ? techStack
          : title;

      final bullets =
          map["bullets"] is List
              ? map["bullets"] as List
              : <dynamic>[];

      return pw.Padding(
        padding: pw.EdgeInsets.only(
          bottom: spacing(5),
        ),
        child: pw.Column(
          crossAxisAlignment:
              pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    heading,
                    style: pw.TextStyle(
                      fontSize: fs(9.8),
                      fontWeight:
                          pw.FontWeight.bold,
                    ),
                  ),
                ),
                if (duration.trim().isNotEmpty)
                  pw.Text(
                    duration,
                    style: pw.TextStyle(
                      fontSize: fs(8.2),
                      color:
                          PdfColors.grey700,
                    ),
                  ),
              ],
            ),

            if (techStack.trim().isNotEmpty)
              pw.Text(
                techStack,
                style: pw.TextStyle(
                  fontSize: fs(8.1),
                  color: PdfColors.grey700,
                ),
              ),

            if (bullets.isNotEmpty)
              _bulletList(
                bullets,
                fs(8.7),
              ),
          ],
        ),
      );
    }

    pw.Widget buildEducation(
      Map<String, dynamic> map,
    ) {
      final degree =
          (map["degree"] ?? "").toString();

      final institution =
          (map["institution"] ?? "").toString();

      final year =
          (map["year"] ?? "").toString();

      final location =
          (map["location"] ?? "").toString();

      final grade =
          (map["grade"] ?? "").toString();

      final left = [
        degree,
        institution,
      ]
          .where(
            (s) => s.trim().isNotEmpty,
          )
          .join(" | ");

      final details = [
        year,
        location,
        grade,
      ]
          .where(
            (s) => s.trim().isNotEmpty,
          )
          .join(" - ");

      return pw.Padding(
        padding: pw.EdgeInsets.only(
          bottom: spacing(4),
        ),
        child: pw.Row(
          crossAxisAlignment:
              pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                left,
                style: pw.TextStyle(
                  fontSize: fs(8.9),
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),
            ),
            if (details.isNotEmpty)
              pw.Text(
                details,
                style: pw.TextStyle(
                  fontSize: fs(8.1),
                  color: PdfColors.grey700,
                ),
              ),
          ],
        ),
      );
    }

    pw.Widget buildVolunteer(
      Map<String, dynamic> map,
    ) {
      final role =
          (map["role"] ?? "").toString();

      final organization =
          (map["organization"] ?? "")
              .toString();

      final duration =
          (map["duration"] ?? "").toString();

      final heading = [
        role,
        organization,
      ]
          .where(
            (s) => s.trim().isNotEmpty,
          )
          .join(" | ");

      final bullets =
          map["bullets"] is List
              ? map["bullets"] as List
              : <dynamic>[];

      return pw.Padding(
        padding: pw.EdgeInsets.only(
          bottom: spacing(4),
        ),
        child: pw.Column(
          crossAxisAlignment:
              pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    heading,
                    style: pw.TextStyle(
                      fontSize: fs(8.9),
                      fontWeight:
                          pw.FontWeight.bold,
                    ),
                  ),
                ),
                if (duration.trim().isNotEmpty)
                  pw.Text(
                    duration,
                    style: pw.TextStyle(
                      fontSize: fs(8.1),
                      color:
                          PdfColors.grey700,
                    ),
                  ),
              ],
            ),
            if (bullets.isNotEmpty)
              _bulletList(
                bullets,
                fs(8.5),
              ),
          ],
        ),
      );
    }

    pw.Widget buildAchievement(
      Map<String, dynamic> map,
    ) {
      final title =
          (map["title"] ?? "").toString();

      final description =
          (map["description"] ?? "")
              .toString();

      return pw.Padding(
        padding: pw.EdgeInsets.only(
          bottom: spacing(3),
        ),
        child: pw.Row(
          crossAxisAlignment:
              pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "-  ",
              style: pw.TextStyle(
                fontSize: fs(8.6),
              ),
            ),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: title,
                      style: pw.TextStyle(
                        fontSize: fs(8.6),
                        fontWeight:
                            pw.FontWeight.bold,
                      ),
                    ),
                    if (description
                        .trim()
                        .isNotEmpty)
                      pw.TextSpan(
                        text:
                            ": $description",
                        style: pw.TextStyle(
                          fontSize: fs(8.6),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final contactItems = [
      email,
      phone,
      college,
      linkedin,
      github,
      portfolio,
    ]
        .where(
          (s) => s.trim().isNotEmpty,
        )
        .toList();

    /*
     * Everything is kept on ONE A4 page.
     *
     * Unlike the previous implementation:
     * - no projects are dropped
     * - no experience entries are dropped
     * - no bullets are dropped
     * - no sections are artificially capped
     *
     * The entire generated resume is rendered and the visual scale
     * is adjusted by the caller when necessary.
     */
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(
          28 * scale,
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                name.isEmpty
                    ? "Resume"
                    : name,
                style: pw.TextStyle(
                  fontSize: fs(20),
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(
                height: spacing(2),
              ),

              if (contactItems.isNotEmpty)
                pw.Text(
                  contactItems.join("  |  "),
                  style: pw.TextStyle(
                    fontSize: fs(8.0),
                    color:
                        PdfColors.grey700,
                  ),
                ),

              pw.Divider(
                color: PdfColors.grey400,
                thickness: 0.7,
                height: spacing(7),
              ),

              if (summary.trim().isNotEmpty) ...[
                _sectionTitle(
                  "Summary",
                  fs(10.5),
                ),
                pw.Text(
                  summary,
                  style: pw.TextStyle(
                    fontSize: fs(9.0),
                    lineSpacing: 1.12,
                  ),
                ),
              ],

              if (skills.isNotEmpty) ...[
                _sectionTitle(
                  "Skills",
                  fs(10.5),
                ),
                pw.Text(
                  skills.join("  |  "),
                  style: pw.TextStyle(
                    fontSize: fs(8.8),
                    lineSpacing: 1.10,
                  ),
                ),
              ],

              if (experience.isNotEmpty) ...[
                _sectionTitle(
                  "Experience",
                  fs(10.5),
                ),
                ...experience
                    .where((e) => e is Map)
                    .map(
                      (e) => buildExperience(
                        Map<String, dynamic>.from(
                          e as Map,
                        ),
                      ),
                    ),
              ],

              if (projects.isNotEmpty) ...[
                _sectionTitle(
                  "Projects",
                  fs(10.5),
                ),
                ...projects
                    .where((p) => p is Map)
                    .map(
                      (p) => buildProject(
                        Map<String, dynamic>.from(
                          p as Map,
                        ),
                      ),
                    ),
              ],

              if (education.isNotEmpty) ...[
                _sectionTitle(
                  "Education",
                  fs(10.5),
                ),
                ...education
                    .where((e) => e is Map)
                    .map(
                      (e) => buildEducation(
                        Map<String, dynamic>.from(
                          e as Map,
                        ),
                      ),
                    ),
              ],

              if (volunteer.isNotEmpty) ...[
                _sectionTitle(
                  "Volunteer & Leadership",
                  fs(10.5),
                ),
                ...volunteer
                    .where((v) => v is Map)
                    .map(
                      (v) => buildVolunteer(
                        Map<String, dynamic>.from(
                          v as Map,
                        ),
                      ),
                    ),
              ],

              if (achievements.isNotEmpty) ...[
                _sectionTitle(
                  "Achievements",
                  fs(10.5),
                ),
                ...achievements
                    .where((a) => a is Map)
                    .map(
                      (a) => buildAchievement(
                        Map<String, dynamic>.from(
                          a as Map,
                        ),
                      ),
                    ),
              ],

              if (languages.isNotEmpty) ...[
                _sectionTitle(
                  "Languages",
                  fs(10.5),
                ),
                pw.Text(
                  languages.join("  |  "),
                  style: pw.TextStyle(
                    fontSize: fs(8.6),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return await doc.save();
  }

  static Future<Uint8List> _buildMinimalPdf({
    required Map<String, dynamic> userProfile,
    required Map<String, dynamic> content,
  }) async {
    final doc = pw.Document();

    final lines = <String>[];

    lines.add(
      (userProfile["name"] ?? "Resume").toString(),
    );

    final contactInfo = [
      (userProfile["email"] ?? "").toString(),
      (userProfile["phone"] ?? "").toString(),
      (userProfile["college"] ?? "").toString(),
      _profileField(userProfile, "linkedin"),
      _profileField(userProfile, "github"),
    ]
        .where(
          (s) => s.trim().isNotEmpty,
        )
        .join("  |  ");

    if (contactInfo.isNotEmpty) {
      lines.add(contactInfo);
    }

    lines.add("");

    final summary =
        (content["summary"] ?? "").toString();

    if (summary.trim().isNotEmpty) {
      lines.add("SUMMARY");
      lines.add(summary);
      lines.add("");
    }

    final skills =
        content["skills"] is List
            ? (content["skills"] as List)
                .map((e) => e.toString())
                .toList()
            : <String>[];

    if (skills.isNotEmpty) {
      lines.add(
        "SKILLS: ${skills.join(", ")}",
      );
      lines.add("");
    }

    void addSection(
      String title,
      dynamic rawItems,
      List<String> fields,
    ) {
      if (rawItems is! List ||
          rawItems.isEmpty) {
        return;
      }

      lines.add(title.toUpperCase());

      for (final raw in rawItems) {
        if (raw is! Map) {
          continue;
        }

        final map =
            Map<String, dynamic>.from(raw);

        final parts = fields
            .map(
              (field) =>
                  (map[field] ?? "")
                      .toString(),
            )
            .where(
              (value) =>
                  value.trim().isNotEmpty,
            )
            .join(" - ");

        if (parts.isNotEmpty) {
          lines.add(parts);
        }

        final bullets = map["bullets"];

        if (bullets is List) {
          for (final bullet in bullets) {
            lines.add(
              "-  ${bullet.toString()}",
            );
          }
        }

        final description =
            (map["description"] ?? "")
                .toString();

        if (description.trim().isNotEmpty &&
            bullets is! List) {
          lines.add(
            "-  $description",
          );
        }
      }

      lines.add("");
    }

    addSection(
      "Education",
      content["education"],
      [
        "degree",
        "institution",
        "year",
      ],
    );

    addSection(
      "Experience",
      content["experience"],
      [
        "role",
        "company",
        "duration",
      ],
    );

    addSection(
      "Projects",
      content["projects"],
      [
        "title",
        "techStack",
        "duration",
      ],
    );

    addSection(
      "Volunteer & Leadership",
      content["volunteer"],
      [
        "role",
        "organization",
        "duration",
      ],
    );

    addSection(
      "Achievements",
      content["achievements"],
      [
        "title",
        "description",
      ],
    );

    if (content["languages"] is List &&
        (content["languages"] as List).isNotEmpty) {
      lines.add("LANGUAGES");
      lines.add(
        (content["languages"] as List)
            .map((e) => e.toString())
            .join("  |  "),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: lines
                .map(
                  (line) => pw.Padding(
                    padding:
                        const pw.EdgeInsets.only(
                      bottom: 2,
                    ),
                    child: pw.Text(
                      line,
                      style:
                          const pw.TextStyle(
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );

    return await doc.save();
  }

  static String _fallbackSummary(
    Map<String, dynamic> profile,
    List<String> skills,
  ) {
    final name = (profile["name"] ?? "").toString().trim();
    final college = (profile["college"] ?? "").toString().trim();
    final branch = (profile["branch"] ?? profile["department"] ?? "")
        .toString()
        .trim();
    final interests = (profile["interests"] ?? "").toString().trim();

    final parts = <String>[];
    if (branch.isNotEmpty && college.isNotEmpty) {
      parts.add("$branch student at $college");
    } else if (college.isNotEmpty) {
      parts.add("Computer science student at $college");
    } else if (branch.isNotEmpty) {
      parts.add("$branch student");
    } else if (name.isNotEmpty) {
      parts.add("Computer science and technology student");
    }

    if (skills.isNotEmpty) {
      parts.add("with practical exposure to ${skills.join(', ')}");
    }

    if (interests.isNotEmpty) {
      parts.add("with interests in $interests");
    }

    if (parts.isEmpty) {
      return "Motivated technology student with a focus on developing practical technical skills through academic work and hands-on projects.";
    }

    return "${parts.join(' ')}. Focused on applying technical knowledge through practical projects, structured problem solving, and continuous development of relevant skills.";
  }

  static Map<String, dynamic>
      _buildContentDirectlyFromProfile(
    Map<String, dynamic> userProfile,
  ) {
    final skillsRaw =
        (userProfile["skills"] ?? "")
            .toString();

    final skills = skillsRaw
        .split(",")
        .map((s) => s.trim())
        .where(
          (s) => s.isNotEmpty,
        )
        .toList();

    final education =
        _profileList(
      userProfile,
      "education",
    );

    final experience =
        _profileList(
      userProfile,
      "experience",
    );

    final projects =
        _profileList(
      userProfile,
      "projects",
    );

    final volunteer =
        _profileList(
      userProfile,
      "volunteer",
    );

    final achievements =
        _profileList(
      userProfile,
      "achievements",
    );

    final languages =
        _profileList(
      userProfile,
      "languages",
    );

    List<dynamic> addBullets(
      List<dynamic> entries,
    ) {
      return entries.map((entry) {
        if (entry is! Map) {
          return entry;
        }

        final map =
            Map<String, dynamic>.from(
          entry,
        );

        if (map["bullets"] is List) {
          return map;
        }

        final description =
            (map["description"] ?? "")
                .toString()
                .trim();

        final techStack = (map["techStack"] ?? "").toString().trim();

        final expanded = <String>[];
        if (description.isNotEmpty) {
          expanded.add("Developed and documented the project around the stated objective: $description");
          expanded.add("Applied the technologies and implementation approach described in the project profile to build the solution.");
          expanded.add("Structured the project around practical functionality and the requirements captured in the user's profile.");
        }
        if (techStack.isNotEmpty) {
          expanded.add("Implemented the project using $techStack, with emphasis on practical integration of the listed technologies.");
        }

        return {
          ...map,
          "bullets": expanded,
        };
      }).toList();
    }

    return {
      "summary": _fallbackSummary(userProfile, skills),

      "skills": skills,

      "education": education,

      "experience":
          addBullets(experience),

      "projects":
          addBullets(projects),

      "volunteer":
          addBullets(volunteer),

      "achievements":
          achievements,

      "languages":
          languages,
    };
  }

  static String _sanitizeFilename(
    String input,
  ) {
    final cleaned = input
        .trim()
        .replaceAll(
          RegExp(
            r'[^a-zA-Z0-9_\-]+',
          ),
          '_',
        );

    return cleaned.isEmpty
        ? "user"
        : cleaned;
  }

  static Future<void> generateAndShare(
    Map<String, dynamic> job,
  ) async {
    final userProfile =
        await _loadUserProfile();

    Map<String, dynamic> content;

    try {
      content =
          await _generateTailoredContent(
        userProfile: userProfile,
        job: job,
      );
    } catch (e) {
      /*
       * AI failed:
       * use the user's actual profile instead of
       * producing an empty resume.
       */
      content =
          _buildContentDirectlyFromProfile(
        userProfile,
      );
    }

    Uint8List bytes;

    try {
      bytes =
          await _buildPdfWithAutoFit(
        content: content,
        userProfile: userProfile,
      );
    } catch (e) {
      bytes =
          await _buildMinimalPdf(
        userProfile: userProfile,
        content: content,
      );
    }

    final userName =
        _sanitizeFilename(
      (userProfile["name"] ?? "user")
          .toString(),
    );

    final companyName =
        _sanitizeFilename(
      (job["company"] ??
              "opportunity")
          .toString(),
    );

    final filename =
        "${userName}_resume_$companyName.pdf";

    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }
}