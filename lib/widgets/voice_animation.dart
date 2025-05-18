import 'package:flutter/material.dart';
import 'dart:math' as math;

class VoiceAnimation extends StatefulWidget {
  final bool isListening;
  final bool isProcessing;
  final double amplitude;
  
  const VoiceAnimation({
    Key? key, 
    required this.isListening, 
    required this.isProcessing,
    this.amplitude = 0.0,
  }) : super(key: key);

  @override
  State<VoiceAnimation> createState() => _VoiceAnimationState();
}

class _VoiceAnimationState extends State<VoiceAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Color> _colors = [
    const Color(0xFF00B77D), // Primary color
    const Color(0xFF00A36C), // Slightly darker
    const Color(0xFF008F5B), // Even darker
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.isListening || widget.isProcessing ? 120.0 : 80.0,
      height: widget.isListening || widget.isProcessing ? 120.0 : 80.0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base circle
          Container(
            width: 60.0,
            height: 60.0,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.isListening 
                ? Icons.mic 
                : (widget.isProcessing ? Icons.hourglass_top : Icons.mic_none),
              color: Colors.white,
              size: 30.0,
            ),
          ),
          
          // Animated circles for listening
          if (widget.isListening)
            ...List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Calculate dynamic radius based on amplitude
                  final baseRadius = 30.0 + (index * 10.0);
                  final amplitudeEffect = widget.amplitude * 20.0 * (index + 1);
                  final radius = baseRadius + amplitudeEffect;
                  
                  return Opacity(
                    opacity: 0.7 - (index * 0.2),
                    child: Transform.scale(
                      scale: 1.0 + (_controller.value + (index * 0.33)) % 1.0,
                      child: Container(
                        width: radius * 2,
                        height: radius * 2,
                        decoration: BoxDecoration(
                          color: _colors[index],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          
          // Processing animation
          if (widget.isProcessing)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _controller.value * 2 * math.pi,
                  child: Container(
                    width: 100.0,
                    height: 100.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3.0,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}