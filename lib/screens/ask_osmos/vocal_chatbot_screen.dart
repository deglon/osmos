import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../../widgets/voice_animation.dart';

// Extension to get last N elements from a list
extension ListExtension<T> on List<T> {
  List<T> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}

class VocalChatbotScreen extends StatefulWidget {
  const VocalChatbotScreen({Key? key}) : super(key: key);

  @override
  State<VocalChatbotScreen> createState() => _VocalChatbotScreenState();
}

class _VocalChatbotScreenState extends State<VocalChatbotScreen> with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isStreaming = false;
  double _streamProgress = 0.0;
  double _voiceAmplitude = 0.0;
  String _text = '';
  List<Map<String, String>> _chatHistory = [];

  // Flag to determine whether to use local model or Groq
  bool _useLocalModel = true;

  // Add the missing API key
  // IMPORTANT: Replace with your actual Groq API key.
  // Consider using environment variables or a secure method instead of hardcoding.
  final String _apiKey = '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';

  // Response cache
  final Map<String, String> _responseCache = {};

  // Animation controller for voice visualization
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Add initial greeting
    _chatHistory.add({
      'role': 'assistant',
      'content': 'Hello! I\'m Osmos, your health assistant. How can I help you today?'
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    _pulseController.dispose();
    super.dispose();
  }

  // Initialize speech recognition
  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done') {
          setState(() {
            _isListening = false;
            _voiceAmplitude = 0.0;
          });
          _processVoiceInput();
        }
      },
      // onSoundLevelChange is now handled directly in the listen method
    );
  }

  // Initialize text-to-speech
  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  // Start listening to voice input
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
          onSoundLevelChange: (level) {
            setState(() {
              _voiceAmplitude = (level < 0 ? 0 : level) / 100;
            });
          },
        );
      }
    } else {
      setState(() {
        _isListening = false;
        _voiceAmplitude = 0.0;
      });
      _speech.stop();
    }
  }

  // Process the voice input
  Future<void> _processVoiceInput() async {
    if (_text.isNotEmpty) {
      _sendMessage(_text);
    }
  }

  // Send message to chatbot
  String? _getQuickResponse(String message) {
    final lowerMessage = message.toLowerCase();

    // Map of common questions and their answers
    final Map<String, String> quickResponses = {
      'hello': "Hello! How can I help with your diabetes management today?",
      'hi': "Hi there! How can I assist you with your health today?",
      'how are you': "I'm here and ready to help with your health questions!",
      'what is diabetes': "Diabetes is a chronic condition that affects how your body processes blood sugar (glucose). There are several types, with Type 1 and Type 2 being the most common.",
      'what should my blood sugar be': "For most people with diabetes, the target blood glucose range is 80-130 mg/dL before meals and less than 180 mg/dL after meals.",
      'what foods should i avoid': "It's best to limit foods high in added sugars, refined carbs, and processed foods. Focus on vegetables, lean proteins, healthy fats, and moderate amounts of whole grains.",
      'how often should i check my blood sugar': "This varies by individual, but typically 1-4 times daily for Type 2 diabetes and 4-10 times daily for Type 1 diabetes.",
      'what are symptoms of low blood sugar': "Symptoms include shakiness, sweating, confusion, irritability, dizziness, hunger, and in severe cases, loss of consciousness.",
      'what are symptoms of high blood sugar': "Symptoms include frequent urination, increased thirst, blurred vision, fatigue, and headaches.",
    };

    // Check for matches
    for (final entry in quickResponses.entries) {
      if (lowerMessage.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Add user message to chat history
    setState(() {
      _chatHistory.add({'role': 'user', 'content': message});
      _isProcessing = true;
      _textController.clear();
      _text = '';
    });

    // Scroll to bottom of chat
    _scrollToBottom();

    // Check for quick responses first
    final quickResponse = _getQuickResponse(message);
    if (quickResponse != null) {
      setState(() {
        _chatHistory.add({'role': 'assistant', 'content': quickResponse});
        _isProcessing = false;
      });

      // Speak the response
      await _flutterTts.speak(quickResponse);
      return;
    }

    // Check cache for similar questions
    final String? cachedResponse = _checkCache(message);
    if (cachedResponse != null) {
      setState(() {
        _chatHistory.add({'role': 'assistant', 'content': cachedResponse});
        _isProcessing = false;
      });

      // Speak the response
      await _flutterTts.speak(cachedResponse);
      return;
    }

    // Continue with normal processing...
    if (_useLocalModel) {
      try {
        await _sendMessageToLocalModel(message);
      } catch (e) {
        print('Error with local model: $e');
        // If local model fails, fall back to Groq
        await _sendMessageToGroq(message);
      }
    } else {
      // Use Groq API
      await _sendMessageToGroq(message);
    }

    // Scroll to bottom of chat is handled within the model methods now
  }

  // Add this method to check the cache
  String? _checkCache(String message) {
    // Normalize the message (lowercase, remove punctuation)
    final normalizedMessage = message.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

    // Check for exact matches
    if (_responseCache.containsKey(normalizedMessage)) {
      return _responseCache[normalizedMessage];
    }

    // Check for similar questions (simple implementation)
    for (final entry in _responseCache.entries) {
      final key = entry.key;
      if (key.contains(normalizedMessage) || normalizedMessage.contains(key)) {
        return entry.value;
      }
    }

    return null;
  }

  // Add this method to update the cache
  void _updateCache(String question, String answer) {
    final normalizedQuestion = question.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    _responseCache[normalizedQuestion] = answer;

    // Limit cache size to prevent memory issues
    if (_responseCache.length > 50) {
      final oldestKey = _responseCache.keys.first;
      _responseCache.remove(oldestKey);
    }
  }

  // Send message to local Ollama model with streaming
  Future<void> _sendMessageToLocalModel(String message) async {
    // Prepare messages for API
    final List<Map<String, String>> messages = [
      {'role': 'system', 'content': 'You are Osmos, a helpful health assistant specializing in diabetes management. Provide concise, accurate information about diabetes care, nutrition, exercise, medication, and general health. Keep responses brief and focused on health topics.'},
      ..._chatHistory.takeLast(5),
    ];

    // Add a placeholder for the assistant's response
    setState(() {
      _chatHistory.add({'role': 'assistant', 'content': ''});
      _isProcessing = true;
      _isStreaming = true;
      _streamProgress = 0.0;
    });

    // Call Ollama API with streaming enabled
    final request = http.Request('POST', Uri.parse('http://localhost:11434/api/chat'));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'model': 'llama3', 
      'messages': messages,
      'stream': true,
      'options': {
        'temperature': 0.7,
        'max_tokens': 100,
      }
    });

    try {
      final streamedResponse = await http.Client().send(request);
      final stream = streamedResponse.stream.transform(utf8.decoder);

      String fullResponse = '';
      // int chunkCount = 0; // Not used

      await for (final chunk in stream) {
        try {
          // Each chunk is a complete JSON object
          final data = jsonDecode(chunk);
          // chunkCount++; // Not used

          if (data.containsKey('message') &&
              data['message'].containsKey('content')) {
            // Get the content from this chunk
            final content = data['message']['content'];

            // Append the content to the full response
            fullResponse += content;

            // Update the UI with the current response
            setState(() {
              _chatHistory.last['content'] = fullResponse;
              // Update progress based on done flag
              _streamProgress = data['done'] == true ? 1.0 : 0.5;
            });

            // Scroll to bottom as text appears
            _scrollToBottom();

            // If this is the final chunk, break
            if (data['done'] == true) {
              break;
            }
          }
        } catch (e) {
          print('Error parsing chunk: $e');
          // Handle parsing error, maybe stop streaming or show error message
          break; // Stop processing stream on error
        }
      }

      // Update the cache with the new response
      if (fullResponse.isNotEmpty) {
         _updateCache(message, fullResponse);
      }


      setState(() {
        _isProcessing = false;
        _isStreaming = false;
      });

      // Speak the response only after it's complete
      if (fullResponse.isNotEmpty) {
        await _flutterTts.speak(fullResponse);
      } else {
        // If we got no response, use a fallback
        final fallbackResponse = "I'm sorry, I couldn't generate a response from the local model. Falling back to Groq.";
         setState(() {
          // Update the last message if it's still empty or show a new one
          if (_chatHistory.isNotEmpty && _chatHistory.last['role'] == 'assistant' && _chatHistory.last['content']!.isEmpty) {
             _chatHistory.last['content'] = fallbackResponse;
          } else {
             _chatHistory.add({'role': 'assistant', 'content': fallbackResponse});
          }
        });
        await _flutterTts.speak(fallbackResponse);
        // Attempt to send to Groq if local failed
        await _sendMessageToGroq(message);
      }

    } catch (e) {
      print('Error sending message to local model: $e');
       final fallbackResponse = "I'm sorry, I couldn't connect to the local model. Falling back to Groq.";
       setState(() {
          // Update the last message if it's still empty or show a new one
          if (_chatHistory.isNotEmpty && _chatHistory.last['role'] == 'assistant' && _chatHistory.last['content']!.isEmpty) {
             _chatHistory.last['content'] = fallbackResponse;
          } else {
             _chatHistory.add({'role': 'assistant', 'content': fallbackResponse});
          }
        });
       await _flutterTts.speak(fallbackResponse);
       setState(() {
         _isProcessing = false;
         _isStreaming = false;
       });
       // Attempt to send to Groq if local failed
       await _sendMessageToGroq(message);
    }
     // Scroll to bottom of chat
    _scrollToBottom();
  }


  // Send message to Groq API (replaces _sendMessageToOpenAI)
  Future<void> _sendMessageToGroq(String message) async {
     // Add a placeholder for the assistant's response if not already added by local model fallback
     if (_chatHistory.isEmpty || _chatHistory.last['role'] != 'assistant' || _chatHistory.last['content']!.isNotEmpty) {
        setState(() {
          _chatHistory.add({'role': 'assistant', 'content': ''});
          _isProcessing = true;
        });
     } else {
        // If placeholder exists from local model fallback, just set processing
        setState(() {
           _isProcessing = true;
        });
     }


    try {
      // Prepare messages for API
      final List<Map<String, String>> messages = [
        {'role': 'system', 'content': 'You are Osmos, a helpful health assistant specializing in diabetes management. Provide concise, accurate information about diabetes care, nutrition, exercise, medication, and general health. Keep responses brief and focused on health topics.'},
        ..._chatHistory.takeLast(10), // Only send the last 10 messages to reduce token usage
      ];

      // Call Groq API with exponential backoff
      int retryCount = 0;
      int maxRetries = 3;
      int baseDelay = 1000; // 1 second

      while (retryCount < maxRetries) {
        try {
          final response = await http.post(
            // Groq API Endpoint
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              // Choose a Groq model, e.g., 'llama3-8b-8192' or 'mixtral-8x7b-32768'
              'model': 'llama3-8b-8192', // Replace with your desired Groq model
              'messages': messages,
              'max_tokens': 150,
              'temperature': 0.7,
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final botResponse = data['choices'][0]['message']['content'];

            // Update the last message with the bot response
            setState(() {
              _chatHistory.last['content'] = botResponse;
              _isProcessing = false;
            });

            // Speak the response
            await _flutterTts.speak(botResponse);

            // Update cache
            _updateCache(message, botResponse);

            // Success, exit the retry loop
            break;
          } else if (response.statusCode == 429) {
            // Rate limit exceeded, retry after delay
            retryCount++;
            if (retryCount >= maxRetries) {
              throw Exception('Rate limit exceeded. Please try again later.');
            }

            // Exponential backoff with jitter
            final delay = baseDelay * (1 << retryCount) + (Random().nextInt(1000));
            await Future.delayed(Duration(milliseconds: delay));
          } else {
             // Handle other API errors
             final errorResponse = 'Error from Groq API: ${response.statusCode} - ${response.body}';
             print(errorResponse);
             setState(() {
                _chatHistory.last['content'] = 'Sorry, I encountered an error communicating with the Groq API.';
                _isProcessing = false;
             });
             await _flutterTts.speak('Sorry, I encountered an error.');
             break; // Exit retry loop on non-rate limit error
          }
        } catch (e) {
          print('Error during Groq API call: $e');
          retryCount++;
          if (retryCount >= maxRetries) {
             // If max retries reached, show a final error message
             setState(() {
                _chatHistory.last['content'] = 'Sorry, I failed to get a response after multiple retries.';
                _isProcessing = false;
             });
             await _flutterTts.speak('Sorry, I could not get a response.');
            rethrow; // Rethrow the exception after exhausting retries
          }
          await Future.delayed(Duration(milliseconds: baseDelay * (1 << retryCount)));
        }
      }
    } catch (e) {
      print('Final Error after Groq API retries: $e');
      // This catch block handles the rethrown exception if retries fail
      setState(() {
        // Ensure a message is shown even if retries fail
        if (_chatHistory.isEmpty || _chatHistory.last['role'] != 'assistant' || _chatHistory.last['content']!.isEmpty) {
           _chatHistory.add({
            'role': 'assistant',
            'content': 'Sorry, I encountered a persistent error and cannot respond right now.'
           });
        } else {
           _chatHistory.last['content'] = 'Sorry, I encountered a persistent error and cannot respond right now.';
        }
        _isProcessing = false;
      });
       await _flutterTts.speak('Sorry, I encountered a persistent error.');
    }

    // Scroll to bottom of chat
    _scrollToBottom();
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
      appBar: AppBar(
        title: const Text('Ask Osmos'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // Toggle switch for local model vs Groq
          Switch(
            value: _useLocalModel,
            onChanged: (value) {
              setState(() {
                _useLocalModel = value;
              });
            },
            activeColor: Colors.white,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Text(
              _useLocalModel ? 'Local AI' : 'Groq AI', // Updated label
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _chatHistory.length,
              itemBuilder: (context, index) {
                final message = _chatHistory[index];
                final isUser = message['role'] == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Text(
                      message['content'] ?? '',
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Live transcription area
          if (_isListening && _text.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12.0),
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _text,
                style: TextStyle(color: Colors.grey[800]),
              ),
            ),

          // Voice animation
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: GestureDetector(
                onTap: _listen,
                child: VoiceAnimation(
                  isListening: _isListening,
                  isProcessing: _isProcessing,
                  amplitude: _voiceAmplitude,
                ),
              ),
            ),
          ),

          // Input area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                    ),
                    onSubmitted: (text) {
                      if (text.isNotEmpty) {
                        _sendMessage(text);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_textController.text.isNotEmpty) {
                      _sendMessage(_textController.text);
                    }
                  },
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}