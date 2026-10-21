import 'package:flutter_test/flutter_test.dart';
import 'package:arete/features/learn/utils/youtube_parser.dart';
import 'package:arete/features/learn/domain/learning_resource_model.dart';
import 'package:arete/features/learn/domain/learning_collection_model.dart';

void main() {
  group('YouTubeParser Tests', () {
    test('Correctly identifies YouTube URLs', () {
      expect(YouTubeParser.isYouTubeUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), isTrue);
      expect(YouTubeParser.isYouTubeUrl('https://youtu.be/dQw4w9WgXcQ'), isTrue);
      expect(YouTubeParser.isYouTubeUrl('https://youtube.com/shorts/dQw4w9WgXcQ'), isTrue);
      expect(YouTubeParser.isYouTubeUrl('https://www.youtube.com/playlist?list=PL12345'), isTrue);
      expect(YouTubeParser.isYouTubeUrl('https://medium.com/@author/story'), isFalse);
      expect(YouTubeParser.isYouTubeUrl('https://flutter.dev/docs'), isFalse);
    });

    test('Extracts YouTube Video ID and generates thumbnails', () {
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s';
      expect(YouTubeParser.extractVideoId(url), 'dQw4w9WgXcQ');
      expect(
        YouTubeParser.getThumbnailUrl(url),
        'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
      );
      expect(
        YouTubeParser.getFallbackThumbnailUrl(url),
        'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );

      const shortUrl = 'https://youtu.be/m8Icp_Cid5o';
      expect(YouTubeParser.extractVideoId(shortUrl), 'm8Icp_Cid5o');
    });

    test('Extracts YouTube Playlist ID and detects playlists', () {
      const playlistUrl = 'https://www.youtube.com/playlist?list=PLot-Xpze53ldVwtstag2TL4HQhAnC8ATf';
      expect(YouTubeParser.extractPlaylistId(playlistUrl), 'PLot-Xpze53ldVwtstag2TL4HQhAnC8ATf');
      expect(YouTubeParser.isPlaylist(playlistUrl), isTrue);

      const regularVideoUrl = 'https://www.youtube.com/watch?v=m8Icp_Cid5o';
      expect(YouTubeParser.isPlaylist(regularVideoUrl), isFalse);
    });

    test('Parses various duration formats into minutes', () {
      expect(YouTubeParser.parseDurationToMinutes('45m'), 45);
      expect(YouTubeParser.parseDurationToMinutes('1h 30m'), 90);
      expect(YouTubeParser.parseDurationToMinutes('2h'), 120);
      expect(YouTubeParser.parseDurationToMinutes('25 mins'), 25);
      expect(YouTubeParser.parseDurationToMinutes('1.5h'), 90);
      expect(YouTubeParser.parseDurationToMinutes('90 min'), 90);
      expect(YouTubeParser.parseDurationToMinutes('15'), 15);
      expect(YouTubeParser.parseDurationToMinutes(null), 0);
      expect(YouTubeParser.parseDurationToMinutes(''), 0);
    });

    test('Formats minutes into clean duration string', () {
      expect(YouTubeParser.formatMinutes(45), '45m');
      expect(YouTubeParser.formatMinutes(90), '1h 30m');
      expect(YouTubeParser.formatMinutes(120), '2h');
      expect(YouTubeParser.formatMinutes(192), '3h 12m');
    });

    test('Formats folder summary text', () {
      expect(YouTubeParser.formatFolderSummary(6, 192), '6 Items • 3h 12m total');
      expect(YouTubeParser.formatFolderSummary(1, 45), '1 Item • 45m total');
      expect(YouTubeParser.formatFolderSummary(0, 0), '0 Items');
    });

    test('LearningResource YouTube helper getters work accurately', () {
      final res = LearningResource(
        id: 'test_res',
        title: 'System Design',
        url: 'https://www.youtube.com/watch?v=m8Icp_Cid5o',
        resourceType: ResourceType.video,
        duration: '1h 15m',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(res.isYouTube, isTrue);
      expect(res.isPlaylist, isFalse);
      expect(res.youtubeVideoId, 'm8Icp_Cid5o');
      expect(res.effectiveThumbnailUrl, 'https://img.youtube.com/vi/m8Icp_Cid5o/maxresdefault.jpg');
      expect(res.durationMinutes, 75);
      expect(res.badgeTypeLabel, 'YouTube Video');
    });

    test('LearningCollection icon and summary text resolve correctly', () {
      final col = LearningCollection(
        id: 'test_col',
        title: 'Backend & Systems',
        icon: 'dns',
        totalResources: 4,
        totalDurationMinutes: 145,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(col.summaryText, '4 Items • 2h 25m total');
      expect(col.iconData, isNotNull);
    });
  });
}
