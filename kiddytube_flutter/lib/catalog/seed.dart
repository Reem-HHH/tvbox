import 'models.dart';

/// Catalog seed parity with Kotlin `DefaultChannels` SEED_VERSION 18.
class DefaultChannels {
  static const seedVersion = 18;

  static const _spacetoonUploadsPlaylist = 'UUuQKih3Ac3NABADQKQdeV6A';
  static const _dawoodHubPlaylist = 'PLKhm8Z5pXdOUWVTnTojfHw_Cr7Ac-HLyR';
  static const _numberblocksSeason1Playlist =
      'PL9swKX1PviEr9UfByZqJYiN8KX3AXqyXm';

  static const retiredChannelIds = {
    'arabic_cartoons',
    'learn_arabic',
    'islamic_kids',
    'playtime',
    'fulla',
    'dawood_juz_amma',
    'dawood_juz_amma_plain',
    'dawood_juz_amma_repeat',
    'dawood_juz_amma_selection',
    'dawood_juz_amma_memorize',
    'dawood_juz_amma_3d',
    'dawood_stories',
    'dawood_teaches_me',
    'dawood_and_me',
    'dawood_secrets_industry',
    'dawood_quranic_games',
    'dawood_quran_quiz',
    'dawood_tabarak',
    'dawood_tabarak_plain',
    'dawood_tabarak_memorize',
    'dawood_juz_28',
    'dawood_juz_27',
    'dawood_juz_26',
  };

