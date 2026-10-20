import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode inputFocusNode = FocusNode();
  final Random random = Random();

  final List<Map<String, dynamic>> messages = [];
  Map<String, dynamic>? currentJob;

  String jobTitle = '';
  String company = '';
  String location = '';
  String description = '';
  String source = '';
  String matchScore = '';
  List<String> detectedSkills = [];

  bool isTyping = false;
  bool _loaded = false;

  final List<String> _skillLibrary = [
    'flutter',
    'dart',
    'firebase',
    'python',
    'java',
    'kotlin',
    'react',
    'node',
    'api',
    'rest api',
    'mongodb',
    'sql',
    'machine learning',
    'ai',
    'data science',
    'figma',
    'ui/ux',
    'aws',
    'docker',
    'git',
    'cybersecurity',
    'tensorflow',
    'fastapi',
    'html',
    'css',
    'javascript',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_loaded) return;
    _loaded = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, dynamic>) {
      currentJob = args;

      jobTitle = (args['title'] ?? '').toString().trim();
      company = (args['company'] ?? '').toString().trim();
      location = (args['location'] ?? '').toString().trim();
      description = (args['description'] ?? '').toString().trim();
      source = (args['source'] ?? '').toString().trim();
      matchScore = (args['matchScore'] ?? '').toString().trim();

      detectSkills();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _addOpeningMessage();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    inputFocusNode.dispose();
    super.dispose();
  }

  void detectSkills() {
    final lower = description.toLowerCase();

    detectedSkills = _skillLibrary
        .where((skill) => lower.contains(skill.toLowerCase()))
        .toSet()
        .toList();

    detectedSkills.sort((a, b) {
      final aIndex = lower.indexOf(a.toLowerCase());
      final bIndex = lower.indexOf(b.toLowerCase());
      return aIndex.compareTo(bIndex);
    });
  }

  String _displayTitle() {
    if (jobTitle.isNotEmpty) return jobTitle;
    return 'this opportunity';
  }

  String _displayCompany() {
    if (company.isNotEmpty) return company;
    return 'the company';
  }

  String _clean(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('•', '')
        .trim();
  }

  String _firstMeaningfulSentence(String text) {
    final clean = _clean(text);
    if (clean.isEmpty) return '';

    final match =
        RegExp(r'^(.{1,220}?[.!?])(?:\s|$)').firstMatch(clean);

    return match?.group(1) ??
        (clean.length > 220 ? '${clean.substring(0, 217)}...' : clean);
  }

  String _skillSentence() {
    if (detectedSkills.isEmpty) {
      return 'The description does not expose a clear technical stack, so I would focus on the role responsibilities and the strongest evidence from your projects.';
    }

    final names = detectedSkills.take(7).map(_prettySkill).toList();

    if (names.length == 1) {
      return '${names.first} is the clearest technical signal in this opportunity.';
    }

    if (names.length == 2) {
      return '${names[0]} and ${names[1]} are the clearest technical signals in this opportunity.';
    }

    return '${names.take(names.length - 1).join(', ')}, and ${names.last} are the clearest technical signals in this opportunity.';
  }

  String _prettySkill(String value) {
    final normalized = value.toLowerCase();

    const special = {
      'api': 'APIs',
      'rest api': 'REST APIs',
      'ui/ux': 'UI/UX',
      'ai': 'AI',
      'sql': 'SQL',
      'aws': 'AWS',
      'css': 'CSS',
      'html': 'HTML',
      'javascript': 'JavaScript',
      'firebase': 'Firebase',
      'flutter': 'Flutter',
      'dart': 'Dart',
      'python': 'Python',
      'mongodb': 'MongoDB',
      'fastapi': 'FastAPI',
      'tensorflow': 'TensorFlow',
    };

    if (special.containsKey(normalized)) return special[normalized]!;

    return value
        .split(' ')
        .map((word) =>
            word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _roleSnapshot() {
    final intro = _firstMeaningfulSentence(description);

    if (intro.isEmpty) {
      return 'I can still help you evaluate this opportunity, but the job description available here is quite limited.';
    }

    return intro;
  }

  String _scoreText() {
    if (matchScore.isEmpty) return '';
    return ' Your current match is shown as $matchScore.';
  }

  void _addOpeningMessage() {
    if (messages.isNotEmpty) return;

    final skillText = detectedSkills.isEmpty
        ? 'I’ll use the role details you have provided'
        : 'I’ll pay particular attention to ${detectedSkills.take(4).map(_prettySkill).join(', ')}';

    setState(() {
      messages.add({
        'isUser': false,
        'message':
            'I’ve got the context for **$_displayTitle()** at **$_displayCompany()**.\n\n'
            '$skillText. I’ll keep my answers specific to this opportunity instead of giving you generic career advice.$_scoreText()',
        'time': DateTime.now(),
      });
    });

    _scrollToBottom();
  }

  String analyzeIntent(String input) {
    final text = input.toLowerCase();

    if (RegExp(r'\b(hi|hello|hey|good morning|good evening)\b')
        .hasMatch(text)) {
      return 'greeting';
    }

    if (text.contains('why me') ||
        text.contains('fit') ||
        text.contains('match') ||
        text.contains('chance')) {
      return 'fit';
    }

    if (text.contains('skill') ||
        text.contains('technology') ||
        text.contains('tech stack') ||
        text.contains('stack')) {
      return 'skills';
    }

    if (text.contains('interview') ||
        text.contains('question') ||
        text.contains('prepare') ||
        text.contains('preparation')) {
      return 'interview';
    }

    if (text.contains('salary') ||
        text.contains('stipend') ||
        text.contains('package') ||
        text.contains('pay')) {
      return 'salary';
    }

    if (text.contains('resume') ||
        text.contains('cv') ||
        text.contains('application')) {
      return 'resume';
    }

    if (text.contains('criteria') ||
        text.contains('eligibility') ||
        text.contains('qualification') ||
        text.contains('requirement')) {
      return 'eligibility';
    }

    if (text.contains('roadmap') ||
        text.contains('learn') ||
        text.contains('study') ||
        text.contains('improve')) {
      return 'roadmap';
    }

    if (text.contains('project')) return 'projects';

    if (text.contains('company') ||
        text.contains('about the company') ||
        text.contains('culture')) {
      return 'company';
    }

    if (text.contains('apply') || text.contains('application')) {
      return 'apply';
    }

    if (text.contains('remote') ||
        text.contains('location') ||
        text.contains('where')) {
      return 'location';
    }

    if (text.contains('experience') || text.contains('fresher')) {
      return 'experience';
    }

    return 'general';
  }

  String generateResponse(String input) {
    final intent = analyzeIntent(input);
    final role = _displayTitle();
    final org = _displayCompany();

    switch (intent) {
      case 'greeting':
        return 'Hey! I’m ready. I’ve already got **$role at $org** in context, so you can ask me something specific — for example, whether you’re a good fit, what to prepare, or how to tailor your resume.';

      case 'fit':
        if (detectedSkills.isEmpty) {
          return '**My read on your fit**\n\n'
              'The job description available to me is not detailed enough to calculate a reliable skill-by-skill match. I would not pretend otherwise.\n\n'
              'What I can say is that your strongest case should come from projects, practical implementation, and evidence that you can handle the responsibilities described in the posting.';
        }

        return '**My read on your fit**\n\n'
            '${_skillSentence()}\n\n'
            'For **$role**, I’d position your profile around the skills that overlap with those requirements and then use your strongest projects as proof that you can actually apply them.\n\n'
            'If there are skills in the posting that you don’t currently have, don’t hide that gap. Pick the 1–2 most important ones and close those first.';

      case 'skills':
        if (detectedSkills.isEmpty) {
          return '**What I would focus on**\n\n'
              'The posting does not give me enough technical keywords to confidently name a stack. '
              'I’d avoid learning random technologies and instead prioritize the tools explicitly mentioned in the responsibilities and requirements.';
        }

        final skillList =
            detectedSkills.take(10).map((s) => '• ${_prettySkill(s)}').join('\n');

        return '**Skills that stand out for this role**\n\n'
            '$skillList\n\n'
            'The important part is not just listing these on your resume. Be ready to explain where you used each relevant skill, what you built with it, and what trade-offs or problems you faced.';

      case 'interview':
        final topics = <String>[];

        if (detectedSkills.contains('flutter')) {
          topics.add(
              'Flutter fundamentals, widget lifecycle, state management, navigation, and API/Firebase integration');
        }

        if (detectedSkills.contains('python')) {
          topics.add(
              'Python fundamentals, OOP, data handling, APIs, and clean problem-solving');
        }

        if (detectedSkills.contains('machine learning') ||
            detectedSkills.contains('ai') ||
            detectedSkills.contains('tensorflow')) {
          topics.add(
              'data preparation, model selection, evaluation, and explaining why your approach works');
        }

        if (detectedSkills.contains('sql')) {
          topics.add(
              'joins, filtering, aggregation, normalization, and practical query writing');
        }

        if (topics.isEmpty) {
          topics.add(
              'the responsibilities mentioned in the posting, your strongest projects, problem-solving, and communication');
        }

        return '**How I’d prepare for $role**\n\n'
            'I’d prepare in this order:\n\n'
            '1. **Role fundamentals** — understand what the posting actually expects you to do.\n'
            '2. **Technical depth** — ${topics.join('; ')}.\n'
            '3. **Your projects** — be able to explain one project from problem → approach → implementation → result.\n'
            '4. **Role-specific questions** — prepare a few situations where you made a technical decision and can explain why.\n\n'
            'The biggest mistake would be memorising definitions without being able to connect them to something you have actually built.';

      case 'salary':
        return '**About compensation**\n\n'
            'I don’t see a verified salary/stipend figure in the opportunity data available to me, so I wouldn’t invent one.\n\n'
            'If the posting does not disclose compensation, treat it as something to confirm from the official application or recruiter. Your technical match and interview performance are separate from the compensation figure.';

      case 'resume':
        final resumeSkills =
            detectedSkills.take(6).map(_prettySkill).join(', ');

        return '**How I’d tailor your resume for this one**\n\n'
            'Put the evidence this role cares about near the top. '
            '${resumeSkills.isEmpty ? 'Use the exact responsibilities and terminology from the posting where they truthfully match your background.' : 'For this posting, make sure your strongest evidence around $resumeSkills is easy to find.'}\n\n'
            'For projects, don’t stop at a technology list. Show the problem you solved, what you implemented, and the part you personally contributed. '
            'That makes the resume feel relevant rather than copied for every application.';

      case 'eligibility':
        return '**What the posting tells us**\n\n'
            'The safest way to judge eligibility is to separate hard requirements from preferred skills. '
            'I can use the opportunity text you supplied, but I won’t assume an eligibility rule that is not actually present in it.\n\n'
            'If you paste a specific requirement you’re unsure about, I can tell you exactly how I’d interpret it for this opportunity.';

      case 'roadmap':
        if (detectedSkills.contains('flutter')) {
          return '**A focused roadmap for this role**\n\n'
              'Dart fundamentals → Flutter UI & architecture → state management → REST APIs → Firebase → testing → deployment.\n\n'
              'I would not try to master everything at once. Build one small feature at each stage and keep it close to the kind of work this role describes.';
        }

        if (detectedSkills.contains('machine learning') ||
            detectedSkills.contains('ai') ||
            detectedSkills.contains('data science')) {
          return '**A focused roadmap for this role**\n\n'
              'Python → data handling → statistics → machine learning fundamentals → model evaluation → practical project → deployment/explanation.\n\n'
              'The goal should be demonstrable ability, not just completing tutorials. One well-explained project is more useful in an interview than a long list of unfinished courses.';
        }

        return '**A focused roadmap for this role**\n\n'
            'Start with the most important requirement in the posting, build a small practical project around it, then add the next requirement. '
            'Once you can explain your implementation confidently, move to interview-level problem solving.';

      case 'projects':
        if (detectedSkills.contains('flutter')) {
          return '**Projects that would strengthen your case**\n\n'
              'I’d choose a project that demonstrates a real mobile workflow rather than another basic UI clone. '
              'A Flutter application with authentication, a backend/Firebase layer, API integration, and a polished user flow would map naturally to the skills visible in this posting.\n\n'
              'The project matters most when you can explain the architecture and the decisions behind it.';
        }

        if (detectedSkills.contains('machine learning') ||
            detectedSkills.contains('ai')) {
          return '**Projects that would strengthen your case**\n\n'
              'Choose a project where the AI/ML component solves a real problem: data preparation, model training, evaluation, and a usable output. '
              'Avoid making the project just a model demo — the ability to explain the full pipeline is what makes it useful in an interview.';
        }

        return '**Project strategy for this opportunity**\n\n'
            'Pick one project that directly demonstrates the most important requirement in the posting. '
            'It should have a clear problem, a real implementation, and enough technical depth that you can defend your decisions in an interview.';

      case 'company':
        return '**About $org in the context of this opportunity**\n\n'
            'From the opportunity data I have, I can confidently discuss the role and its requirements, but I don’t want to invent details about company culture, products, or interview practices that are not included here.\n\n'
            'If you want, ask me specifically what this role appears to expect from a candidate and I’ll stay focused on the evidence in the posting.';

      case 'apply':
        return '**Before you apply**\n\n'
            '1. Tailor the resume to **$role**.\n'
            '2. Put the strongest matching project/experience where it is immediately visible.\n'
            '3. Use the posting’s terminology only where it truthfully describes your background.\n'
            '4. Check the official application details before submitting.\n\n'
            'You don’t need to look perfect for every requirement. You need to make the relevant evidence in your profile easy to see.';

      case 'location':
        if (location.isEmpty) {
          return 'I don’t have a confirmed location in the opportunity data available to me. I’d check the original posting before assuming the role is remote, hybrid, or on-site.';
        }

        return '**Location**\n\n'
            'The opportunity lists **$location**.\n\n'
            'That is the location associated with the posting I received. I would not assume the exact work mode or interview arrangement unless the original listing explicitly states it.';

      case 'experience':
        return '**If you’re worried about experience**\n\n'
            'Don’t compensate by padding your resume. Use projects, internships, coursework, leadership, or other genuine work to demonstrate the same capabilities the role is asking for.\n\n'
            'For a student/fresher profile, being able to clearly explain what you built and what you personally did can make a much stronger impression than simply claiming experience.';

      default:
        final roleSummary = _roleSnapshot();

        return '**My take on this opportunity**\n\n'
            '$roleSummary\n\n'
            '${_skillSentence()}\n\n'
            'If I were approaching **$role**, I’d focus on the overlap between the posting and your strongest evidence rather than trying to become a match for every possible requirement.\n\n'
            'You can ask me something as specific as **“Am I a good fit?”**, **“What should I prepare for the interview?”**, or **“Which skills should I put first on my resume?”**';
    }
  }

  Future<void> sendMessage([String? preset]) async {
    final text = (preset ?? controller.text).trim();

    if (text.isEmpty || isTyping) return;

    inputFocusNode.unfocus();
    controller.clear();

    setState(() {
      messages.add({
        'isUser': true,
        'message': text,
        'time': DateTime.now(),
      });

      isTyping = true;
    });

    _scrollToBottom();

    await Future.delayed(
      Duration(milliseconds: 500 + random.nextInt(450)),
    );

    if (!mounted) return;

    setState(() {
      messages.add({
        'isUser': false,
        'message': generateResponse(text),
        'time': DateTime.now(),
      });

      isTyping = false;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<String> get _suggestions {
    return [
      'Am I a good fit?',
      'What should I prepare?',
      'Which skills matter most?',
      'How should I tailor my resume?',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF101114) : const Color(0xFFF8F9FB),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildOpportunityContext(context),
          Expanded(
            child: messages.isEmpty
                ? _buildWelcome(context)
                : ListView.builder(
                    controller: scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: messages.length + (isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (isTyping && index == messages.length) {
                        return const _TypingIndicator();
                      }

                      final message = messages[index];

                      return _ChatMessage(
                        message: message['message']?.toString() ?? '',
                        isUser: message['isUser'] == true,
                      );
                    },
                  ),
          ),
          if (messages.length <= 2 && !isTyping)
            _buildSuggestionRow(context),
          _buildComposer(context),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      elevation: 0,
      backgroundColor:
          isDark ? const Color(0xFF101114) : const Color(0xFFF8F9FB),
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF635BFF), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CareerConnect AI',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Personalized for this opportunity',
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurface.withOpacity(.55),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityContext(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191B21) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.dividerColor.withOpacity(.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF635BFF).withOpacity(.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.work_outline_rounded,
              color: Color(0xFF635BFF),
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jobTitle.isEmpty ? 'Opportunity' : jobTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (company.isNotEmpty) company,
                    if (location.isNotEmpty) location,
                    if (source.isNotEmpty) source,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(.55),
                  ),
                ),
              ],
            ),
          ),
          if (matchScore.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$matchScore match',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 25, 28, 25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF635BFF), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF635BFF).withOpacity(.20),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Let’s talk about\n${jobTitle.isEmpty ? 'this opportunity' : jobTitle}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 25,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Ask naturally. I’ll keep the conversation focused on this specific role and its requirements.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(.60),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: _suggestions
                  .map(
                    (text) => ActionChip(
                      label: Text(text),
                      onPressed: () => sendMessage(text),
                      backgroundColor:
                          Theme.of(context).colorScheme.surface,
                      side: BorderSide(
                        color: Theme.of(context).dividerColor.withOpacity(.7),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionRow(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final text = _suggestions[index];

          return ActionChip(
            label: Text(text),
            onPressed: () => sendMessage(text),
            backgroundColor: Theme.of(context).colorScheme.surface,
            side: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(.6),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color:
              isDark ? const Color(0xFF101114) : const Color(0xFFF8F9FB),
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withOpacity(.35),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 125),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1C21) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(.55),
                  ),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: inputFocusNode,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Message CareerConnect AI...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(17, 12, 14, 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isTyping
                    ? theme.disabledColor.withOpacity(.18)
                    : const Color(0xFF635BFF),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                tooltip: 'Send',
                onPressed: isTyping ? null : () => sendMessage(),
                icon: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage extends StatelessWidget {
  final String message;
  final bool isUser;

  const _ChatMessage({
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(
          left: 42,
          top: 8,
          bottom: 8,
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * .78,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF635BFF), Color(0xFF745CF6)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(5),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF635BFF).withOpacity(.12),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(
        right: 16,
        top: 9,
        bottom: 9,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(
              top: 2,
              right: 9,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF635BFF), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(3, 0, 2, 0),
              child: _RichMessageText(
                text: message,
                color: theme.colorScheme.onSurface
                    .withOpacity(isDark ? .92 : .88),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RichMessageText extends StatelessWidget {
  final String text;
  final Color color;

  const _RichMessageText({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.trim().isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }

      if (line.startsWith('### ')) {
        spans.add(
          TextSpan(
            text: '${line.substring(4)}\n',
            style: const TextStyle(
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else {
        spans.addAll(_parseInline(line, color));

        if (i < lines.length - 1) {
          spans.add(const TextSpan(text: '\n'));
        }
      }
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: color,
          fontSize: 14.5,
          height: 1.55,
        ),
        children: spans,
      ),
    );
  }

  List<InlineSpan> _parseInline(String line, Color color) {
    final result = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.*?)\*\*');
    int cursor = 0;

    for (final match in pattern.allMatches(line)) {
      if (match.start > cursor) {
        result.add(
          TextSpan(
            text: line.substring(cursor, match.start),
          ),
        );
      }

      result.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      );

      cursor = match.end;
    }

    if (cursor < line.length) {
      result.add(
        TextSpan(
          text: line.substring(cursor),
        ),
      );
    }

    if (line.startsWith('• ')) {
      if (result.isNotEmpty) {
        result[0] = WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF635BFF),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );

        result.insert(
          1,
          TextSpan(
            text: line
                .substring(2)
                .replaceFirst(RegExp(r'\*\*.*?\*\*'), ''),
          ),
        );
      }
    }

    return result;
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        right: 16,
        top: 9,
        bottom: 9,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF635BFF), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: controller,
            builder: (_, __) {
              return Row(
                children: List.generate(3, (index) {
                  final value =
                      sin((controller.value * 2 * pi) + index * .9);

                  final opacity =
                      .35 + ((value + 1) / 2) * .65;

                  return Opacity(
                    opacity: opacity.clamp(.25, 1.0),
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}