import 'package:flutter/material.dart';

class BreathingOverlayScreen extends StatefulWidget {
  const BreathingOverlayScreen({super.key, this.onSubmit});

  final ValueChanged<String>? onSubmit;

  @override
  State<BreathingOverlayScreen> createState() => _BreathingOverlayScreenState();
}

class _BreathingOverlayScreenState extends State<BreathingOverlayScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _circleScaleAnimation;
  late final Animation<double> _textOpacityAnimation;
  final TextEditingController _reasonController = TextEditingController();

  bool _isBreathingComplete = false;

  bool get _isSubmitEnabled =>
      _isBreathingComplete && _reasonController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _circleScaleAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 1.32)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.32, end: 1)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_animationController);

    _textOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.25, end: 1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0.25)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_animationController);

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isBreathingComplete = true;
        });
      }
    });

    _reasonController.addListener(() {
      setState(() {});
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_isSubmitEnabled) return;

    final reason = _reasonController.text.trim();
    FocusScope.of(context).unfocus();

    if (widget.onSubmit != null) {
      widget.onSubmit!(reason);
      return;
    }

    Navigator.of(context).maybePop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF0B0F1E),
              Color(0xFF121A33),
              Color(0xFF0B0D16),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxContentWidth = constraints.maxWidth > 520
                  ? 520.0
                  : constraints.maxWidth * 0.9;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Column(
                              children: <Widget>[
                                Transform.scale(
                                  scale: _circleScaleAnimation.value,
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const RadialGradient(
                                        center: Alignment(-0.2, -0.2),
                                        radius: 1,
                                        colors: <Color>[
                                          Color(0xFF7BA7FF),
                                          Color(0xFF5476C9),
                                          Color(0xFF30467D),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.28),
                                        width: 1.2,
                                      ),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: const Color(0xFF87A5FF)
                                              .withValues(alpha: 0.28),
                                          blurRadius: 30,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Opacity(
                                  opacity: _textOpacityAnimation.value,
                                  child: Text(
                                    'Take a deep breath...',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 44),
                        TextField(
                          controller: _reasonController,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Why do you want to open this app?',
                            labelStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                            hintText: 'Type your reason...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.20),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF8FB1FF),
                                width: 1.2,
                              ),
                            ),
                          ),
                          onSubmitted: (_) {
                            if (_isSubmitEnabled) {
                              _handleSubmit();
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isSubmitEnabled ? _handleSubmit : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6B8DE7),
                              disabledBackgroundColor:
                                  Colors.white.withValues(alpha: 0.18),
                              foregroundColor: Colors.white,
                              disabledForegroundColor:
                                  Colors.white.withValues(alpha: 0.45),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              _isBreathingComplete
                                  ? 'Submit'
                                  : 'Complete breath first',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
