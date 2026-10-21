class YouTubeParser {
  // Regex pattern matching YouTube video IDs (11 chars)
  static final RegExp _videoRegex = RegExp(
    r'(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?|shorts)\/|.*[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );

  // Regex pattern matching YouTube playlist IDs
  static final RegExp _playlistRegex = RegExp(
    r'[?&]list=([a-zA-Z0-9_-]+)',
    caseSensitive: false,
  );

  /// Checks if the given URL is a YouTube link (video, shorts, playlist, embed, or youtu.be)
  static bool isYouTubeUrl(String url) {
    final trimmed = url.trim().toLowerCase();
    return trimmed.contains('youtube.com') || trimmed.contains('youtu.be');
  }

  /// Extracts the 11-character video ID from a YouTube URL if present
  static String? extractVideoId(String url) {
    if (url.trim().isEmpty) return null;
    final match = _videoRegex.firstMatch(url.trim());
    return match?.group(1);
  }

  /// Extracts the playlist ID from a YouTube URL if present
  static String? extractPlaylistId(String url) {
    if (url.trim().isEmpty) return null;
    final match = _playlistRegex.firstMatch(url.trim());
    return match?.group(1);
  }

  /// Checks if this URL is primarily a playlist
  static bool isPlaylist(String url) {
    final playlistId = extractPlaylistId(url);
    if (playlistId == null) return false;
    final videoId = extractVideoId(url);
    return videoId == null || url.contains('/playlist?');
  }

  /// Returns high-resolution maxresdefault thumbnail URL if video ID found
  static String? getThumbnailUrl(String url) {
    final videoId = extractVideoId(url);
    if (videoId != null) {
      return 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
    }
    return null;
  }

  /// Returns fallback hqdefault thumbnail URL if video ID found
  static String? getFallbackThumbnailUrl(String url) {
    final videoId = extractVideoId(url);
    if (videoId != null) {
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }
    return null;
  }

  /// Parses duration strings like "45m", "1h 30m", "25 mins", "2h", "90m" into total minutes
  static int parseDurationToMinutes(String? duration) {
    if (duration == null || duration.trim().isEmpty) return 0;
    final text = duration.trim().toLowerCase();
    int totalMinutes = 0;

    // Match hours: e.g. "2h", "1.5h", "2 hours", "1 hr"
    final hourRegex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:h|hr|hours?)');
    final hourMatch = hourRegex.firstMatch(text);
    if (hourMatch != null) {
      final hours = double.tryParse(hourMatch.group(1) ?? '0') ?? 0;
      totalMinutes += (hours * 60).round();
    }

    // Match minutes: e.g. "45m", "30 mins", "20 min", "15 minutes"
    final minRegex = RegExp(r'(\d+)\s*(?:m|min|mins|minutes?)');
    final minMatch = minRegex.firstMatch(text);
    if (minMatch != null) {
      // Ensure we don't pick up the 'm' from hours/other words
      final matchedVal = minMatch.group(1);
      if (matchedVal != null && !text.substring(0, minMatch.start).contains('h')) {
        totalMinutes += int.tryParse(matchedVal) ?? 0;
      } else if (matchedVal != null && hourMatch != null && minMatch.start > hourMatch.end) {
        totalMinutes += int.tryParse(matchedVal) ?? 0;
      }
    }

    // Fallback if user just entered a raw number like "45"
    if (hourMatch == null && minMatch == null) {
      final numOnly = int.tryParse(text);
      if (numOnly != null) {
        totalMinutes += numOnly;
      }
    }

    return totalMinutes;
  }

  /// Formats minutes into human-readable duration like "45m" or "3h 12m"
  static String formatMinutes(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) {
      return '${h}h ${m}m';
    } else if (h > 0) {
      return '${h}h';
    } else {
      return '${m}m';
    }
  }

  /// Formats a folder card summary: e.g., "6 Items • 3h 12m total" or "1 Item"
  static String formatFolderSummary(int count, int totalMinutes) {
    final itemText = count == 1 ? '1 Item' : '$count Items';
    if (totalMinutes > 0) {
      return '$itemText • ${formatMinutes(totalMinutes)} total';
    }
    return itemText;
  }
}