  static List<ContentChannel> seed() => _withDailyFollow([
        _channel(
          id: 'omar_hana',
          title: 'Omar & Hana',
          order: 0,
          color: 0xFF66BB6A,
          playlist: _uploadsOf('UC178EmfQAV3OT-UpuO6WUMg'),
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
          playlist: _uploadsOf('UCIDYe6rgdROl77DDevNIcPA'),
          videos: [
            _yt('4VpiuY_C5Ok', 'Ramadan Around The World — MiniMuslims'),
            _yt('vB3ffnqdNVs', 'Islamic Songs for Kids (45 min) — MiniMuslims'),
            _yt('WyxekrpqcEQ', 'Islamic Songs for Kids (30 min) — MiniMuslims'),
          ],
        ),
        _channel(
          id: 'dawood',
          title: 'داوود',
          order: 2,
          color: 0xFF00897B,
          playlist: _dawoodHubPlaylist,
          videos: const [],
        ),
        _channel(
          id: 'kids_music',
          title: 'Kids Music',
          order: 3,
          color: 0xFFEC407A,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('wyOJfLSeZIE', 'بابا فين — Free Baby (Music Video)'),
            _yt('5wnNBQAkc-A', 'ماما جابت بيبي — جنى مقداد | طيور الجنة'),
            _yt('ISSlEZyIRFw', 'مابي أنام — حلا الترك'),
          ],
        ),
        _channel(
          id: 'spacetoon',
          title: 'Spacetoon أناشيد',
          order: 14,
          color: 0xFF5C6BC0,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('-_Kz-hseLkc', 'كتاب الله'),
            _yt('s7FQXvhwm40', 'كتابُ الله'),
            _yt('mJMigyCh-I8', 'أغنية الكتاب'),
            _yt('YoAU-tciuVs', 'يا طيبة — المدينة المنورة'),
            _yt('2h6Y8k8fNS4', 'هيا للمسجد لنصلي'),
            _yt('g7LjhyO7CEw', 'رمضان أقبل طيباً'),
            _yt('INZMVhnVlRM', 'أهلاً رمضان يا شهر الإحسان'),
            _yt('BojfVe5G6GM', 'هلال رمضان — يوسف إسلام'),
            _yt('Jh4gl0obMK0', 'رمضان 2020 — أطل الفجر بالبشر'),
            _yt('dB95J8Pa49c', 'أغنية بداية أنا وأختي'),
            _yt('o9xR7JcU2iw', 'فلفول — أغنية السلطة'),
            _yt('krYQGcQ3o0U', 'جميع أغاني الأشكال الهندسية'),
            _yt('fxZE5hOMyi4', 'أكثر من 30 دقيقة — أروع أغاني سبيستون'),
          ],
        ),
        _channel(
          id: 'moda_modi',
          title: 'مودا مودي',
          order: 15,
          color: 0xFF7E57C2,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('V2upg7iZvT0', 'مودا مودي — وأتى رمضان'),
            _yt('_SdwG5nE0Ik', 'مودا مودي — رمضان عاد'),
            _yt('7DUiKe_UneA', 'عائلة مودا مودي — رمضان تجلّى'),
            _yt('8cRwwgOzHF4', 'أغنية عيد الفطر من مودا مودي'),
          ],
        ),
        _channel(
          id: 'smarta',
          title: 'سمارتا وحقيبتها العجيبة',
          order: 16,
          color: 0xFF42A5F5,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('USLdtIWQrLU', 'سمارتا — الحلقة 1'),
            _yt('efHkhsi675M', 'سمارتا — الحلقة 2'),
            _yt('nP-F7A54oVc', 'سمارتا — الحلقة 3'),
            _yt('xIFNnxZD5IQ', 'ساعة من المغامرات — المجموعة الأولى'),
            _yt('Ui2P60B2WJE', 'مجموعة الحلقات الثالثة'),
            _yt('rf8FgLed_E8', 'مجموعة الحلقات الرابعة'),
            _yt('YgXdgZ2Wd0I', 'مجموعة الحلقات الخامسة'),
            _yt('5xftaiEK_7Y', 'مجموعة الحلقات السادسة'),
            _yt('nPBlRc5heBc', 'مجموعة الحلقات السابعة'),
            _yt('wcIW_tbTB3M', 'مجموعة الحلقات الثامنة'),
            _yt('kJULJaJjD4M', 'مجموعة الحلقات العاشرة'),
          ],
        ),
        _channel(
          id: 'toyor_jana',
          title: 'طيور الجنة',
          order: 17,
          color: 0xFF66BB6A,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('7GgZjoF0D2I', 'قلبي ينادي | طيور الجنة'),
            _yt('jlJaCmIOu8k', 'الصدقة — ديمة بشار | طيور الجنة'),
            _yt('So6XIOgO4TM', 'بيجاما — سند مقداد | طيور الجنة'),
            _yt('B5kD9sxd5Jg', 'شاكر والببغاء الشاطر — الخلفاء الراشدون'),
            _yt('1zt6iH8R2uA', 'شاكر والببغاء الشاطر — الفصول الأربعة'),
            _yt('02OKtnWyjNo', 'دادا حبة حبة (بدون إيقاع) — راية مقداد'),
          ],
        ),
        _channel(
          id: 'adam_mishmish',
          title: 'Adam & Mishmish',
          order: 18,
          color: 0xFFFFA726,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('FurzMF0L6QI', 'Animal Sounds Songs (68 min) — Adam & Mishmish'),
            _yt('docDippkI-Q', 'Farm Animal Songs — Adam & Mishmish'),
            _yt('etAPDF2i9s0', 'Arabic Letters with Animals — Adam & Mishmish'),
          ],
        ),
        _channel(
          id: 'zakaria',
          title: 'Zakaria',
          order: 19,
          color: 0xFF29B6F6,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('LocumA_zI0c', 'Learn Colors with Cars — Zakaria'),
            _yt('sGw7Fs7oRvw', 'Vehicle Names in Arabic — Zakaria'),
            _yt('XCp_1eTPnrM', 'Arabic Numbers 1–10 — Zakaria'),
            _yt('0MGqhiLQbxI', 'Write Arabic Alphabet أ–ص — Zakaria'),
            _yt('5v7A2AXzCY0', 'Write Arabic Alphabet ض–ي — Zakaria'),
          ],
        ),
        _channel(
          id: 'kiki_nadoush',
          title: 'Kiki wa Nadoush',
          order: 20,
          color: 0xFFEF5350,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('EI3yLs6A-Qk', 'Learn Arabic Colors — Kiki wa Nadoush'),
          ],
        ),
        _channel(
          id: 'rayan',
          title: 'Rayan',
          order: 21,
          color: 0xFFAB47BC,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('yPhFBBMWbPU', 'Shapes & Directions in Arabic — Rayan'),
          ],
        ),
        _channel(
          id: 'sweet_kalima',
          title: 'Sweet Kalima',
          order: 22,
          color: 0xFFFFCA28,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('En3OJwCqHx8', 'Shapes, Colors & Numbers — Sweet Kalima'),
          ],
        ),
        _channel(
          id: 'abata',
          title: 'Abata',
          order: 23,
          color: 0xFF8D6E63,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('sVtaIloYxvw', 'Arabic Alphabet with Chalk — Abata'),
          ],
        ),
        _channel(
          id: 'sara_duck',
          title: 'Sarah & Duck',
          order: 24,
          color: 0xFF26C6DA,
          playlist: _uploadsOf('UC3OUMU3s7Oy6Ta0wnpZFBWw'),
          videos: [
            _yt('EOj_7ZYmCOI', 'Cheer Up Donkey — Sarah & Duck'),
            _yt('e69BdjwjDxk', 'Bouncy Ball — Sarah & Duck'),
            _yt('zGn6PwRkD7c', 'Sarah, Duck and the Penguins'),
          ],
        ),
        _channel(
          id: 'twirlywoos',
          title: 'Twirlywoos',
          order: 25,
          color: 0xFFFF7043,
          playlist: _uploadsOf('UC6-m1hdh8xEu-XBJK3v1TPg'),
          videos: [
            _yt('yS4vFgys9-U', 'Soft — Twirlywoos'),
            _yt('lRVTYTWPUhU', 'This way, that way — Twirlywoos'),
            _yt('phqqLsmOxic', 'Joining Up! — Twirlywoos'),
            _yt('Ya45-PIVjhA', 'Sneaking in the Kitchen — Twirlywoos'),
            _yt('wAFiVXz1NNw', 'Full — Twirlywoos'),
            _yt('Wg0JkKmQY6A', 'Connecting — Twirlywoos'),
            _yt('8MUQW96Nsks', 'Turning — Twirlywoos'),
            _yt('iagHmqt-Hio', 'Going Over — Twirlywoos'),
            _yt('7JXSOIOebW4', 'Full (Kid Movies) — Twirlywoos'),
          ],
        ),
        _channel(
          id: 'barney',
          title: 'Barney & Friends',
          order: 26,
          color: 0xFF7CB342,
          playlist: _uploadsOf('UCelJG1JV-pKYGOG3AM17Wvg'),
          videos: [
            _yt('HoS5Dv4kAx8', 'I Love You — Barney Nursery Rhymes'),
            _yt('eb7yLV9moeU', 'Learning Colors with Barney!'),
            _yt('iuxvKiCkVUo', "Barney's Best Animal Songs!"),
            _yt('ecj5DwqT2xE', 'Having a Healthy Snack! — Barney'),
            _yt('Zi5CQbSajXE', 'Learning Something New with Barney!'),
            _yt('gzw6-AbAbK4', "Let's Play Together! — Barney"),
            _yt('dIQCqktBrXc', 'A Friend Like You! — Barney'),
          ],
        ),
        _channel(
          id: 'dora',
          title: 'Dora the Explorer',
          order: 27,
          color: 0xFFFF7043,
          playlist: _uploadsOf('UCkvPyGW-gsYucCK37UR0q2g'),
          videos: [
            _yt('7bqSFXuEUgo', 'NEW Dora Theme Song! — Dora & Friends'),
            _yt('gFTaVxUynsQ', 'You Can Do It! — Dora & Friends'),
            _yt('kKCLBnKT4dU', 'Best Friends Forever Day — Dora & Friends'),
            _yt('aIkGW0o5NeM', 'Dora Plays with Giant Kitty Cats!'),
            _yt('fAYtT9_iOfI', 'Sunny Flower Scenes with Boots — Dora & Friends'),
          ],
        ),
        _channel(
          id: 'peppa',
          title: 'Peppa Pig',
          order: 28,
          color: 0xFFEF5350,
          playlist: _uploadsOf('UCAOtE1V7Ots4DjM8JLlrYgg'),
          videos: [
            _yt("XAK5n8XUmfM", "What is Peppa's Favourite Sound? — Full Episodes"),
            _yt('t7dTdE8Aqtw', 'Jumping in Muddy Puddles — Peppa Pig My First Album'),
            _yt('P5vlEeqdJN8', 'Peppa and George Love Jumping in Muddy Puddles!'),
            _yt('jbdck_y74ls', 'Peppa Pig Rides the TRAIN! — LEGO DUPLO'),
          ],
        ),
        _channel(
          id: 'lego_duplo',
          title: 'LEGO DUPLO',
          order: 29,
          color: 0xFFFDD835,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('fwg0UIw0Efs', 'LEGO DUPLO Numbers & Colors in Arabic'),
            _yt('w7aZLVaLTlM', 'LEGO DUPLO Vehicles & Colors'),
            _yt('01JxHFDBdzE', 'LEGO DUPLO Creative Animals Unbox'),
            _yt('a0uPqr_iASU', 'LEGO DUPLO Animal Build'),
            _yt('jvCdmPsAn40', 'LEGO DUPLO Balancing Tree'),
            _yt('xvxQeQfdifk', 'LEGO DUPLO Marble Run'),
          ],
        ),
        _channel(
          id: 'play_doh',
          title: 'Play-Doh',
          order: 30,
          color: 0xFFFF8A65,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('2FyKZKNls4c', 'Play-Doh Cookie Man & Shapes'),
            _yt('8581xy-tGqw', 'Play-Doh Rainbow Ice Cream'),
            _yt('kS9fxiOdiGs', 'Marble Run Plasticine Race'),
            _yt('F4ICHmkVGtQ', 'Magic Marble Run Compilation'),
          ],
        ),
        _channel(
          id: 'toy_kitchen',
          title: 'Toy Kitchen',
          order: 31,
          color: 0xFF90A4AE,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('mSUJM2naI7I', 'Travel Kitchen Playset Unboxing'),
            _yt('TL3e2UZQxPE', 'Kitchen Set & Toy Fruits'),
          ],
        ),
        _channel(
          id: 'dancing_fruit',
          title: 'Dancing Fruit',
          order: 32,
          color: 0xFFEC407A,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('7mR81x2Fk7g', 'Dancing Fruit! — 1 Hour Mix — Hey Bear Sensory'),
            _yt('ALaQvK7KZOY', 'Dance, Colors and Counting — Dancing Fruit & Funky Veggies'),
            _yt('kAxdvigZtw8', 'Best of Dancing Fruit and Funky Veggies — Dance Party'),
            _yt('b65MoVwANq4', 'Disco Fruit Party — Dancing Fruit with Cumbia'),
            _yt('KPP4Cfupzhs', 'Smoothie Mix — Fun Dance Video'),
            _yt('xOUdk2LdXrs', "Let's Dance! — Avocadosaurus and Party Strawberries"),
          ],
        ),
        _channel(
          id: 'toyor_baby',
          title: 'طيور بيبي',
          order: 33,
          color: 0xFF81C784,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('_tN--Xk4kaE', 'دعاء النوم — سند مقداد | طيور بيبي'),
            _yt('9hmZtWndznM', 'دعاء قبل الطعام وبعده — سند مقداد | طيور بيبي'),
            _yt('UA6sLNgWRtI', 'شمّام (بدون ايقاع) — طيور بيبي'),
            _yt('42oNUPf_SsM', 'دعسوقة (بدون إيقاع) — طيور بيبي'),
            _yt('OHM8yH2QRC8', 'شاكر والببغاء الشاطر — العشرة المبشرون بالجنة'),
            _yt('-l5_ao_oxmg', 'شاكر والببغاء الشاطر — الصلوات'),
            _yt('iSuhEcI1HOQ', 'شاكر والببغاء الشاطر — المدينة المنورة'),
            _yt('QhAc8NS8J_M', 'شمّام — طيور بيبي'),
          ],
        ),
        _channel(
          id: 'pingu',
          title: 'Pingu',
          order: 34,
          color: 0xFF42A5F5,
          playlist: _uploadsOf('UCM88mtSE0zRTn5ae4EbYcuw'),
          videos: [
            _yt('fWb-pNyPzdo', 'The Flying Pingu! — Official Channel'),
            _yt('e3egZ7tLXV4', 'A Helping Pingu! — Official Channel'),
            _yt('67zm4V1F0Z0', 'Painting Pingu! — Official Channel'),
            _yt('cXmY4mlM6OI', 'Like Father Like Pingu! — Official Channel'),
            _yt('PpwYRAWTD8c', 'Pingu the Doctor — Official Channel'),
            _yt('m3KuDiBEtgU', 'Pingu and the Broken Vase — Official Channel'),
          ],
        ),
        _channel(
          id: 'daniel_tiger',
          title: 'Daniel Tiger',
          order: 35,
          color: 0xFFFFA726,
          playlist: _uploadsOf('UCDqgSnRMGVx3dP4sn3ATZMA'),
          videos: [
            _yt("OrNlkDVk_PA", "Daniel's Big Emotions — Daniel Tiger"),
            _yt('N4cTNBbDTdw', 'Daniel Learns Good Manners — Daniel Tiger'),
            _yt('R6nF76uDWDA', 'Daniel Eats Healthy — Daniel Tiger'),
            _yt('9AfD-N9HK8s', 'Bath Time with Daniel Tiger — Full Episodes'),
            _yt('oloZANav_g8', 'Potty Training! — Daniel Tiger'),
            _yt('IGM-r8baTN4', 'Daniel Learns to Swing — Daniel Tiger'),
          ],
        ),
        _channel(
          id: 'hey_duggee',
          title: 'Hey Duggee',
          order: 36,
          color: 0xFFFFCA28,
          playlist: _uploadsOf('UCj_mFUb-47d9QNiJ5556LjQ'),
          videos: [
            _yt('W4oqUjPj-pI', 'The Drawing Badge — Hey Duggee'),
            _yt('_zJJVO4XXZs', 'The Colour Badge — Hey Duggee'),
            _yt('RhMecZiUEiY', 'The Decorating Badge — Hey Duggee'),
            _yt('VVMjTvc8qbQ', 'The Key Badge — Hey Duggee'),
            _yt('6bxOoxBheb0', 'Feel-Good Happy Days With Duggee'),
          ],
        ),
        _channel(
          id: 'numberblocks',
          title: 'Numberblocks',
          order: 37,
          color: 0xFFAB47BC,
          playlist: _numberblocksSeason1Playlist,
          videos: [
            _yt('jVeYnCehEFE', 'One — Numberblocks S1 E1'),
            _yt('bz2oWyDjgbc', 'Another One — Numberblocks S1 E2'),
            _yt('aJzaNIpbUZo', 'Two — Numberblocks S1 E3'),
            _yt('6-duQqX5ECs', 'Three — Numberblocks S1 E4'),
            _yt('IqkSbJqplpg', 'One, Two, Three — Numberblocks S1 E5'),
            _yt('yKAttOvgWJc', 'Three Little Pigs — Numberblocks S1 E8'),
            _yt('Ap5kgJ-bpEQ', 'How to Count — Numberblocks S1 E10'),
          ],
        ),
        _channel(
          id: 'pocoyo',
          title: 'Pocoyo',
          order: 38,
          color: 0xFF29B6F6,
          playlist: _uploadsOf('UChT6ex4rsEDXjJKW7wJAb8w'),
          videos: [
            _yt('CwL_mEsASGY', "Pato's Bedtime — Pocoyo"),
            _yt('_-UEJip10hE', "Elly's Market — Pocoyo"),
            _yt('_g_QHiaKuEs', 'Cooking with Elly — Pocoyo'),
            _yt('eDu9RdFhcg4', 'Magician Pocoyo — Pocoyo'),
            _yt('_b2U6PLIc_E', "Giving Loula a Bath — Pocoyo"),
            _yt('jO-AiyofVEI', "Pocoyo's New Toys — Pocoyo"),
          ],
        ),
        _channel(
          id: 'cocomelon',
          title: 'CoComelon',
          order: 39,
          color: 0xFFFFEE58,
          playlist: _uploadsOf('UCbCmjCuTUZos6Inko4u57UQ'),
          videos: [
            _yt('e_04ZrNroTo', 'Wheels on the Bus — CoComelon'),
            _yt('WRVsOCh907o', 'Bath Song — CoComelon'),
            _yt('ZzAm13KsBCc', 'Bath Song + More — CoComelon'),
            _yt('tgFynI0l06U', 'Old MacDonald Had A Farm + More — CoComelon'),
            _yt('hqehvbhky5k', 'On My Way To School — CoComelon'),
            _yt('wfwvrawZDs8', 'Happy Birthday Song — CoComelon'),
          ],
        ),
        _channel(
          id: 'masha',
          title: 'Masha and the Bear',
          order: 40,
          color: 0xFFEF5350,
          playlist: _uploadsOf('UCu59yAFE8fM0sVNTipR4edw'),
          videos: [
            _yt('qBp1rCz_yQU', 'Recipe For Disaster — Masha and the Bear'),
            _yt('1Kt9RhxJdzk', 'Recipe For Disaster (4K) — Masha and the Bear'),
            _yt('g9CMF85dAt4', 'Laundry Day — Best Episodes Collection'),
            _yt('AV-UBYOGB_o', 'Why Should We Play Games? — Best Episodes'),
            _yt('R6Oh1xUmB3E', 'Honey Day — Cartoon Collection'),
          ],
        ),
        _channel(
          id: 'mansour',
          title: 'منصور',
          order: 41,
          color: 0xFF5C6BC0,
          playlist: _uploadsOf('UCqiIbqnJB0AVTg6Z6QnZNdw'),
          videos: [
            _yt('TohnJvGq-cU', 'مغامرات منصور — مغامرات مشوقة الجزء 7'),
            _yt('A1edNxaVICE', 'مغامرات منصور — مغامرات مشوقة الجزء 6'),
            _yt('T1AlwoEdxGo', 'مغامرات منصور — مغامرات مشوقة الجزء 5'),
            _yt('l5LwMtanIg8', 'مغامرات منصور — مغامرات مشوقة الجزء 4'),
            _yt('qbrHu-vkXiI', 'مغامرات منصور — الحلقات المميزة ج7'),
          ],
        ),
      ]);

  /// Playlist-backed channels follow uploads daily by default.
  static List<ContentChannel> _withDailyFollow(List<ContentChannel> channels) {
    return [
      for (final ch in channels)
        if (ch.youtubePlaylistId == null || ch.youtubePlaylistId!.isEmpty)
          ch
        else
          ch.copyWith(followUploads: true),
    ];
  }

  /// Merge newer seed defaults onto an existing catalog without wiping parent toggles.
  static List<ContentChannel> mergeSeedUpdates(List<ContentChannel> existing) {
    final byId = {
      for (final ch in existing.where((c) => !retiredChannelIds.contains(c.id)))
        ch.id: ch,
    };

    for (final seedCh in seed()) {
      final current = byId[seedCh.id];
      if (current == null) {
        byId[seedCh.id] = seedCh;
        continue;
      }

      final clearSpacetoonUploads = seedCh.id == 'spacetoon' &&
          (seedCh.youtubePlaylistId == null ||
              seedCh.youtubePlaylistId!.isEmpty) &&
          current.youtubePlaylistId == _spacetoonUploadsPlaylist;

      final needsPlaylist = !current.playlistManagedByParent &&
          (current.youtubePlaylistId == null ||
              current.youtubePlaylistId!.isEmpty) &&
          seedCh.youtubePlaylistId != null &&
          seedCh.youtubePlaylistId!.isNotEmpty &&
          current.videos.isEmpty;
      final replaceNumberblocksPlaylist = seedCh.id == 'numberblocks' &&
          !current.playlistManagedByParent &&
          seedCh.youtubePlaylistId != null &&
          seedCh.youtubePlaylistId!.isNotEmpty &&
          current.youtubePlaylistId != seedCh.youtubePlaylistId;
      final enableFollowFromSeed = seedCh.followUploads &&
          !current.followUploads &&
          !current.playlistManagedByParent;

      final existingIds = current.videos.map((v) => v.id).toSet();
      final missingVideos =
          seedCh.videos.where((v) => !existingIds.contains(v.id)).toList();
      final titleStale = current.title != seedCh.title &&
          (seedCh.id == 'spacetoon' || clearSpacetoonUploads);
      final disableFromSeed = !seedCh.enabled && current.enabled;

      if (clearSpacetoonUploads ||
          needsPlaylist ||
          replaceNumberblocksPlaylist ||
          enableFollowFromSeed ||
          missingVideos.isNotEmpty ||
          titleStale ||
          disableFromSeed) {
        final List<VideoItem> videos;
        if (clearSpacetoonUploads) {
          videos = seedCh.videos;
        } else if (current.videos.isEmpty && seedCh.videos.isNotEmpty) {
          videos = seedCh.videos;
        } else if (missingVideos.isNotEmpty) {
          videos = [...current.videos, ...missingVideos];
        } else {
          videos = current.videos;
        }

        byId[seedCh.id] = current.copyWith(
          title: (titleStale || clearSpacetoonUploads)
              ? seedCh.title
              : current.title,
          youtubePlaylistId: clearSpacetoonUploads
              ? null
              : (needsPlaylist || replaceNumberblocksPlaylist
                  ? seedCh.youtubePlaylistId
                  : current.youtubePlaylistId),
          clearPlaylist: clearSpacetoonUploads,
          videos: videos,
          sourceType: clearSpacetoonUploads ||
                  needsPlaylist ||
                  replaceNumberblocksPlaylist
              ? seedCh.sourceType
              : current.sourceType,
          sortOrder: seedCh.sortOrder,
          color: seedCh.color,
          enabled: !seedCh.enabled ? false : current.enabled,
          followUploads: !current.playlistManagedByParent && seedCh.followUploads
              ? true
              : current.followUploads,
        );
      } else if (current.sortOrder != seedCh.sortOrder ||
          current.color != seedCh.color) {
        byId[seedCh.id] = current.copyWith(
          sortOrder: seedCh.sortOrder,
          color: seedCh.color,
        );
      }
    }

    final merged = byId.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return merged;
  }

  static ContentChannel _channel({
    required String id,
    required String title,
    required int order,
    required int color,
    String? playlist,
    SourceType? sourceType,
    List<VideoItem> videos = const [],
    bool enabled = true,
  }) {
    return ContentChannel(
      id: id,
      title: title,
      sourceType: sourceType ??
          (playlist != null
              ? SourceType.youtubePlaylist
              : SourceType.youtubeVideoList),
      enabled: enabled,
      youtubePlaylistId: playlist,
      videos: videos,
      sortOrder: order,
      color: color,
      followUploads: playlist != null && playlist.isNotEmpty,
    );
  }

  static String _uploadsOf(String channelId) =>
      channelId.startsWith('UC') ? 'UU${channelId.substring(2)}' : channelId;

  static VideoItem _yt(String id, String title) => VideoItem(
        id: id,
        title: title,
        youtubeVideoId: id,
        thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      );
}
