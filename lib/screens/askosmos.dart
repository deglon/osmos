import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OSMOS App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF00785A),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const OsmosScreen(),
    );
  }
}

class OsmosScreen extends StatefulWidget {
  const OsmosScreen({super.key});

  @override
  State<OsmosScreen> createState() => _OsmosScreenState();
}

class _OsmosScreenState extends State<OsmosScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final TextEditingController _textController = TextEditingController();
  List<ChatMessage> _messages = [];
  late final GenerativeModel _model;
  bool _isGenerating = false;
  bool _isSpeaking = false;

  // Speech to Text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  Timer? _silenceTimer;
  bool _messageSent = false; // Flag pour empêcher les envois en double
  bool _listeningReactivationScheduled =
      false; // Nouveau flag pour éviter la réactivation en boucle

  // Text to Speech
  final FlutterTts _flutterTts = FlutterTts();

  // Image Picker
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initSpeech();
    _initTTS();
    _requestCameraPermission();
    _model = GenerativeModel(
      apiKey: 'AIzaSyASYyPxHaZ7DDWA39oBZCZitds6ZKsgogA',
      model: 'gemini-2.0-flash',
    );
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Animation plus rapide
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _requestCameraPermission() async {
    await Permission.camera.request();
  }

  void _initSpeech() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      // Initialiser avec des options spécifiques
      _speechEnabled = await _speech.initialize(
        onError: (error) => print("Erreur lors de l'initialisation: $error"),
        onStatus:
            (status) => print("Statut de la reconnaissance vocale: $status"),
        debugLogging: true,
      );
      setState(() {});
      print("Reconnaissance vocale initialisée: $_speechEnabled");
    } else {
      print("Permission microphone non accordée !");
    }
  }

  void _initTTS() async {
    await _flutterTts.setLanguage("fr-FR");
    await _flutterTts.setSpeechRate(1.0); // Vitesse légèrement plus lente
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(0.9); // Voix un peu plus grave

    // Lister et utiliser une voix spécifique (si disponible)
    try {
      List<dynamic>? voices = await _flutterTts.getVoices;
      if (voices != null && voices.isNotEmpty) {
        // Afficher les voix disponibles en console pour référence
        print("Voix disponibles: $voices");

        // Chercher une voix féminine française spécifique
        for (var voice in voices) {
          if (voice is Map &&
              voice['locale']?.toString().startsWith('fr') == true &&
              voice['name']?.toString().toLowerCase().contains('female') ==
                  true) {
            await _flutterTts.setVoice({
              "name": voice['name'],
              "locale": voice['locale'],
            });
            print("Voix sélectionnée: ${voice['name']}");
            break;
          }
        }
      }
    } catch (e) {
      print("Erreur lors de la configuration des voix: $e");
    }

    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });

      // Éviter de réactiver le micro si c'est déjà prévu
      if (mounted && !_listeningReactivationScheduled) {
        _listeningReactivationScheduled = true;

        // Utiliser un délai court pour éviter les déclenchements en boucle
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isListening && !_isSpeaking) {
            print(
              "Synthèse vocale terminée, réactivation du micro après délai.",
            );
            _startListening();
          }
          _listeningReactivationScheduled = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    _flutterTts.stop();
    _silenceTimer?.cancel();
    super.dispose();
  }

  String _sanitizeTextForSpeech(String text) {
    return text
        .replaceAll('*', '')
        .replaceAll('_', '')
        .replaceAll('`', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('/', '')
        .trim();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _textController.clear();
      _isGenerating = true;
      _messageSent = false; // Réinitialiser le flag après envoi réussi
    });

    try {
      // Ajouter des instructions pour des réponses courtes dans le prompt
      final String promptWithInstructions =
          "Réponds de façon très brève et synthétique (max 1-2 phrases) à cette question: $text";

      final response = await _model.generateContent([
        Content.text(promptWithInstructions),
      ]);
      final geminiResponse = response.text;
      if (geminiResponse != null) {
        // Limiter la longueur de la réponse si nécessaire
        String shortResponse = geminiResponse;
        if (shortResponse.length > 200) {
          // Trouver la fin de la phrase près de 200 caractères
          int endIndex = shortResponse.indexOf('.', 150);
          if (endIndex > 0 && endIndex < 300) {
            shortResponse = shortResponse.substring(0, endIndex + 1);
          } else {
            shortResponse = shortResponse.substring(0, 200) + "...";
          }
        }

        setState(() {
          _messages.add(ChatMessage(text: shortResponse, isUser: false));
          _isGenerating = false;
        });
        final String sanitizedResponse = _sanitizeTextForSpeech(shortResponse);
        await _flutterTts.speak(sanitizedResponse);
      } else {
        _handleError("Erreur : Impossible d'obtenir une réponse de l'IA.");
      }
    } catch (e) {
      _handleError("Erreur de communication avec l'IA : $e");
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _sendImageMessage(File imageFile) async {
    setState(() {
      _messages.add(
        ChatMessage(text: "Image envoyée", isUser: true, imageFile: imageFile),
      );
      _isGenerating = true;
    });

    try {
      final String responseText =
          "J'ai bien reçu votre image. Comment puis-je vous aider avec cela?";

      setState(() {
        _messages.add(ChatMessage(text: responseText, isUser: false));
        _isGenerating = false;
      });

      await _flutterTts.speak(responseText);
    } catch (e) {
      _handleError("Erreur lors du traitement de l'image : $e");
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _startListening() async {
    // Réinitialiser le flag lorsque nous commençons à écouter
    _messageSent = false;

    // Annuler tout timer existant
    _silenceTimer?.cancel();
    _silenceTimer = null;

    if (_isListening) {
      // Si déjà en train d'écouter, arrêter d'abord
      await _speech.stop();
    }

    setState(() {
      _isListening = true;
    });

    print("Démarrage de l'écoute...");

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted || !_isListening || _messageSent) return;

          setState(() {
            _textController.text = result.recognizedWords;
            print(
              "Résultat: '${result.recognizedWords}', final: ${result.finalResult}",
            );
          });

          // Si nous avons un résultat final
          if (result.finalResult &&
              result.recognizedWords.isNotEmpty &&
              !_messageSent) {
            print("Résultat final détecté, préparation à l'envoi...");
            _prepareToSendMessage();
            return;
          }

          // Sinon, réinitialiser le timer de silence
          _resetSilenceTimer();
        },
        listenFor: const Duration(seconds: 30), // Durée max d'une écoute
        pauseFor: const Duration(seconds: 2), // Durée de pause avant arrêt auto
        partialResults: true,
        cancelOnError: true,
      );
    } catch (e) {
      print("Exception lors du démarrage de l'écoute: $e");
      _stopListening();
    }
  }

  void _resetSilenceTimer() {
    // Annuler tout timer existant
    _silenceTimer?.cancel();

    // Ne pas créer de nouveau timer si on a déjà envoyé un message
    if (_messageSent) return;

    // Créer un nouveau timer
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      _prepareToSendMessage();
    });
  }

  void _prepareToSendMessage() {
    if (!mounted || !_isListening || _messageSent) return;

    final String messageText = _textController.text.trim();
    if (messageText.isEmpty) {
      _stopListening();
      return;
    }

    print("Préparation de l'envoi du message: '$messageText'");

    // Marquer comme envoyé pour éviter les doublons
    _messageSent = true;

    // Arrêter l'écoute avant d'envoyer
    _stopListening();

    // Envoyer le message
    _sendMessage(messageText);
  }

  void _stopListening() async {
    if (!_isListening) return;

    print("Arrêt de l'écoute...");

    // Annuler tout timer existant
    _silenceTimer?.cancel();
    _silenceTimer = null;

    setState(() {
      _isListening = false;
    });

    try {
      await _speech.stop();
    } catch (e) {
      print("Erreur lors de l'arrêt de l'écoute: $e");
    }
  }

  void _handleError(String errorMessage) {
    setState(() {
      _messages.add(ChatMessage(text: errorMessage, isUser: false));
    });
    _flutterTts.speak(errorMessage);
  }

  void _showConversationHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ConversationHistoryScreen(
              messages: _messages,
              onSendMessage: _sendMessage,
            ),
      ),
    );
  }

  Future<void> _takePicture() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      _imageFile = File(pickedFile.path);
      await _sendImageMessage(_imageFile!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Partie supérieure - Logo centré
        Expanded(flex: 3, child: Center(child: _buildAnimatedLogo())),
        // Partie inférieure - Contrôles de microphone
        Expanded(flex: 1, child: _buildMicrophoneControls()),
      ],
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          Icons.chevron_left,
          color: Color(0xFF00785A),
          size: 30,
        ),
        onPressed: () {},
      ),
      title: const Text(
        'OSMOS',
        style: TextStyle(
          color: Color(0xFF00785A),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF00785A)),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        // Calculer le déplacement avant-arrière basé sur l'animation
        final double offset =
            _isSpeaking ? ((_pulseAnimation.value - 1.0) * 60.0) : 0.0;

        return Transform.translate(
          // Déplacement sur l'axe Y (avant-arrière)
          offset: Offset(0, offset),
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4ECDC4), Color(0xFF00785A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00785A).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _isSpeaking ? Icons.graphic_eq : Icons.auto_awesome,
                color: Colors.white,
                size: _isSpeaking ? 90 : 70,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMicrophoneControls() {
    return Container(
      padding: const EdgeInsets.only(bottom: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionButton(
            icon: Icons.message,
            onPressed: () {
              _showConversationHistory();
            },
          ),
          const SizedBox(width: 20),
          _buildActionButton(
            icon: _isListening ? Icons.mic : Icons.mic_none,
            size: 80,
            iconSize: 35,
            color:
                _isListening ? const Color(0xFF00785A) : Colors.grey.shade700,
            onPressed: () {
              if (_speechEnabled) {
                if (_isListening) {
                  _stopListening();
                } else {
                  _startListening();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "La reconnaissance vocale n'est pas activée.",
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 20),
          _buildActionButton(
            icon: Icons.camera_alt, // Remplacé delete_outline par camera_alt
            onPressed: () {
              _takePicture(); // Nouvelle fonction pour prendre une photo
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 60,
    double iconSize = 28,
    Color? color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: iconSize, color: color ?? Colors.grey.shade700),
        onPressed: onPressed,
      ),
    );
  }
}

// Écran pour afficher l'historique des conversations
class ConversationHistoryScreen extends StatefulWidget {
  final List<ChatMessage> messages;
  final Function(String) onSendMessage;

  const ConversationHistoryScreen({
    super.key,
    required this.messages,
    required this.onSendMessage,
  });

  @override
  State<ConversationHistoryScreen> createState() =>
      _ConversationHistoryScreenState();
}

class _ConversationHistoryScreenState extends State<ConversationHistoryScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_textController.text.trim().isNotEmpty) {
      widget.onSendMessage(_textController.text);
      _textController.clear();
      Navigator.pop(context); // Retourner à l'écran principal après envoi
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            color: Color(0xFF00785A),
            size: 30,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Historique des conversations',
          style: TextStyle(
            color: Color(0xFF00785A),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Liste des messages
          Expanded(
            child:
                widget.messages.isEmpty
                    ? _buildEmptyState()
                    : _buildConversationList(),
          ),
          // Zone de saisie de texte
          _buildMessageInputField(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            'Aucune conversation',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Commencez à parler avec OSMOS pour voir vos messages ici',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              message.isUser ? const Color(0xFF00785A) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: const BoxConstraints(maxWidth: 280),
        child:
            message.imageFile != null
                ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        message.imageFile!,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (message.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color:
                                message.isUser ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                )
                : Text(
                  message.text,
                  style: TextStyle(
                    color: message.isUser ? Colors.white : Colors.black87,
                    fontSize: 16,
                  ),
                ),
      ),
    );
  }

  Widget _buildMessageInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          // Champ de saisie
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Écrivez votre message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.grey.shade100,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          // Bouton d'envoi
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00785A),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final File? imageFile;

  const ChatMessage({required this.text, required this.isUser, this.imageFile});
}
