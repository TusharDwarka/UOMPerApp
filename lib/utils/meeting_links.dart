import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum MeetingPlatform { googleMeet, teams, zoom, other }

class MeetingLinks {
  /// Adds https:// when the user pasted a bare "meet.google.com/abc".
  static String? normalize(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return 'https://$s';
  }

  static bool isValid(String? raw) {
    final n = normalize(raw);
    if (n == null) return false;
    final uri = Uri.tryParse(n);
    return uri != null && uri.host.contains('.');
  }

  static MeetingPlatform platformOf(String url) {
    final host = Uri.tryParse(normalize(url) ?? '')?.host.toLowerCase() ?? '';
    if (host.contains('meet.google')) return MeetingPlatform.googleMeet;
    if (host.contains('teams.microsoft') || host.contains('teams.live')) return MeetingPlatform.teams;
    if (host.contains('zoom.us')) return MeetingPlatform.zoom;
    return MeetingPlatform.other;
  }

  static String label(String url) {
    switch (platformOf(url)) {
      case MeetingPlatform.googleMeet:
        return 'Join Meet';
      case MeetingPlatform.teams:
        return 'Join Teams';
      case MeetingPlatform.zoom:
        return 'Join Zoom';
      case MeetingPlatform.other:
        return 'Join call';
    }
  }

  static Color color(String url) {
    switch (platformOf(url)) {
      case MeetingPlatform.googleMeet:
        return const Color(0xFF00897B);
      case MeetingPlatform.teams:
        return const Color(0xFF5B5FC7);
      case MeetingPlatform.zoom:
        return const Color(0xFF2D8CFF);
      case MeetingPlatform.other:
        return const Color(0xFF2962FF);
    }
  }

  static Future<void> open(BuildContext context, String url) async {
    final uri = Uri.tryParse(normalize(url) ?? '');
    final messenger = ScaffoldMessenger.of(context);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not open the meeting link')));
    }
  }
}

/// Compact "Join Teams" pill used on class and event cards.
class JoinMeetingButton extends StatelessWidget {
  final String url;
  final bool dense;
  const JoinMeetingButton({super.key, required this.url, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final c = MeetingLinks.color(url);
    return Material(
      color: c,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: () => MeetingLinks.open(context, url),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14, vertical: dense ? 5 : 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_rounded, size: dense ? 14 : 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                MeetingLinks.label(url),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: dense ? 11 : 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
