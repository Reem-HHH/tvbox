import 'catalog_sanitize.dart';
import 'models.dart';

/// Catalog seed parity with Kotlin `DefaultChannels` SEED_VERSION 26.
class DefaultChannels {
  static const seedVersion = 29;

  /// Wrong upload formerly labeled مابي أنام; replaced by بنيتي الحبوبة.
  static const _retiredKidsMusicVideoId = 'ISSlEZyIRFw';

  /// Rotating YouTube live IDs that crash in the kid player when the stream ends.
  static const retiredLiveVideoIds = {
    'wawzF8i5yAo',
    '3eAQvIImyTM',
    'tuOo0oPuc2Y',
    'Rs7St51oDDc',
  };

  static const _spacetoonUploadsPlaylist = 'UUuQKih3Ac3NABADQKQdeV6A';
  static const _dawoodHubPlaylist = 'PLKhm8Z5pXdOUWVTnTojfHw_Cr7Ac-HLyR';
  static const _numberblocksSeason1Playlist =
      'PL9swKX1PviEr9UfByZqJYiN8KX3AXqyXm';
  /// Games For Kids Hub — Dad & Olivia Play (calm Minecraft builds only).
  static const _dadOliviaMinecraftPlaylist =
      'PLCGF5P4ZzZ6d2S5-RVKKkFp-wLZk-uKP9';

