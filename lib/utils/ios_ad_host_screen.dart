import 'package:flutter/material.dart';

/// iOS-only host route presented before a full-screen ad.
/// Popping it after the ad dismisses restores the Flutter view hierarchy.
class IosAdHostScreen extends StatefulWidget {
  final Future<void> Function(BuildContext hostContext) onHostReady;

  const IosAdHostScreen({
    super.key,
    required this.onHostReady,
  });

  @override
  State<IosAdHostScreen> createState() => _IosAdHostScreenState();
}

class _IosAdHostScreenState extends State<IosAdHostScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await widget.onHostReady(context);
      } catch (e) {
        debugPrint('IosAdHostScreen error: $e');
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}
