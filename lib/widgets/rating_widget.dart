import 'package:flutter/material.dart';

class RatingWidget extends StatefulWidget {
  final int initialRating;
  final Function(int rating) onRatingChanged;
  final bool readOnly;
  final Color? color;

  const RatingWidget({
    super.key,
    this.initialRating = 0,
    required this.onRatingChanged,
    this.readOnly = false,
    this.color,
  });

  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget>
    with SingleTickerProviderStateMixin {
  late int _currentRating;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: widget.readOnly
              ? null
              : () {
                  setState(() {
                    _currentRating = index + 1;
                  });
                  _animationController.forward(from: 0);
                  widget.onRatingChanged(_currentRating);
                },
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final scale =
                  _currentRating > index ? 1.0 + (_animationController.value * 0.2) : 1.0;
              return Transform.scale(
                scale: scale,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        colors: [Color(0xFF2E4A9B), Color(0xFF1DA1F2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: Icon(
                      _currentRating > index ? Icons.star : Icons.star_border,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
