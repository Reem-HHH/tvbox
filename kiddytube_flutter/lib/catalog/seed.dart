import 'models.dart';

/// Phase-1 scaffold seed (verified starter IDs from native Kotlin catalog).
/// Full seed parity with Kotlin `DefaultChannels` SEED_VERSION 14 lands later.
class DefaultChannels {
  static const seedVersion = 1;

  static List<ContentChannel> seed() => [
        _channel(
          id: 'omar_hana',
          title: 'Omar & Hana',
          order: 0,
          color: 0xFF66BB6A,
          playlist: 'UU178EmfQAV3OT-UpuO6WUMg',
          videos: [
            _yt('T6ggVnk1JZg', 'Omar & Hana 15 Minutes Song'),
            _yt('iJtM9bzScJY', 'Omar & Hana — Dua & Salah (Acapella)'),
            _yt('HvzYeFB0lB4', 'Breakfasting — Omar & Hana'),
            _yt('AkSrzSwK2wE', 'Omar & Hana Arabic — Please Come Home Dad'),
          ],
        ),
        _channel(
          id: 'mini_muslim',
          title: 'Mini Muslim',
          order: 1,
          color: 0xFF26A69A,
          playlist: 'UUIDYe6rgdROl77DDevNIcPA',
          videos: [
            _yt('4VpiuY_C5Ok', 'Ramadan Around The World — MiniMuslims'),
            _yt('vB3ffnqdNVs', 'Islamic Songs for Kids (45 min) — MiniMuslims'),
            _yt('WyxekrpqcEQ', 'Islamic Songs for Kids (30 min) — MiniMuslims'),
          ],
        ),
        _channel(
          id: 'peppa',
          title: 'Peppa Pig',
          order: 2,
          color: 0xFFEF5350,
          playlist: 'UUAOtE1V7Ots4DjM8JLlrYgg',
          videos: [
            _yt("XAK5n8XUmfM", "What is Peppa's Favourite Sound? — Full Episodes"),
            _yt('t7dTdE8Aqtw', 'Jumping in Muddy Puddles — Peppa Pig My First Album'),
            _yt('P5vlEeqdJN8', 'Peppa and George Love Jumping in Muddy Puddles!'),
          ],
        ),
        _channel(
          id: 'pingu',
          title: 'Pingu',
          order: 3,
          color: 0xFF42A5F5,
          playlist: 'UUM88mtSE0zRTn5ae4EbYcuw',
          videos: [
            _yt('fWb-pNyPzdo', 'The Flying Pingu! — Official Channel'),
            _yt('e3egZ7tLXV4', 'A Helping Pingu! — Official Channel'),
            _yt('67zm4V1F0Z0', 'Painting Pingu! — Official Channel'),
          ],
        ),
        _channel(
          id: 'daniel_tiger',
          title: 'Daniel Tiger',
          order: 4,
          color: 0xFFFFA726,
          playlist: 'UUDqgSnRMGVx3dP4sn3ATZMA',
          videos: [
            _yt("OrNlkDVk_PA", "Daniel's Big Emotions — Daniel Tiger"),
            _yt('N4cTNBbDTdw', 'Daniel Learns Good Manners — Daniel Tiger'),
            _yt('R6nF76uDWDA', 'Daniel Eats Healthy — Daniel Tiger'),
          ],
        ),
        _channel(
          id: 'hey_duggee',
          title: 'Hey Duggee',
          order: 5,
          color: 0xFFFFCA28,
          playlist: 'UUj_mFUb-47d9QNiJ5556LjQ',
          videos: [
            _yt('W4oqUjPj-pI', 'The Drawing Badge — Hey Duggee'),
            _yt('_zJJVO4XXZs', 'The Colour Badge — Hey Duggee'),
            _yt('RhMecZiUEiY', 'The Decorating Badge — Hey Duggee'),
          ],
        ),
        _channel(
          id: 'numberblocks',
          title: 'Numberblocks',
          order: 6,
          color: 0xFFAB47BC,
          playlist: 'UUPlwvN0w4qFSP1FllALB92w',
          videos: [
            _yt('jVeYnCehEFE', 'One — Numberblocks S1 E1'),
            _yt('bz2oWyDjgbc', 'Another One — Numberblocks S1 E2'),
            _yt('aJzaNIpbUZo', 'Two — Numberblocks S1 E3'),
          ],
        ),
        _channel(
          id: 'pocoyo',
          title: 'Pocoyo',
          order: 7,
          color: 0xFF29B6F6,
          playlist: 'UUhT6ex4rsEDXjJKW7wJAb8w',
          videos: [
            _yt('CwL_mEsASGY', "Pato's Bedtime — Pocoyo"),
            _yt('_-UEJip10hE', "Elly's Market — Pocoyo"),
            _yt('_g_QHiaKuEs', 'Cooking with Elly — Pocoyo'),
          ],
        ),
      ];

  static ContentChannel _channel({
    required String id,
    required String title,
    required int order,
    required int color,
    String? playlist,
    List<VideoItem> videos = const [],
  }) {
    return ContentChannel(
      id: id,
      title: title,
      sourceType: playlist != null
          ? SourceType.youtubePlaylist
          : SourceType.youtubeVideoList,
      youtubePlaylistId: playlist,
      videos: videos,
      sortOrder: order,
      color: color,
      followUploads: false,
    );
  }

  static VideoItem _yt(String id, String title) => VideoItem(
        id: id,
        title: title,
        youtubeVideoId: id,
      );
}