  static const retiredChannelIds = {
    'arabic_cartoons',
    'learn_arabic',
    'islamic_kids',
    'playtime',
    'fulla',
    'toyor_jana',
    'disney_songs_ar',
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

  static List<ContentChannel> seed() {
    final channels = [
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
            _yt('T5b1d3xvh3c', 'Omar & Hana Arabic — مجموعة رسوم دينية'),
            _yt('V9bIdfyiQYQ', 'Omar & Hana Arabic — مجموعة حلقات'),
            _yt('_YMsrKhUnPs', 'Salam Scientist — Omar & Hana'),
            _yt('icd_EkXP1Eo', "Dad's Magical Dish — Omar & Hana"),
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
            _yt('8aABPaYMpUs', "Let's Count To 10 — MiniMuslims"),
            _yt('sWk1Xyqv19Y', 'Mawlid Song — Salawatun Tayyibatun'),
            _yt('HgREL4X7eUg', 'The Ants Go Marching — MiniMuslims'),
            _yt('mVGnpSthYZQ', 'Mawlaya Burdah — MiniMuslims'),
          ],
        ),
        _channel(
          id: 'dawood',
          title: 'داوود',
          order: 2,
          color: 0xFF00897B,
          playlist: _dawoodHubPlaylist,
          followUploads: true,
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
            _yt(
              'qn3ITODjLiw',
              'بنيتي الحبوبة — حلا الترك و مشاعل',
            ),
            _yt(
              '03X3iys-Rcs',
              'أغنية آيس كريم — ثعلوب والفواكه | أسرتنا',
            ),
            _yt(
              'Gmhk7mWG050',
              'في منزل أنثى السنجاب — أسرتنا',
            ),
            _yt(
              'Pf1Y0JtfMPU',
              'أنشودة الخضروات — أسرتنا',
            ),
            _yt(
              'WqzwrbzSqyY',
              'أغنية الكواكب — أسرتنا',
            ),
            _yt(
              'wK-YBukZUuU',
              'كوكسينو والعنكبوت — أسرتنا',
            ),
            _yt(
              'NWcs3bZ0fSM',
              'رمضان جانا — أسرتنا',
            ),
            _yt(
              'XE4qklLOokQ',
              'أنا البندورة الحمراء — طيور الجنة',
            ),
            _yt(
              'ZUCS_cR9cY8',
              'ساعة من أغاني أسرتنا — بدون إيقاع',
            ),
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
            _yt('iIg9QBsd-Rw', 'أنا مودو — مودا مودي | سبيستون'),
            _yt('AWHJRkWISgs', 'هل تعلمين ماذا فعلت اليوم — مودا مودي'),
            _yt('zYhbSoxUOIY', 'دعونا نبني — مودا مودي | سبيستون'),
            _yt('hCFI7oi6XRc', 'دمتي أمي دمت يا أبي — مودا مودي'),
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
          id: 'adam_mishmish',
          title: 'Adam & Mishmish',
          order: 18,
          color: 0xFFFFA726,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('FurzMF0L6QI', 'Animal Sounds Songs (68 min) — Adam & Mishmish'),
            _yt('docDippkI-Q', 'Farm Animal Songs — Adam & Mishmish'),
            _yt('etAPDF2i9s0', 'Arabic Letters with Animals — Adam & Mishmish'),
            _yt('Sp85Q-qiqQw', 'أغاني عربية للأطفال 60 دقيقة — آدم ومشمش'),
            _yt('w67-oHQNBVA', 'الأغاني المفضلة 60 دقيقة — آدم ومشمش'),
            _yt('auSSr85LDbE', 'أغاني جديدة ممتعة — آدم ومشمش'),
            _yt('IDP3sV9ZMEc', 'أغنية الرياضة والحركة — آدم ومشمش'),
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
            _yt('USW8_gV_Hnw', 'Colors with Street Vehicles — Zakaria'),
            _yt('So5y8Sy8R6Y', 'Street Vehicles in Arabic — Zakaria'),
            _yt('_pUf4xdBqxA', 'Counting with Cars 1–10 — Zakaria'),
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
            _yt('2j8ScIsrYxg', 'Basic Phrases & Counting — Kiki wa Nadoush'),
            _yt('e80_mbmSbC0', 'Colors Short Story — Kiki wa Nadoush'),
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
            _yt('hMXsohVaPGQ', 'خضار وفواكه وألوان وأرقام — ريان'),
            _yt('csUnMp9Gdjo', 'الأرقام بالعربية — ريان'),
            _yt('pfzBh3okwe0', 'أشكال وألوان وأحجام — ريان'),
            _yt('ojfQ6yB_Liw', 'كلمات وألوان وفواكه — ريان'),
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
            _yt('L3MaRZCKq20', 'أغاني تعليمية — الجزء 2 | Sweet Kalima'),
            _yt('U2mZgNj-Ya0', 'أغاني تعليمية للأطفال | Sweet Kalima'),
            _yt('sSAby5cLSbo', 'الروتين الصباحي — Sweet Kalima'),
            _yt('R0asqLFXxzo', 'الفصول الأربعة — Sweet Kalima'),
            _yt('8rbhv2iEohM', 'أغاني الفواكه — Sweet Kalima'),
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
            _yt('AekHJ4m4dks', 'Sea Arabic Alphabet Song — Abata'),
            _yt('xkvkf4LhQKU', 'Dancing Arabic Alphabet Song — Abata'),
            _yt('cSQQ2JATO5I', 'Hijaiyah Puzzle — Abata'),
            _yt('6JnixgqoLbQ', 'Learn ALIF Letters — Abata'),
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
            _yt('tavYEmefXgI', '1 Hour Marathon — Sarah & Duck'),
            _yt('F87fpmUgPUA', '30 mins Full Episodes — Sarah & Duck'),
            _yt('wWxzi_obAUw', 'Strawberry Souffle — Sarah & Duck'),
            _yt('_zHfVdvx6OA', 'Pipe Conductor — Sarah & Duck'),
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
            _yt('OUsNcAxAq8M', 'Full Episodes — Love — Barney'),
            _yt('PDlcqXoOIFI', 'Good Manners & Best Behavior — Barney'),
            _yt('-NpnkSB90-E', 'Up, Down, and Around! — Barney'),
            _yt('4FwrbFxYOOQ', 'My Family and Me — Barney'),
            _yt('pf93hIE1xBU', 'Splish! Splash! — Barney'),
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
            _yt('RafDio654Ws', "Peppa Pig's New Tree House"),
            _yt('blQxZ73C_Vg', 'Tea Party in Her Tree House — Peppa Pig'),
            _yt('e1WO60yYBtg', "Peppa's Magical Treehouse Adventure"),
            _yt('xu1mfnnle0Q', "Peppa Pig's New Tree House (Official)"),
          ],
        ),
        _channel(
          id: 'ben_and_holly',
          title: "Ben & Holly",
          order: 29,
          color: 0xFF66BB6A,
          playlist: _uploadsOf('UC2UhuvjTIrR0Ck2KrkvRcuA'),
          videos: [
            _yt('mLHPMMKTNRI', 'The Royal Fairy Picnic — Ben & Holly'),
            _yt('edAhVTPprT0', 'The Toy Robot — Ben & Holly'),
            _yt('37Cz9nqz5fg', "King Thistle's Busiest Day — Ben & Holly"),
            _yt('gHga2hc_NsE', 'The Elf Farm — Ben & Holly'),
            _yt('dR0UCe5DXjk', 'Gaston Moves Into the Castle — Ben & Holly'),
            _yt('3w1Z_YhB008', 'Holly Goes to Elf School — Ben & Holly'),
            _yt('3QCsaMMt3I4', 'Gaston Goes To School — Ben & Holly'),
            _yt('it_Z9yZ77fM', 'Ben Turned Into a Frog — Ben & Holly'),
            _yt('AWD6XYd8iOA', "Holly Forgets Ben's Birthday — Ben & Holly"),
            _yt('AWWywfv69ww', 'The Elf Band Saves the Day — Ben & Holly'),
            _yt('rZ5kKVQkqM4', 'Ben Learns to Tell Time — Ben & Holly'),
            _yt('WOddu_AdGPU', 'What are Ben and Holly Cooking? — Ben & Holly'),
            _yt('hCblA3qIFGs', 'Learn to Share — Ben & Holly'),
            _yt('t5x7QurObts', 'Holly Needs Help — Ben & Holly'),
            _yt('GvGFWEJq2oE', 'King Thistle Has a Cold — Ben & Holly'),
            _yt('g-bNPrZWmXg', "King Thistle's Clothes Shrink — Ben & Holly"),
            _yt('iMDZv-7pRrM', 'The Mystery of the Lost Egg — Ben & Holly'),
            _yt('4Jr6Nfngto0', "Nanny Plum's Windmill — Ben & Holly"),
            _yt('GzxW_whnX3I', "Betty's Butterfly Surprise — Ben & Holly"),
            _yt('ghv0qtbeyeY', "Holly's Sandcastle Surprise — Ben & Holly"),
          ],
        ),
        _channel(
          id: 'lego_duplo',
          title: 'LEGO DUPLO',
          order: 30,
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
          order: 31,
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
          order: 32,
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
          order: 33,
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
          order: 34,
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
            _yt('x6s8KLzbq28', 'الديك بيصحى (بدون إيقاع) — طيور بيبي'),
            _yt('3pI5IhE1sSE', 'حمار جحا (بدون إيقاع) — طيور بيبي'),
            _yt('ZgUCuW8aRCY', 'الليمونة والبرتقالة (بدون إيقاع) — طيور بيبي'),
            _yt('j4ViMQxKY4A', 'الأرنب والثعلب (بدون إيقاع) — طيور بيبي'),
          ],
        ),
        _channel(
          id: 'pingu',
          title: 'Pingu',
          order: 35,
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
          order: 36,
          color: 0xFFFFA726,
          playlist: _uploadsOf('UCDqgSnRMGVx3dP4sn3ATZMA'),
          videos: [
            _yt("OrNlkDVk_PA", "Daniel's Big Emotions — Daniel Tiger"),
            _yt('N4cTNBbDTdw', 'Daniel Learns Good Manners — Daniel Tiger'),
            _yt('R6nF76uDWDA', 'Daniel Eats Healthy — Daniel Tiger'),
            _yt('9AfD-N9HK8s', 'Bath Time with Daniel Tiger — Full Episodes'),
            _yt('oloZANav_g8', 'Potty Training! — Daniel Tiger'),
            _yt('IGM-r8baTN4', 'Daniel Learns to Swing — Daniel Tiger'),
            _yt('zvJAcFoFXxE', 'Learning Patience — Daniel Tiger'),
            _yt('mnc6a3aA_yA', "Won't You Be My Neighbour? — Daniel Tiger"),
            _yt('8p8ADCLz3Hk', 'Baby Margaret is My Best Friend — Daniel Tiger'),
            _yt('5tb0ukBVbA0', 'Neighbourhood Jobs — Daniel Tiger'),
          ],
        ),
        _channel(
          id: 'hey_duggee',
          title: 'Hey Duggee',
          order: 37,
          color: 0xFFFFCA28,
          playlist: _uploadsOf('UCj_mFUb-47d9QNiJ5556LjQ'),
          videos: [
            _yt('W4oqUjPj-pI', 'The Drawing Badge — Hey Duggee'),
            _yt('_zJJVO4XXZs', 'The Colour Badge — Hey Duggee'),
            _yt('RhMecZiUEiY', 'The Decorating Badge — Hey Duggee'),
            _yt('VVMjTvc8qbQ', 'The Key Badge — Hey Duggee'),
            _yt('6bxOoxBheb0', 'Feel-Good Happy Days With Duggee'),
            _yt('BBleojshabk', 'The Recipe Badge — Hey Duggee'),
            _yt('J0Jc0MSQglg', 'The Delivery Badge — Hey Duggee'),
            _yt('dIoRncsoFm8', 'The Shopping Badge — Hey Duggee'),
            _yt('l0L9WACaMCc', "Roly's First Day — Hey Duggee"),
          ],
        ),
        _channel(
          id: 'numberblocks',
          title: 'Numberblocks',
          order: 38,
          color: 0xFFAB47BC,
          playlist: _numberblocksSeason1Playlist,
          followUploads: true,
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
          order: 39,
          color: 0xFF29B6F6,
          playlist: _uploadsOf('UChT6ex4rsEDXjJKW7wJAb8w'),
          videos: [
            _yt('CwL_mEsASGY', "Pato's Bedtime — Pocoyo"),
            _yt('_-UEJip10hE', "Elly's Market — Pocoyo"),
            _yt('_g_QHiaKuEs', 'Cooking with Elly — Pocoyo'),
            _yt('eDu9RdFhcg4', 'Magician Pocoyo — Pocoyo'),
            _yt('_b2U6PLIc_E', "Giving Loula a Bath — Pocoyo"),
            _yt('jO-AiyofVEI', "Pocoyo's New Toys — Pocoyo"),
            _yt('swVI1aYW8E0', "It's Shopping Day — Pocoyo (89 min)"),
            _yt('tqAf9tFW00Y', 'Super Babies — Pocoyo (94 min)'),
            _yt('WDQl4w-n9IE', 'Playground Time — Pocoyo (99 min)'),
            _yt('YFCWXJdo4N0', 'Learn The Alphabet — Pocoyo'),
          ],
        ),
        _channel(
          id: 'cocomelon',
          title: 'CoComelon',
          order: 40,
          color: 0xFFFFEE58,
          playlist: _uploadsOf('UCbCmjCuTUZos6Inko4u57UQ'),
          videos: [
            _yt('e_04ZrNroTo', 'Wheels on the Bus — CoComelon'),
            _yt('WRVsOCh907o', 'Bath Song — CoComelon'),
            _yt('ZzAm13KsBCc', 'Bath Song + More — CoComelon'),
            _yt('tgFynI0l06U', 'Old MacDonald Had A Farm + More — CoComelon'),
            _yt('hqehvbhky5k', 'On My Way To School — CoComelon'),
            _yt('wfwvrawZDs8', 'Happy Birthday Song — CoComelon'),
            _yt('qXcMNBQnQMM', 'Songs For Kids Compilation — CoComelon'),
            _yt('fdPu-wvl3KE', 'Peek A Boo — CoComelon'),
          ],
        ),
        _channel(
          id: 'masha',
          title: 'Masha and the Bear',
          order: 41,
          color: 0xFFEF5350,
          playlist: _uploadsOf('UCu59yAFE8fM0sVNTipR4edw'),
          videos: [
            _yt('qBp1rCz_yQU', 'Recipe For Disaster — Masha and the Bear'),
            _yt('1Kt9RhxJdzk', 'Recipe For Disaster (4K) — Masha and the Bear'),
            _yt('g9CMF85dAt4', 'Laundry Day — Best Episodes Collection'),
            _yt('AV-UBYOGB_o', 'Why Should We Play Games? — Best Episodes'),
            _yt('R6Oh1xUmB3E', 'Honey Day — Cartoon Collection'),
            _yt('erwBhzx3eok', 'أفضل طريقة لقضاء اليوم — ماشا والدب'),
            _yt('EsGkXt6nneE', 'أميرة الأسنان الحلوة — ماشا والدب'),
            _yt('INyR_Dl7rVk', 'طيف ظريف — ماشا والدب'),
          ],
        ),
        _channel(
          id: 'mansour',
          title: 'منصور',
          order: 42,
          color: 0xFF5C6BC0,
          playlist: _uploadsOf('UCqiIbqnJB0AVTg6Z6QnZNdw'),
          videos: [
            _yt('TohnJvGq-cU', 'مغامرات منصور — مغامرات مشوقة الجزء 7'),
            _yt('A1edNxaVICE', 'مغامرات منصور — مغامرات مشوقة الجزء 6'),
            _yt('T1AlwoEdxGo', 'مغامرات منصور — مغامرات مشوقة الجزء 5'),
            _yt('l5LwMtanIg8', 'مغامرات منصور — مغامرات مشوقة الجزء 4'),
            _yt('qbrHu-vkXiI', 'مغامرات منصور — الحلقات المميزة ج7'),
            _yt('FdUVdcfsHzY', 'مغامرات منصور — حلقات الاختراعات'),
            _yt('dXeBoTInNcA', 'مغامرات منصور — العطلة مع منصور ج17'),
            _yt('bJpAuVrcQgc', 'مغامرات منصور — جمعتنا مع منصور ج4'),
            _yt('fpfSHyyhD2Q', 'مغامرات منصور — جمعتنا مع منصور ج12'),
          ],
        ),
        _channel(
          id: 'maruko',
          title: 'ماروكو الصغيرة',
          order: 43,
          color: 0xFFEC407A,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('7Xf9nKYyAM4', 'شارة العمل — ماروكو الصغيرة | سبيستون'),
            _yt('OMbPlfL2VMY', 'الحلقات الثلاث الأولى — ماروكو الصغيرة | سبيستون'),
            _yt('vnwWjLlbYUQ', 'المقدمة الرسمية — ماروكو الصغيرة'),
            _yt('_WgvHPmMYXo', 'مشاجرة الأختين — ماروكو الصغيرة'),
            _yt('zZAQztwJGxg', 'بيع الساعة — ماروكو الصغيرة'),
            _yt('3iKlvWdgQ2M', 'ماروكو الصغيرة تستغل الفرصة'),
            _yt('KQidxkPZrOI', 'عالية مكانتي — ماروكو الصغيرة'),
            _yt('OBPi512Q-0c', 'ماروكو الصغيرة واكتشافها'),
            _yt('efoYDgyUdbU', 'ماروكو الصغيرة والتنظيف'),
            _yt('daBmNllqeto', 'ماروكو الصغيرة والمكالمة الهاتفية'),
            _yt('zT0VZaaXVgg', 'ماروكو الصغيرة وصراحتها الزائدة'),
            _yt('EM4vPYt7t-A', 'ماروكو والهدوء الذي لا ينتهي | سبيستون غو'),
            _yt('BCYkBHqnN0I', 'مغامرات ماروكو مع العائلة | سبيستون غو'),
            _yt('STo24SNg2Ws', 'ماروكو واختبار الرياضيات | سبيستون غو'),
            _yt('0gAG-rxdX2I', 'حرب البلابل — ماروكو الصغيرة | سبيستون غو'),
            _yt('zZcU-kPRorc', 'ماروكو في نظر الجد | سبيستون غو'),
          ],
        ),
        _channel(
          id: 'live_makkah',
          title: 'قرآن للنوم',
          order: 44,
          color: 0xFF2E7D32,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('UMT2RvaOKrg', 'قرآن للنوم — جزء عم | شاشة سوداء'),
            _yt('vfdU0VNJvJ0', 'جزء عم — ماهر المعيقلي | شاشة سوداء'),
            _yt('WX2K1q0G9I4', 'سورة الملك للنوم — عمر هشام | شاشة سوداء'),
            _yt('cEDlcpgBCMM', 'سورة الملك — ماهر المعيقلي | شاشة سوداء'),
            _yt('SyYV7OVStLA', 'سورة الملك — مشاري العفاسي | شاشة سوداء'),
            _yt('Nne9H-3Z-bM', 'سورة البقرة — ماهر المعيقلي | شاشة سوداء'),
            _yt('HMAJn52hQqw', 'سورة البقرة كاملة — ماهر المعيقلي | شاشة سوداء'),
            _yt('WFnpX2yMRK8', 'رقية المنزل — تحصين البيت والأولاد'),
            _yt('Jkgu5vGjJz8', 'رقية البيت — البقرة وماهر المعيقلي'),
            _yt('BhtzXGiPB5Y', 'رقية للبيت — سور مباركة'),
            _yt('i4tggpG4rFI', 'الرقية الشرعية — ماهر المعيقلي'),
            _yt('XmJu7Efsj0Y', 'الرقية الشرعية الشاملة — صوت هادئ'),
            _yt('6hDV4sQiQNc', 'رقية شرعية للنوم — ماهر المعيقلي | شاشة سوداء'),
            _yt('5v-P7gbDK9s', 'رقية شرعية شاشة سوداء — ماهر المعيقلي'),
          ],
        ),
        _channel(
          id: 'live_quran',
          title: 'رقية وقرآن',
          order: 45,
          color: 0xFF00695C,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('TQ9R8-TIdV4', 'قرآن هادئ للنوم — 10 ساعات | شاشة سوداء'),
            _yt('kXZgeu27BOo', 'قرآن للنوم — 10 ساعات | شاشة سوداء'),
            _yt('HOREcsKsjcU', 'سورة الملك مكررة — شاشة سوداء'),
            _yt('XqOhVxvooTY', 'رقية للبيت — عبد الرحمن السديس'),
            _yt('zVLxK5Kn6mE', 'رقية العين والحسد — شاشة سوداء'),
          ],
        ),
        _channel(
          id: 'masha_ar',
          title: 'ماشا والدب',
          order: 46,
          color: 0xFFE53935,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('N9HG6_hdotI', 'ساعة من المرح — ماشا والدب'),
            _yt('b_o6JWdrMB8', 'بيت بالمقلوب — ماشا والدب'),
            _yt('KedRL7GrXo8', 'الحَمَل الجديدة — ماشا والدب'),
            _yt('MZ_nL7BW4Wg', 'الطلاب المثاليون — ماشا والدب'),
            _yt('BmtZ9zo8XYs', 'سباحة أنيقة — ماشا والدب'),
            _yt('FFe8tPNw1AU', 'أكثر 10 حلقات مشاهدة — ماشا والدب'),
            _yt('lF3wFRw1Qa4', 'رحلة الدب — ماشا والدب'),
            _yt('ZYiKqKe4RYc', 'ما أجمل العمل — ماشا والدب'),
            _yt('uXCGuus_U1k', 'يوم الفنون والحِرف — ماشا والدب'),
            _yt('erwBhzx3eok', 'أفضل طريقة لقضاء اليوم — ماشا والدب'),
            _yt('EsGkXt6nneE', 'أميرة الأسنان الحلوة — ماشا والدب'),
          ],
        ),
        _channel(
          id: 'blippi_ar',
          title: 'بليبي بالعربي',
          order: 47,
          color: 0xFF039BE5,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('ZooIBL5z-s8', 'بليبي يزور ملعب داخلي'),
            _yt('fKBp_i03wSE', 'بليبي يزور مصنع للشوكولاتة'),
            _yt('XXyqtYoBXLg', 'بليبي يستكشف حيوانات الغابة'),
            _yt('si138Y1-xs0', 'بلبي يتعلم مهارات السيرك'),
            _yt('JE0MivjUzOc', 'قفزات بلبي على الترامبولين'),
            _yt('uwLH7U-AJ5M', 'سيارات بليبي السريعة'),
            _yt('8CU7aJRXb7U', 'ملعب بلِّيبي الداخلي الملون'),
            _yt('Ng2YGHBVRHw', 'اللعب بالصلصال مع بليبي'),
            _yt('TAs1xWSDgzw', 'بليبي يكتشف سيارات غو كارت'),
            _yt('cLGqn3nnuUk', 'اللعب بالصلصال مع بليبي — طين للأطفال'),
          ],
        ),
        _channel(
          id: 'disney_songs',
          title: 'Disney Songs',
          order: 48,
          color: 0xFF5C6BC0,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('L0MK7qz13bU', 'Let It Go — Sing-Along (Frozen)'),
            _yt('TeQ_TTyLGMs', 'Do You Want to Build a Snowman? — Sing-Along'),
            _yt('kQDw88hEr2c', 'Love Is an Open Door — Sing-Along (Frozen)'),
            _yt('r4KTqce-9Z0', "You're Welcome — Sing-Along (Moana)"),
            _yt('pnZbiKKydWU', "How Far I'll Go — Sing-Along (Moana)"),
            _yt('RTWhvp_OD6s', 'Where You Are — Sing-Along (Moana)'),
            _yt('ILRs2r6lcHY', 'I See the Light — Sing-Along (Tangled)'),
            _yt('0fVcwXbAWtA', 'When Will My Life Begin? — Sing-Along (Tangled)'),
            _yt('YRpvIiz9G8A', "We Don't Talk About Bruno — Sing-Along (Encanto)"),
            _yt('uh4dTLJ9q9o', 'Lava — Official Lyric Video'),
            _yt('6BH-Rxd-NBo', 'The Bare Necessities — Sing-Along (Jungle Book)'),
            _yt('GC_mV1IpjWA', 'Under the Sea — Official Video (Little Mermaid)'),
            _yt('1MPZRcyTrcU', "You've Got a Friend in Me — Toy Story"),
            _yt('0MxulhivCvI', 'Hakuna Matata — The Lion King'),
            _yt('eitDnP0_83k', 'A Whole New World — Aladdin'),
            _yt('bseyU2PvBQo', 'Hot Dog Dance Compilation — Mickey Mouse Clubhouse'),
            _yt('3f0C_PGcTAw', 'Welcome to the Clubhouse (Hot Dog!) — Mickey'),
            _yt('DAb93ws35gA', 'My Friends Tigger & Pooh Theme — Disney Junior'),
          ],
        ),
        _channel(
          id: 'babar',
          title: 'بابار',
          order: 50,
          color: 0xFF78909C,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('CKG8KXSiehs', 'Babar — The Elephant Express (Ep. 18)'),
            _yt('7x1RmD8gnug', 'Babar — Remember When… (Ep. 26)'),
            _yt('OzjPwN0rDY0', 'Babar — Monkey Business (Ep. 23)'),
            _yt('8lXs1qmACnU', 'Babar — A Tale of Two Siblings (Ep. 36)'),
            _yt('fbRBhg1tegQ', 'Babar — The City of Elephants (Ep. 4)'),
            _yt('tBebJGDwNC0', 'Babar — City Ways (Ep. 2)'),
            _yt('50jU1R3tNMM', "Babar — An Elephant's Best Friend (Ep. 9)"),
            _yt('USYFs3FfPT0', 'Babar — Between Friends (Ep. 16)'),
            _yt('sN52Lm31zDY', "Babar — What's Mine is Mine (Ep. 49)"),
            _yt('IBRWCeWhSGQ', 'Babar — My Dinner with Rataxes (Ep. 33)'),
            _yt('OhGOJoLKOts', 'Babar — Helping Hands (Ep. 54)'),
            _yt(
              '8Z5jvr_JJUk',
              'Babar & Badou — Kite Fight / Zoomerblimps (Ep. 9)',
            ),
            _yt(
              'uilO6OTjo-4',
              'Babar & Badou — The Brave Guy / Starring Ms. Strich (Ep. 14)',
            ),
            _yt(
              'PlKszSbTh1E',
              'Babar & Badou — The Unhidden Courtyard / The Rhino Rule (Ep. 36)',
            ),
            _yt(
              'hoT5HIAhTQ8',
              'Babar & Badou — Fair is Fair / Savanna Surfing (Ep. 55)',
            ),
            _yt(
              'QUkhjd127ho',
              'Babar & Badou — Ruby Rumpus / Dandy Andi (Ep. 17)',
            ),
            _yt(
              'Vl1F5cB8pqE',
              'Babar & Badou — The Thunderclap / Junior Marching Band (Ep. 4)',
            ),
            _yt(
              '_LmXqt73EVA',
              'Babar & Badou — Spy Trap / Sneazles (Ep. 1)',
            ),
          ],
        ),
        _channel(
          id: 'hadikat_almarah',
          title: 'حديقة المرح',
          order: 51,
          color: 0xFFAB47BC,
          sourceType: SourceType.youtubeVideoList,
          videos: [
            _yt('knTqvBZtgDc', 'نظيف نظيف — حديقة المرح | 1'),
            _yt('bGRQ9KBKpwA', 'جوجو — حديقة المرح | 2'),
            _yt('lZKz-xtGLiU', 'الطائرة الظريفة — حديقة المرح | 3'),
            _yt('talSXCgXMJk', 'أواني الزهور — حديقة المرح | 4'),
            _yt('EHCfylJXNto', 'الدمى المضحكة عال — حديقة المرح | 5'),
            _yt('rqmJ3-3kcEg', 'استيقظ إيجل بيجل — حديقة المرح'),
            _yt('DDhMUpA3CuA', 'حجر هوبزا هوب الخاصة — حديقة المرح'),
            _yt('fi1qBp_VNfY', '1 + 2 — حديقة المرح'),
            _yt('oRmgEaQAyQc', 'بطانية — حديقة المرح'),
            _yt('OA7fVAxkuxw', 'إخفاء — حديقة المرح'),
            _yt('9A-Cy0m0NHA', 'حلقة 230 — حديقة المرح'),
          ],
        ),
        _channel(
          id: 'minecraft',
          title: 'Minecraft',
          order: 52,
          color: 0xFF7CB342,
          playlist: _dadOliviaMinecraftPlaylist,
          videos: [
            _yt('3prPLWKeDiw', 'Dad And Olivia Play: Minecraft'),
            _yt('FjTATyVGl-o', 'Building our treehouse — Dad & Olivia'),
            _yt('y1pigDzOku0', "What's A Fish House? — Dad & Olivia"),
            _yt('rpZwIU0oZbg', 'Fish Problems — Dad & Olivia'),
            _yt('jeust7nhHdo', 'More Zoo Animals — Dad & Olivia'),
            _yt('O74nJOq3vjw', "We're Back! — Dad & Olivia Minecraft"),
            _yt('vBhSLvba0U8', 'Village Adventure — Dad & Olivia'),
            _yt('aayOk2wVf6w', 'NEW BABIES — Dad & Olivia'),
            _yt('dptgi5L8N7Y', 'Dad & Olivia Plus A Special Guest'),
            _yt('VO0Hf2q2FDY', 'We built our first cabin!'),
            _yt('pyLrc-CIm48', 'Our First Chicken Coop!'),
            _yt('sRPD8kEslRQ', 'Minecraft Makeover: Family Edition'),
            _yt('UVRFH_QIfFA', 'Pool & Barn — Let\'s Play Minecraft'),
            _yt('hp73MXqh0wE', 'Finding Puppies and Building Houses'),
            _yt('RfhUhx1MgS0', 'Building Amazing Villager Shops'),
            _yt('Fo21W_4F5KQ', 'Time To Build New Bases'),
            _yt('K6U_08kLB-E', 'Our New Sheep Farm'),
            _yt('gE8JZLs5xg8', 'How To Find All New Dogs!'),
          ],
        ),
    ];
    // Drop blocked titles even from the built-in seed.
    return CatalogSanitize.channels(channels);
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
      final followChanged = !current.playlistManagedByParent &&
          current.followUploads != seedCh.followUploads;

      final dropWrongKidsMusic = seedCh.id == 'kids_music' &&
          current.videos.any((v) => v.id == _retiredKidsMusicVideoId);
      final dropRetiredLive = (seedCh.id == 'live_makkah' ||
              seedCh.id == 'live_quran') &&
          current.videos.any((v) => retiredLiveVideoIds.contains(v.id));
      // Follow-off channels: drop leftover playlist-sync Shorts/promos that are
      // neither curated seed nor parent-manual.
      final seedVideoIds = {for (final v in seedCh.videos) v.id};
      final pruneStaleSync = !current.playlistManagedByParent &&
          !current.followUploads &&
          !seedCh.followUploads &&
          seedCh.videos.isNotEmpty;
      final baseVideos = [
        for (final v in current.videos)
          if ((!dropWrongKidsMusic || v.id != _retiredKidsMusicVideoId) &&
              (!dropRetiredLive || !retiredLiveVideoIds.contains(v.id)) &&
              (!pruneStaleSync || v.manual || seedVideoIds.contains(v.id)))
            v,
      ];
      final existingIds = baseVideos.map((v) => v.id).toSet();
      final missingVideos =
          seedCh.videos.where((v) => !existingIds.contains(v.id)).toList();
      final titleStale = current.title != seedCh.title &&
          (seedCh.id == 'spacetoon' ||
              clearSpacetoonUploads ||
              seedCh.id == 'live_makkah' ||
              seedCh.id == 'live_quran');
      final disableFromSeed = !seedCh.enabled && current.enabled;
      final prunedStale =
          pruneStaleSync && baseVideos.length != current.videos.length;

      if (clearSpacetoonUploads ||
          needsPlaylist ||
          replaceNumberblocksPlaylist ||
          followChanged ||
          missingVideos.isNotEmpty ||
          dropWrongKidsMusic ||
          dropRetiredLive ||
          prunedStale ||
          titleStale ||
          disableFromSeed) {
        final List<VideoItem> videos;
        if (clearSpacetoonUploads) {
          videos = seedCh.videos;
        } else if (current.videos.isEmpty && seedCh.videos.isNotEmpty) {
          videos = seedCh.videos;
        } else if (missingVideos.isNotEmpty ||
            dropWrongKidsMusic ||
            dropRetiredLive ||
            prunedStale) {
          videos = [...baseVideos, ...missingVideos];
        } else {
          videos = current.videos;
        }

        byId[seedCh.id] = current.copyWith(
          title: titleStale || clearSpacetoonUploads
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
          followUploads: current.playlistManagedByParent
              ? current.followUploads
              : seedCh.followUploads,
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
    return CatalogSanitize.channels(merged);
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
    bool followUploads = false,
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
      followUploads: followUploads,
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
