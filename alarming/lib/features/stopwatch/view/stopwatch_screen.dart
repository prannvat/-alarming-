import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../core/theme/app_theme.dart';

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> with TickerProviderStateMixin {
  late final Ticker _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  
  // List of laps (duration of the lap)
  final List<Duration> _laps = [];
  
  // Duration of the current lap (not yet saved)
  Duration _currentLapDuration = Duration.zero;
  
  // Duration of all previous laps combined
  Duration _previousLapsDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (mounted) {
        setState(() {
          // Update UI every frame
          if (_stopwatch.isRunning) {
            _currentLapDuration = _stopwatch.elapsed - _previousLapsDuration;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _toggleStartStop() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _ticker.stop();
    } else {
      _stopwatch.start();
      _ticker.start();
    }
    setState(() {});
  }

  void _lapOrReset() {
    if (_stopwatch.isRunning) {
      // Lap
      setState(() {
        _laps.insert(0, _currentLapDuration);
        _previousLapsDuration = _stopwatch.elapsed;
        _currentLapDuration = Duration.zero;
      });
    } else {
      // Reset
      setState(() {
        _stopwatch.reset();
        _laps.clear();
        _previousLapsDuration = Duration.zero;
        _currentLapDuration = Duration.zero;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    String twoDigitCentiseconds = twoDigits((duration.inMilliseconds.remainder(1000) ~/ 10));
    return "$twoDigitMinutes:$twoDigitSeconds.$twoDigitCentiseconds";
  }

  @override
  Widget build(BuildContext context) {
    final totalDuration = _stopwatch.elapsed;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Digital Display
            Expanded(
              flex: 4,
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  _formatDuration(totalDuration),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                    fontSize: 86,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Lap/Reset Button
                  _buildCircleButton(
                    label: _stopwatch.isRunning ? 'Lap' : 'Reset',
                    color: const Color(0xFF3A3A3C),
                    textColor: Colors.white,
                    onPressed: _lapOrReset,
                  ),
                  
                  // Page Indicator (dots) - purely visual for now
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3A3A3C),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),

                  // Start/Stop Button
                  _buildCircleButton(
                    label: _stopwatch.isRunning ? 'Stop' : 'Start',
                    color: _stopwatch.isRunning 
                        ? const Color(0xFF330E0C) // Dark Red
                        : const Color(0xFF0A2A12), // Dark Green
                    textColor: _stopwatch.isRunning 
                        ? const Color(0xFFFF453A) // Red
                        : const Color(0xFF32D74B), // Green
                    onPressed: _toggleStartStop,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Laps List
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  const Divider(height: 1, color: Color(0xFF2C2C2E)),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _laps.length + (_stopwatch.isRunning || _stopwatch.elapsedTicks > 0 ? 1 : 0),
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        color: Color(0xFF2C2C2E),
                        indent: 16,
                      ),
                      itemBuilder: (context, index) {
                        // Current running lap is index 0 if running
                        // Saved laps follow
                        
                        int lapIndex;
                        Duration lapTime;
                        bool isCurrentLap = false;

                        if (index == 0 && (_stopwatch.isRunning || (_laps.isEmpty && _stopwatch.elapsedTicks > 0))) {
                          // This is the current live lap (or the only lap if stopped but not reset)
                          // Actually, if stopped, the current lap is still "pending" until reset or lap pressed?
                          // Apple logic: 
                          // If running: Top row is current lap (incrementing).
                          // If stopped: Top row is the last partial lap.
                          
                          lapIndex = _laps.length + 1;
                          lapTime = _currentLapDuration;
                          isCurrentLap = true;
                          
                          // If we have laps, the current one is just the elapsed minus previous
                          if (_laps.isNotEmpty) {
                             // _currentLapDuration is already calculated in ticker
                          } else {
                             lapTime = _stopwatch.elapsed;
                          }
                        } else {
                          // Saved laps
                          // If we are showing a current lap at 0, then saved laps start at 1
                          // If we are NOT showing a current lap (reset state), this block won't run for 0
                          
                          int adjustedIndex = index - 1;
                          lapIndex = _laps.length - adjustedIndex;
                          lapTime = _laps[adjustedIndex];
                        }

                        // Find best/worst laps for highlighting
                        Color textColor = Colors.white;
                        if (_laps.length >= 2 && !isCurrentLap) {
                          Duration min = _laps.reduce((a, b) => a < b ? a : b);
                          Duration max = _laps.reduce((a, b) => a > b ? a : b);
                          if (lapTime == min) textColor = const Color(0xFF32D74B); // Green
                          if (lapTime == max) textColor = const Color(0xFFFF453A); // Red
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          height: 44,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lap $lapIndex',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                _formatDuration(lapTime),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 17,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

  Widget _buildCircleButton({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
