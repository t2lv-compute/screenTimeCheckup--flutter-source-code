import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class FloatingBalloons extends StatefulWidget {
  final bool isPlaying;

  const FloatingBalloons({super.key, required this.isPlaying});

  @override
  State<FloatingBalloons> createState() => _FloatingBalloonsState();
}

class _FloatingBalloonsState extends State<FloatingBalloons>
    with TickerProviderStateMixin {
  final List<_BalloonData> _balloons = [];
  final Random _random = Random();
  late AnimationController _spawnController;
  Timer? _stopSpawningTimer;
  bool _spawning = false;

  static const Duration _spawnDuration = Duration(seconds: 4);

  static const List<Color> _balloonColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    Colors.cyan,
    Colors.teal,
    Colors.indigo,
  ];

  @override
  void initState() {
    super.initState();
    _spawnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_maybeSpawnBalloon);

    if (widget.isPlaying) {
      _startSpawning();
    }
  }

  @override
  void didUpdateWidget(FloatingBalloons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _startSpawning();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _spawning = false;
      _stopSpawningTimer?.cancel();
      _spawnController.stop();
    }
  }

  void _startSpawning() {
    _spawning = true;
    _spawnController.repeat();
    // Spawn initial batch
    for (int i = 0; i < 8; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted && _spawning) _spawnBalloon();
      });
    }
    // Stop spawning after the set duration; existing balloons float away naturally
    _stopSpawningTimer?.cancel();
    _stopSpawningTimer = Timer(_spawnDuration, () {
      if (mounted) {
        _spawning = false;
        _spawnController.stop();
      }
    });
  }

  void _maybeSpawnBalloon() {
    if (!_spawning) return;
    if (_random.nextDouble() < 0.08 && _balloons.length < 20) {
      _spawnBalloon();
    }
  }

  void _spawnBalloon() {
    if (!mounted) return;

    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3000 + _random.nextInt(2000)),
    );

    final balloon = _BalloonData(
      controller: controller,
      xPosition: _random.nextDouble(),
      xWobble: (_random.nextDouble() - 0.5) * 0.1,
      size: 30 + _random.nextDouble() * 25,
      color: _balloonColors[_random.nextInt(_balloonColors.length)],
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _balloons.remove(balloon);
          });
          controller.dispose();
        }
      }
    });

    setState(() {
      _balloons.add(balloon);
    });

    controller.forward();
  }

  @override
  void dispose() {
    _stopSpawningTimer?.cancel();
    _spawnController.dispose();
    for (final balloon in _balloons) {
      balloon.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: _balloons.map((balloon) {
          return AnimatedBuilder(
            animation: balloon.controller,
            builder: (context, child) {
              final progress = balloon.controller.value;
              final yOffset = 1.2 - (progress * 1.4); // Start below, end above
              final xOffset = balloon.xPosition +
                  sin(progress * pi * 4) * balloon.xWobble;

              return Positioned(
                left: xOffset * MediaQuery.of(context).size.width,
                top: yOffset * MediaQuery.of(context).size.height,
                child: Opacity(
                  opacity: progress < 0.1
                      ? progress * 10
                      : (progress > 0.9 ? (1 - progress) * 10 : 1),
                  child: _Balloon(
                    size: balloon.size,
                    color: balloon.color,
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

class _BalloonData {
  final AnimationController controller;
  final double xPosition;
  final double xWobble;
  final double size;
  final Color color;

  _BalloonData({
    required this.controller,
    required this.xPosition,
    required this.xWobble,
    required this.size,
    required this.color,
  });
}

class _Balloon extends StatelessWidget {
  final double size;
  final Color color;

  const _Balloon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Balloon body
        Container(
          width: size,
          height: size * 1.1,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size * 0.5),
          ),
        ),
        // Knot
        Container(
          width: size * 0.15,
          height: size * 0.1,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(size * 0.05),
          ),
        ),
        // String
        Container(
          width: 1,
          height: size * 1.5,
          color: Colors.grey.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}
