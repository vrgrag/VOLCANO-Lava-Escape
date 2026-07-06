import 'package:flutter/material.dart';

/// Renders "Loading" followed by a cycling 1-3 dot animation, e.g.
/// "Loading.", "Loading..", "Loading...".
class LoadingDotsText extends StatefulWidget {
  const LoadingDotsText({super.key, this.text = 'Loading', this.style});

  final String text;
  final TextStyle? style;

  @override
  State<LoadingDotsText> createState() => _LoadingDotsTextState();
}

class _LoadingDotsTextState extends State<LoadingDotsText> {
  int _dots = 1;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(() {
      setState(() => _dots = (_dots % 3) + 1);
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.text}${'.' * _dots}',
      style: widget.style,
    );
  }
}

/// Minimal periodic ticker to avoid pulling in an AnimationController for
/// a simple repeating text change.
class Ticker {
  Ticker(this._onTick);

  final VoidCallback _onTick;
  bool _active = false;

  void start() {
    _active = true;
    _loop();
  }

  Future<void> _loop() async {
    while (_active) {
      await Future.delayed(const Duration(milliseconds: 450));
      if (_active) _onTick();
    }
  }

  void dispose() {
    _active = false;
  }
}
