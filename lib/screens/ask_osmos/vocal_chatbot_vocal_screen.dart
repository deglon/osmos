import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';

class AppColors {
  static const Color primary = Color(0xFF68B86C);
  static const Color background = Color(0xFFF5F5F5);
}

class VocalChatbotVocalScreen extends StatefulWidget {
  const VocalChatbotVocalScreen({Key? key}) : super(key: key);

  @override
  State<VocalChatbotVocalScreen> createState() =>
      _VocalChatbotVocalScreenState();
}

class _VocalChatbotVocalScreenState extends State<VocalChatbotVocalScreen>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, String>> _chatHistory = [];
  String? _currentTranscript;
  bool _isListening = false;
  bool _isAISpeaking = false;
  bool _isAwaitingAI = false;
  late AnimationController _aiSpeakingAnimController;
  late AnimationController _circleAnimController;
  final String _apiKey ='';
  String? _typingAIMessage;
  int _typingIndex = 0;
  Timer? _typingTimer;
  bool _userInterrupting = false;

  @override
  void initState() {
    super.initState();
    _aiSpeakingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _circleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initTts();
    _chatHistory.add({
      'role': 'assistant',
      'content':
          "Hello! I'm Osmos, your health assistant. How can I help you today?",
    });
    _startListening();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _flutterTts.stop();
    _aiSpeakingAnimController.dispose();
    _circleAnimController.dispose();
    _typingTimer?.cancel();
    super.dispose();
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
      if (!_userInterrupting) _startListening();
      _userInterrupting = false;
    });
  }

  void _startListening() async {
    if (_isAISpeaking) {
      await _flutterTts.stop();
      setState(() {
        _isAISpeaking = false;
        _userInterrupting = true;
      });
    }
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
        _currentTranscript = null;
      });
      _speech.listen(
        onResult: (result) {
          // If AI is speaking, interrupt and start listening
          if (_isAISpeaking) {
            _flutterTts.stop();
            setState(() {
              _isAISpeaking = false;
              _userInterrupting = true;
            });
          }
          setState(() {
            _currentTranscript = result.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 2),
        onSoundLevelChange: null,
        cancelOnError: true,
        partialResults: true,
        onDevice: true,
        localeId: 'en_US',
      );
      _speech.statusListener = (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          if ((_currentTranscript ?? '').trim().isNotEmpty) {
            _sendMessage(_currentTranscript!.trim());
          } else {
            _startListening();
          }
        }
      };
    }
  }

  Future<void> _sendMessage(String message) async {
    setState(() {
      _chatHistory.add({'role': 'user', 'content': message});
      _currentTranscript = null;
    });
    _scrollToBottom();
    await _sendMessageToGroq(message);
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
    final body = jsonEncode({
      "model": "llama3-8b-8192",
      "messages": [
        ..._chatHistory.map(
          (m) => {"role": m['role'], "content": m['content']},
        ),
        {"role": "user", "content": message},
      ],
      "max_tokens": 256,
      "temperature": 0.7,
    });
    debugPrint('[GroqTTS] Request URL: \\${url.toString()}');
    debugPrint('[GroqTTS] Request Headers: \\${headers.toString()}');
    debugPrint('[GroqTTS] Request Body: \\${body.toString()}');
    try {
      final response = await http.post(url, headers: headers, body: body);
      debugPrint('[GroqTTS] Response Status: \\${response.statusCode}');
      debugPrint('[GroqTTS] Response Body: \\${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiMessage = data['choices'][0]['message']['content'];
        setState(() {
          _typingAIMessage = '';
          _typingIndex = 0;
          _isAwaitingAI = false;
        });
        _startTypingEffect(aiMessage);
      } else {
        setState(() {
          _chatHistory.add({
            'role': 'assistant',
            'content':
                'Sorry, there was an error with the AI service. (${response.statusCode})',
          });
          _isAwaitingAI = false;
        });
        _startListening();
      }
    } catch (e) {
      setState(() {
        _chatHistory.add({
          'role': 'assistant',
          'content': 'Sorry, I could not connect to the AI service. ($e)',
        });
        _isAwaitingAI = false;
      });
      _startListening();
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
        _flutterTts.speak(fullText);
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
    final AICircleState aiState =
        _isListening
            ? AICircleState.listening
            : _isAISpeaking
            ? AICircleState.speaking
            : _isAwaitingAI
            ? AICircleState.thinking
            : AICircleState.idle;
    String statusText =
        _isListening
            ? 'Listening...'
            : _isAISpeaking
            ? 'Osmos is speaking...'
            : _isAwaitingAI
            ? 'Osmos is thinking...'
            : 'Say something to Osmos...';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Osmos Vocal Mode',
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
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Chat area with extra bottom padding
            Padding(
              padding: const EdgeInsets.only(bottom: 120),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                itemCount:
                    _chatHistory.length +
                    (_typingAIMessage != null ? 1 : 0) +
                    (_currentTranscript != null ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show transcript bubble if present and at the end
                  if (_currentTranscript != null &&
                      index ==
                          _chatHistory.length +
                              (_typingAIMessage != null ? 1 : 0)) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: _ChatBubble(
                        content:
                            _currentTranscript! + (_isListening ? ' ...' : ''),
                        isUser: true,
                        isTyping: true,
                        isSpeaking: false,
                        aiSpeakingAnim: null,
                      ),
                    );
                  }
                  // Show typing AI bubble if present
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
                  if (index >= _chatHistory.length)
                    return const SizedBox.shrink();
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
            // Animated AI Circle and status text at the bottom center
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AnimatedAICircle(
                    anim: _circleAnimController,
                    state: aiState,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _speakWithGroqTTS(String text) async {
    const ttsVoice = 'alloy';
    final url = Uri.parse('https://api.groq.com/openai/v1/audio/speech');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + _apiKey,
    };
    final body = jsonEncode({
      'model': 'tts-1',
      'input': text,
      'voice': ttsVoice,
    });
    debugPrint('[GroqTTS] Request URL: \\${url.toString()}');
    debugPrint('[GroqTTS] Request Headers: \\${headers.toString()}');
    debugPrint('[GroqTTS] Request Body: \\${body.toString()}');
    try {
      final response = await http.post(url, headers: headers, body: body);
      debugPrint('[GroqTTS] Response Status: \\${response.statusCode}');
      debugPrint('[GroqTTS] Response Body: \\${response.body}');
      if (response.statusCode == 200) {
        final audioBytes = response.bodyBytes;
        // Play audio as before (if needed)
        // ...
      } else {
        throw Exception('Groq TTS error: \\${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[GroqTTS] Exception: $e');
      rethrow;
    }
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
  const _AnimatedMicIcon();
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

enum AICircleState { idle, listening, thinking, speaking }

class _AnimatedAICircle extends StatelessWidget {
  final AnimationController anim;
  final AICircleState state;
  const _AnimatedAICircle({required this.anim, required this.state});

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.primary;
    double size = 64;
    Widget icon;
    switch (state) {
      case AICircleState.listening:
        icon = Icon(Icons.mic, color: Colors.white, size: 32);
        break;
      case AICircleState.speaking:
        icon = Icon(Icons.graphic_eq, color: Colors.white, size: 32);
        break;
      case AICircleState.thinking:
        icon = Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            double t = (anim.value + i * 0.2) % 1.0;
            double scale = 0.7 + 0.6 * sin(t * pi);
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              transform: Matrix4.identity()..scale(scale, scale),
            );
          }),
        );
        break;
      default:
        icon = Icon(Icons.circle, color: Colors.white, size: 28);
    }
    double pulse = 1 + 0.10 * anim.value;
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        return Transform.scale(
          scale: pulse,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.18),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(child: icon),
          ),
        );
      },
    );
  }
}
