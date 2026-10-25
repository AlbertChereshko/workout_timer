import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Live digital wall-clock widget displaying current real time (HH:mm).
/// Updates automatically every second.
class RealTimeClock extends StatefulWidget {
  final TextStyle? textStyle;
  final Color? color;
  final double fontSize;
  final double scale;

  const RealTimeClock({
    super.key,
    this.textStyle,
    this.color,
    this.fontSize = 26,
    this.scale = 1.0,
  });

  @override
  State<RealTimeClock> createState() => _RealTimeClockState();
}

class _RealTimeClockState extends State<RealTimeClock> {
  late Timer _timer;
  late DateTime _currentTime;
  static final DateFormat _formatter = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = widget.textStyle ??
        GoogleFonts.chakraPetch(
          fontSize: widget.fontSize * widget.scale,
          fontWeight: FontWeight.w800,
          color: widget.color ?? Colors.white,
          letterSpacing: 2.0,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return Text(
      _formatter.format(_currentTime),
      style: effectiveStyle,
      textAlign: TextAlign.center,
    );
  }
}
