import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import '../../widgets/voice_animation.dart';
import 'vocal_chatbot_vocal_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/user_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

// Extension to get last N elements from a list
extension ListExtension<T> on List<T> {
  List<T> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}

// Add AppColors for consistent theming
class AppColors {
  static const Color primary = Color(0xFF68B86C);
  static const Color secondary = Color(0xFFFA8B26);
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF2D2D2D);
  static const Color textSecondary = Color(0xFF757575);
}

class VocalChatbotScreen extends StatefulWidget {
  const VocalChatbotScreen({Key? key}) : super(key: key);

  @override
  State<VocalChatbotScreen> createState() => _VocalChatbotScreenState();
}

class _VocalChatbotScreenState extends State<VocalChatbotScreen>
    with TickerProviderStateMixin {
  static final Map<String, List<Map<String, String>>> _userChatHistories = {};
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _text = '';
  List<Map<String, String>> _chatHistory = [];
  String? _typingAIMessage; // For typewriter effect
  int _typingIndex = 0;
  Timer? _typingTimer;

  final String _apiKey = '';

  bool _isListening = false;
  bool _isAISpeaking = false;
  bool _isAwaitingAI = false;
  late AnimationController _aiSpeakingAnimController;

  // Google Places API key for healthy restaurant suggestions
  static const String _placesApiKey = '';

  String getUserType(BuildContext context) {
    final profileProvider = Provider.of<UserProfileProvider>(
      context,
      listen: false,
    );
    return profileProvider.profile?.userType ?? 'Patient';
  }

  String getUserContext(BuildContext context) {
    final profileProvider = Provider.of<UserProfileProvider>(
      context,
      listen: false,
    );
    final profile = profileProvider.profile;
    if (profile == null) return '';
    List<String> contextParts = [];
    contextParts.add('User type: \'${profile.userType}\'');
    if (profile.primaryCondition != null &&
        profile.primaryCondition!.isNotEmpty)
      contextParts.add('Primary condition: \'${profile.primaryCondition}\'');
    if (profile.mainChallenge != null && profile.mainChallenge!.isNotEmpty)
      contextParts.add('Main challenge: \'${profile.mainChallenge}\'');
    if (profile.wellnessGoal != null && profile.wellnessGoal!.isNotEmpty)
      contextParts.add('Wellness goal: \'${profile.wellnessGoal}\'');
    if (profile.wellnessObstacle != null &&
        profile.wellnessObstacle!.isNotEmpty)
      contextParts.add('Wellness obstacle: \'${profile.wellnessObstacle}\'');
    if (profile.careRole != null && profile.careRole!.isNotEmpty)
      contextParts.add('Care role: \'${profile.careRole}\'');
    if (profile.careNeeds != null && profile.careNeeds!.isNotEmpty)
      contextParts.add('Care needs: \'${profile.careNeeds}\'');
    return contextParts.join(', ');
  }

  Future<List<String>> getNearbyHealthyRestaurants(
    double lat,
    double lng,
  ) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=$lat,$lng'
      '&radius=1500'
      '&type=restaurant'
      '&keyword=healthy'
      '&key=$_placesApiKey',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'] as List;
      if (results.isNotEmpty) {
        final places =
            results.take(5).map((place) => place['name'] as String).toList();
        debugPrint('[Chatbot] Google Places found: ' + places.join(', '));
        return places;
      } else {
        debugPrint(
          '[Chatbot] Google Places returned no results. Using Geneva fallback list.',
        );
        return [
          'Qibi',
          'Le Boteco Healthy Food',
          'Green Gorilla',
          'Be Kind Café',
          'Alive',
          'Le Pain Quotidien',
          'Eat Me',
          'Café Mutin',
          'Manora',
          'Holy Cow! Gourmet Burger',
        ];
      }
    }
    debugPrint(
      '[Chatbot] Google Places API error: \\${response.statusCode}. Using Geneva fallback list.',
    );
    return [
      'Qibi',
      'Le Boteco Healthy Food',
      'Green Gorilla',
      'Be Kind Café',
      'Alive',
      'Le Pain Quotidien',
      'Eat Me',
      'Café Mutin',
      'Manora',
      'Holy Cow! Gourmet Burger',
    ];
  }

  Future<String> getModeContext() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('mode') ?? '...';
    final subMode = prefs.getString('away_sub_mode') ?? '';
    double? lat = prefs.getDouble('last_lat');
    double? lng = prefs.getDouble('last_lng');
    // Geneva fallback list
    final genevaPlaces = [
      'Qibi',
      'Le Boteco Healthy Food',
      'Green Gorilla',
      'Be Kind Café',
      'Alive',
      'Le Pain Quotidien',
      'Eat Me',
      'Café Mutin',
      'Manora',
      'Holy Cow! Gourmet Burger',
    ];
    if (mode == 'Away' && lat != null && lng != null && lat > 0 && lng > 0) {
      final places = await getNearbyHealthyRestaurants(lat, lng);
      String placesStr =
          places.isNotEmpty
              ? 'Nearby healthy restaurants: ' + places.join(', ') + '.'
              : 'Nearby healthy restaurants in Geneva: ' +
                  genevaPlaces.join(', ') +
                  '.';
      debugPrint('[Chatbot] ModeContext places sent to AI: $placesStr');
      return "The user is currently 'Away' (sub-mode: '[1m[31m[1m[31m[1m[31m$subMode'). $placesStr";
    } else if (mode == 'Away') {
      String placesStr =
          'Nearby healthy restaurants in Geneva: ' +
          genevaPlaces.join(', ') +
          '.';
      debugPrint(
        '[Chatbot] ModeContext fallback places sent to AI: $placesStr',
      );
      return "The user is currently 'Away' (sub-mode: '[1m[31m[1m[31m[1m[31m$subMode'). $placesStr Please ONLY suggest restaurants from this Geneva list if you cannot determine the user's location.";
    } else if (mode == 'Home') {
      return "The user is currently 'Home'.";
    } else {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _aiSpeakingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    // Load chat history per user
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'guest';
    if (!_userChatHistories.containsKey(uid) ||
        _userChatHistories[uid]!.isEmpty) {
      _userChatHistories[uid] = [
        {
          'role': 'assistant',
          'content':
              'Hello! I\'m Osmos, your health assistant. How can I help you today?',
        },
      ];
    }
    _chatHistory = List<Map<String, String>>.from(_userChatHistories[uid]!);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    _aiSpeakingAnimController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done') {
          setState(() => _isListening = false);
          _processVoiceInput();
        }
      },
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.65);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.08);
    _flutterTts.setStartHandler(() {
      setState(() => _isAISpeaking = true);
    });
    _flutterTts.setCompletionHandler(() {
      setState(() => _isAISpeaking = false);
    });
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _text = '';
        });
        _speech.listen(
          onResult: (result) {
            setState(() {
              _text = result.recognizedWords;
              _textController.text = _text;
            });
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _processVoiceInput() async {
    if (_text.isNotEmpty) {
      await _sendMessage(_text);
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    setState(() {
      _chatHistory.add({'role': 'user', 'content': message});
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? 'guest';
      _userChatHistories[uid] = List<Map<String, String>>.from(_chatHistory);
      _textController.clear();
      _text = '';
    });
    _scrollToBottom();
    await _sendMessageToGroq(message);
  }

  // Helper to extract JSON and conversational reply from AI response
  Map<String, dynamic>? _extractJsonBlock(String text) {
    try {
      final regex = RegExp(r'\{[\s\S]*?\}');
      final match = regex.firstMatch(text);
      if (match != null) {
        final jsonString = match.group(0);
        if (jsonString != null) {
          debugPrint('[Chatbot] Extracted JSON: $jsonString');
          return jsonDecode(jsonString);
        }
      }
    } catch (e) {
      debugPrint('[Chatbot] Failed to parse JSON from AI response: $e');
    }
    debugPrint('[Chatbot] No JSON found in AI response.');
    return null;
  }

  String _extractReplyAfterJson(String text) {
    final regex = RegExp(r'\{[\s\S]*?\}');
    final match = regex.firstMatch(text);
    if (match != null) {
      final jsonEnd = match.end;
      return text.substring(jsonEnd).trim();
    }
    return text.trim();
  }

  // --- Groq TTS function ---
  Future<void> _speakWithGroqTTS(String text) async {
    const ttsVoice = 'alloy';
    final url = Uri.parse('https://api.groq.com/openai/v1/audio/speech');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };
    final body = jsonEncode({
      'model': 'tts-1',
      'input': text,
      'voice': ttsVoice,
    });
    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final audioBytes = response.bodyBytes;
        final player = AudioPlayer();
        await player.play(BytesSource(audioBytes));
        debugPrint('[GroqTTS] Played TTS audio successfully.');
      } else {
        debugPrint('[GroqTTS] TTS API error: \\${response.statusCode}');
        throw Exception('Groq TTS error: \\${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[GroqTTS] Exception: $e');
      rethrow;
    }
  }

  Future<void> _sendMessageToGroq(String message) async {
    setState(() {
      _isAwaitingAI = true;
    });
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };
    final userType = getUserType(context);
    final userContext = getUserContext(context);
    final modeContext = await getModeContext();

    // --- Enhanced system prompt for Wellness users ---
    String wellnessEnhancement = '';
    if (userType == 'Wellness') {
      final profileProvider = Provider.of<UserProfileProvider>(
        context,
        listen: false,
      );
      final profile = profileProvider.profile;
      String goal = profile?.wellnessGoal ?? '';
      String obstacle = profile?.wellnessObstacle ?? '';
      wellnessEnhancement =
          '\nThe user is a Wellness user. Please be especially motivational, positive, and focus on actionable wellness tips, encouragement, and habit-building. Celebrate small wins and progress. Offer gentle nudges for consistency, self-care, and balance.' +
          (goal.isNotEmpty
              ? '\nTheir current wellness goal is: "$goal".'
              : '') +
          (obstacle.isNotEmpty ? '\nTheir main obstacle is: "$obstacle".' : '');
    }

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'guest';
    final systemPrompt =
        "You are Osmos, a friendly, discreet health assistant. Here is the user context: $userContext. $modeContext" +
        wellnessEnhancement +
        "\n- If the user mentions eating food, log it as JSON: { \"log_type\": \"food\", \"foods\": [...], \"meal\": \"...\", \"amount\": \"...\", \"notes\": \"...\" } and reply naturally, e.g., 'Ouh, sounds nice! I'll log that for you.'\n- If the user mentions a symptom or health reading (e.g., blood sugar), log as JSON: { \"log_type\": \"symptom\", \"symptom\": \"...\", \"severity\": \"...\", \"notes\": \"...\" } and reply with empathy and a helpful suggestion, e.g., 'I'm sorry to hear your blood sugar is low. Would you like some tips to help with that?'\n- If the user mentions an appointment, log as JSON: { \"log_type\": \"appointment\", \"title\": \"...\", \"date\": \"2024-06-10T14:00:00\", \"place\": \"...\" } and confirm in a friendly way.\n- If the user mentions a workout or exercise (e.g., running, walking, cycling, gym), log as JSON: { \"log_type\": \"workout\", \"type\": \"Run\", \"distanceKm\": 5.0, \"durationMin\": 30, \"calories\": 400, \"dateTime\": \"2024-06-10T07:00:00\" } and reply with encouragement, e.g., 'Great job on your run! I've logged it for you.'\n- If the user is 'Away' or in a sub-mode like 'Dining', suggest healthy food options that can be found in restaurants or on the go.\n- When suggesting a place to eat, ONLY use the names from the provided list of nearby healthy restaurants. Do NOT invent or make up any other restaurant names. If you cannot determine the user's location, ONLY use the Geneva fallback list provided.\n- Always include the JSON log first, then your conversational reply.\n- Adapt your tone: for Patients, be supportive and practical; for Wellness users, be encouraging; for Caregivers, be informative and gentle.\n- Be brief and discreet, never over-explain the logging.";
    final body = jsonEncode({
      "model": "llama3-8b-8192",
      "messages": [
        {"role": "system", "content": systemPrompt},
        ..._userChatHistories[uid]!.map(
          (m) => {"role": m['role'], "content": m['content']},
        ),
        {"role": "user", "content": message},
      ],
      "max_tokens": 256,
      "temperature": 0.7,
    });
    try {
      final response = await http.post(url, headers: headers, body: body);
      debugPrint('[Chatbot] AI raw response: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiMessage = data['choices'][0]['message']['content'];
        debugPrint('[Chatbot] AI message: $aiMessage');
        final log = _extractJsonBlock(aiMessage);
        final reply = _extractReplyAfterJson(aiMessage);
        if (log != null && log['log_type'] == 'food') {
          debugPrint('[Chatbot] Detected food log JSON: $log');
          await _logFoodToFirestore(log);
        } else if (log != null && log['log_type'] == 'symptom') {
          debugPrint('[Chatbot] Detected symptom log JSON: $log');
          await _logSymptomToFirestore(log);
        } else if (log != null && log['log_type'] == 'appointment') {
          debugPrint('[Chatbot] Detected appointment log JSON: $log');
          await _logAppointmentToFirestore(log);
        } else if (log != null && log['log_type'] == 'workout') {
          debugPrint('[Chatbot] Detected workout log JSON: $log');
          await _logWorkoutToFirestore(log);
        } else {
          debugPrint('[Chatbot] No valid log JSON found.');
        }
        setState(() {
          _chatHistory.add({'role': 'assistant', 'content': reply});
          _userChatHistories[uid] = List<Map<String, String>>.from(
            _chatHistory,
          );
          _isAwaitingAI = false;
        });
      } else if (response.statusCode == 401) {
        debugPrint(
          '[Chatbot] AI service error: 401 Unauthorized. Check your API key.',
        );
        setState(() {
          _chatHistory.add({
            'role': 'assistant',
            'content':
                'Sorry, there was an authentication error with the AI service (401 Unauthorized). Please check your API key.',
          });
          _userChatHistories[uid] = List<Map<String, String>>.from(
            _chatHistory,
          );
          _isAwaitingAI = false;
        });
      } else {
        debugPrint('[Chatbot] AI service error: ${response.statusCode}');
        setState(() {
          _chatHistory.add({
            'role': 'assistant',
            'content':
                'Sorry, there was an error with the AI service. (${response.statusCode})',
          });
          _userChatHistories[uid] = List<Map<String, String>>.from(
            _chatHistory,
          );
          _isAwaitingAI = false;
        });
      }
    } catch (e) {
      debugPrint('[Chatbot] Exception: $e');
      setState(() {
        _chatHistory.add({
          'role': 'assistant',
          'content': 'Sorry, I could not connect to the AI service. ($e)',
        });
        final user = FirebaseAuth.instance.currentUser;
        final uid = user?.uid ?? 'guest';
        _userChatHistories[uid] = List<Map<String, String>>.from(_chatHistory);
        _isAwaitingAI = false;
      });
    }
  }

  Future<void> _logFoodToFirestore(Map<String, dynamic> foodLog) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[Chatbot] No user logged in, cannot log food.');
      return;
    }
    final foods =
        (foodLog['foods'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final meal = foodLog['meal']?.toString() ?? '';
    final now = DateTime.now();
    final amount = foodLog['amount']?.toString() ?? '';
    final notes = foodLog['notes']?.toString() ?? '';
    final calories = foodLog['calories'];
    final carbs = foodLog['carbs'];
    final protein = foodLog['protein'];
    final fat = foodLog['fat'];
    for (final food in foods) {
      try {
        debugPrint('[Chatbot] Writing food log to Firestore: $food');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('food_logs')
            .add({
              'foodName': food,
              'amount': amount,
              'mealType': meal,
              'notes': notes,
              'dateTime': now,
              'calories': calories,
              'carbs': carbs,
              'protein': protein,
              'fat': fat,
            });
        debugPrint('[Chatbot] Successfully logged food: $food');
      } catch (e) {
        debugPrint('[Chatbot] Firestore write error for $food: $e');
      }
    }
  }

  Future<void> _logSymptomToFirestore(Map<String, dynamic> log) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[Chatbot] No user logged in, cannot log symptom.');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('symptoms')
          .add({
            'description': log['symptom'] ?? '',
            'severity': log['severity'] ?? '',
            'notes': log['notes'] ?? '',
            'timestamp': DateTime.now(),
          });
      debugPrint('[Chatbot] Successfully logged symptom.');
    } catch (e) {
      debugPrint('[Chatbot] Firestore write error for symptom: $e');
    }
  }

  Future<void> _logAppointmentToFirestore(Map<String, dynamic> log) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[Chatbot] No user logged in, cannot log appointment.');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appointments')
          .add({
            'title': log['title'] ?? '',
            'date': log['date'] ?? '',
            'place': log['place'] ?? '',
            'notes': log['notes'] ?? '',
            'timestamp': DateTime.now(),
          });
      debugPrint('[Chatbot] Successfully logged appointment.');
    } catch (e) {
      debugPrint('[Chatbot] Firestore write error for appointment: $e');
    }
  }

  Future<void> _logWorkoutToFirestore(Map<String, dynamic> log) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[Chatbot] No user logged in, cannot log workout.');
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('workouts')
          .add({
            'type': log['type'] ?? '',
            'distanceKm': log['distanceKm'] ?? 0,
            'durationMin': log['durationMin'] ?? 0,
            'calories': log['calories'] ?? 0,
            'dateTime':
                log['dateTime'] != null
                    ? DateTime.tryParse(log['dateTime']) ?? DateTime.now()
                    : DateTime.now(),
          });
      debugPrint('[Chatbot] Successfully logged workout.');
    } catch (e) {
      debugPrint('[Chatbot] Firestore write error for workout: $e');
    }
  }

  void _startTypingEffect(String fullText) {
    _typingTimer?.cancel();
    setState(() {
      _typingAIMessage = '';
      _typingIndex = 0;
    });
    _typingTimer = Timer.periodic(const Duration(milliseconds: 22), (timer) {
      if (_typingIndex < fullText.length) {
        setState(() {
          _typingAIMessage = fullText.substring(0, _typingIndex + 1);
          _typingIndex++;
        });
        _scrollToBottom();
      } else {
        timer.cancel();
        setState(() {
          _chatHistory.add({'role': 'assistant', 'content': fullText});
          _typingAIMessage = null;
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Ask Osmos',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1.1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic),
            tooltip: 'Vocal Mode',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VocalChatbotVocalScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                itemCount:
                    _chatHistory.length + (_typingAIMessage != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_typingAIMessage != null &&
                      index == _chatHistory.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: _ChatBubble(
                        content: _typingAIMessage!,
                        isUser: false,
                        isTyping: true,
                        isSpeaking: _isAISpeaking,
                        aiSpeakingAnim: _aiSpeakingAnimController,
                      ),
                    );
                  }
                  final message = _chatHistory[index];
                  final isUser = message['role'] == 'user';
                  final isLastAI =
                      !isUser &&
                      index ==
                          _chatHistory.lastIndexWhere(
                            (m) => m['role'] == 'assistant',
                          );
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: _ChatBubble(
                      content: message['content'] ?? '',
                      isUser: isUser,
                      isSpeaking: isLastAI && _isAISpeaking,
                      aiSpeakingAnim: _aiSpeakingAnimController,
                    ),
                  );
                },
              ),
            ),
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText:
                      _isListening ? 'Listening...' : 'Type your message...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  suffixIcon:
                      _isListening
                          ? Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: _AnimatedMicIcon(),
                          )
                          : null,
                ),
                onSubmitted: (text) {
                  if (text.isNotEmpty &&
                      !_isAwaitingAI &&
                      _typingAIMessage == null) {
                    _sendMessage(text);
                  }
                },
                enabled: !_isAwaitingAI && _typingAIMessage == null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isAwaitingAI || _typingAIMessage != null ? null : _listen,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                if (_textController.text.isNotEmpty &&
                    !_isAwaitingAI &&
                    _typingAIMessage == null) {
                  _sendMessage(_textController.text);
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(12.0),
                child: Icon(Icons.send, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  final bool isTyping;
  final bool isSpeaking;
  final AnimationController? aiSpeakingAnim;
  const _ChatBubble({
    required this.content,
    required this.isUser,
    this.isTyping = false,
    this.isSpeaking = false,
    this.aiSpeakingAnim,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isUser ? 18 : 4),
          topRight: Radius.circular(isUser ? 4 : 18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser && (isTyping || isSpeaking)) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child:
                  isTyping
                      ? const _AnimatedTypingDots()
                      : _AnimatedSoundWave(anim: aiSpeakingAnim),
            ),
          ],
          Flexible(
            child: Text(
              content,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedMicIcon extends StatefulWidget {
  @override
  State<_AnimatedMicIcon> createState() => _AnimatedMicIconState();
}

class _AnimatedMicIconState extends State<_AnimatedMicIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double scale = 1 + 0.18 * _controller.value;
        return Transform.scale(
          scale: scale,
          child: Icon(Icons.mic, color: AppColors.primary, size: 26),
        );
      },
    );
  }
}

class _AnimatedTypingDots extends StatefulWidget {
  const _AnimatedTypingDots();
  @override
  State<_AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<_AnimatedTypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double t = (_controller.value + i * 0.2) % 1.0;
            double scale = 0.7 + 0.6 * sin(t * pi);
            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                shape: BoxShape.circle,
              ),
              transform: Matrix4.identity()..scale(scale, scale),
            );
          },
        );
      }),
    );
  }
}

class _AnimatedSoundWave extends StatelessWidget {
  final AnimationController? anim;
  const _AnimatedSoundWave({this.anim});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim ?? kAlwaysDismissedAnimation,
      builder: (context, child) {
        double scale = 1 + 0.18 * (anim?.value ?? 0);
        return Transform.scale(
          scale: scale,
          child: Icon(Icons.graphic_eq, color: AppColors.primary, size: 22),
        );
      },
    );
  }
}
