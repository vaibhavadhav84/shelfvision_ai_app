import 'package:flutter/material.dart';

class CameraControls extends StatelessWidget {
  final VoidCallback onCapture;
  final VoidCallback onRecordToggle;
  final bool isRecording;
  final VoidCallback? onSwitchCamera;

  const CameraControls({
    super.key,
    required this.onCapture,
    required this.onRecordToggle,
    required this.isRecording,
    this.onSwitchCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.black.withValues(alpha: 0.6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Video Record Button
          IconButton(
            iconSize: 40,
            icon: Icon(
              isRecording ? Icons.stop_circle : Icons.videocam,
              color: isRecording ? Colors.red : Colors.white,
            ),
            onPressed: onRecordToggle,
            tooltip: isRecording ? 'Stop Recording' : 'Record Video',
          ),

          // Photo Capture Button
          GestureDetector(
            onTap: onCapture,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                color: Colors.white24,
              ),
              child: Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                ),
              ),
            ),
          ),

          // Switch / Info
          IconButton(
            iconSize: 36,
            icon: const Icon(Icons.flip_camera_android, color: Colors.white),
            onPressed: onSwitchCamera,
            tooltip: 'Camera',
          ),
        ],
      ),
    );
  }
}
