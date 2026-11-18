import 'package:flutter/material.dart';

// ─── Color Palette ────────────────────────────────────────────────────────────
// Strict "Board-First" dark charcoal with Neon Green and Gold accents
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bg0 = Color(0xFF0D0D0F); // deepest background
  static const Color bg1 = Color(0xFF141416); // scaffold
  static const Color bg2 = Color(0xFF1A1A1D); // card surface
  static const Color bg3 = Color(0xFF222226); // elevated card

  // Neon Green accents
  static const Color neonGreen = Color(0xFF39FF7E);
  static const Color neonGreenDim = Color(0xFF27C45C);
  static const Color neonGreenFaint = Color(0x2039FF7E);

  // Gold accents
  static const Color gold = Color(0xFFFFCC02);
  static const Color goldDim = Color(0xFFE5A800);
  static const Color goldFaint = Color(0x22FFCC02);

  // Text
  static const Color textPrimary = Color(0xFFF0F0F2);
  static const Color textSecondary = Color(0xFF8C8C9A);
  static const Color textDim = Color(0xFF55555E);

  // Borders / Dividers
  static const Color border = Color(0xFF2A2A30);
  static const Color borderBright = Color(0xFF3A3A44);

  // Semantic
  static const Color win = Color(0xFF39FF7E);
  static const Color loss = Color(0xFFFF3B5C);
  static const Color draw = Color(0xFF8C8C9A);
  static const Color check = Color(0xFFFF1744);
}

// ─── Design Tokens ────────────────────────────────────────────────────────────
class AppDimensions {
  AppDimensions._();

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 20.0;

  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  static const EdgeInsets cardPadding = EdgeInsets.all(14.0);
}

// ─── Board & Piece Theme Models ────────────────────────────────────────────────
class BoardThemeInfo {
  final String id;
  final String name;
  final String description;
  final String assetPath;
  final String? thumbnailPath;
  final Color fallbackLight;
  final Color fallbackDark;
  final String tag;
  final String specCode;

  const BoardThemeInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.assetPath,
    this.thumbnailPath,
    required this.fallbackLight,
    required this.fallbackDark,
    this.tag = 'RATED',
    this.specCode = 'SPEC-FID-990',
  });
}

class PieceSetInfo {
  final String id;
  final String name;
  final String description;
  final String styleCategory;
  final bool isWebp;

  const PieceSetInfo({
    required this.id,
    required this.name,
    required this.description,
    this.styleCategory = 'CLASSIC',
    this.isWebp = false,
  });

  String getPieceAsset(String piece) {
    final isWhite = piece == piece.toUpperCase();
    final prefix = isWhite ? 'w' : 'b';
    final symbol = piece.toUpperCase();
    final ext = isWebp ? 'webp' : 'svg';
    return 'assets/piece/$id/$prefix$symbol.$ext';
  }
}

// ─── App Themes Registry ───────────────────────────────────────────────────────
class AppThemes {
  AppThemes._();

  // All 24 authentic board themes mapped to assets/board/
  static const List<BoardThemeInfo> boardThemeList = [
    BoardThemeInfo(
      id: 'brown',
      name: 'Classic Wood',
      description: 'Warm natural oak and walnut tournament finish',
      assetPath: 'assets/board/brown.png',
      thumbnailPath: 'assets/board/brown.thumbnail.png',
      fallbackLight: Color(0xFFF0D9B5),
      fallbackDark: Color(0xFFB58863),
      tag: 'CLASSIC',
      specCode: 'SPEC-BRN-05',
    ),
    BoardThemeInfo(
      id: 'green',
      name: 'Tournament Green',
      description: 'Official FIDE world championship green tournament canvas',
      assetPath: 'assets/board/green.png',
      thumbnailPath: 'assets/board/green.thumbnail.png',
      fallbackLight: Color(0xFFEEEED2),
      fallbackDark: Color(0xFF769656),
      tag: 'FIDE',
      specCode: 'SPEC-GRN-07',
    ),
    BoardThemeInfo(
      id: 'grey',
      name: 'Midnight Dark',
      description: 'High-contrast modern stealth slate and carbon finish',
      assetPath: 'assets/board/grey.jpg',
      thumbnailPath: 'assets/board/grey.thumbnail.jpg',
      fallbackLight: Color(0xFF4A4A6A),
      fallbackDark: Color(0xFF1E1E3A),
      tag: 'STEALTH',
      specCode: 'SPEC-GRY-09',
    ),
    BoardThemeInfo(
      id: 'blue-marble',
      name: 'Blue Marble',
      description: 'Polished sapphire mineral with natural marble veining',
      assetPath: 'assets/board/blue-marble.jpg',
      thumbnailPath: 'assets/board/blue-marble.thumbnail.jpg',
      fallbackLight: Color(0xFFC4D7E8),
      fallbackDark: Color(0xFF4B6E96),
      tag: 'PREMIUM',
      specCode: 'SPEC-MAR-01',
    ),
    BoardThemeInfo(
      id: 'blue',
      name: 'Cyber Blue',
      description: 'Crisp digital cyan matrix for high-speed tactical clarity',
      assetPath: 'assets/board/blue.png',
      fallbackLight: Color(0xFFD4E4EC),
      fallbackDark: Color(0xFF55829D),
      tag: 'DIGITAL',
      specCode: 'SPEC-BLU-02',
    ),
    BoardThemeInfo(
      id: 'blue2',
      name: 'Deep Cobalt',
      description: 'Deep abyss cobalt slate with ambient eye-strain reduction',
      assetPath: 'assets/board/blue2.jpg',
      thumbnailPath: 'assets/board/blue2.thumbnail.jpg',
      fallbackLight: Color(0xFFDEE3E6),
      fallbackDark: Color(0xFF8CA2AD),
      tag: 'OLED',
      specCode: 'SPEC-BL2-03',
    ),
    BoardThemeInfo(
      id: 'blue3',
      name: 'Navy Titanium',
      description: 'Dark navy titanium mesh official tournament specification',
      assetPath: 'assets/board/blue3.jpg',
      thumbnailPath: 'assets/board/blue3.thumbnail.jpg',
      fallbackLight: Color(0xFFE0E6ED),
      fallbackDark: Color(0xFF4A688A),
      tag: 'RATED',
      specCode: 'SPEC-BL3-04',
    ),
    BoardThemeInfo(
      id: 'canvas2',
      name: 'Textured Canvas',
      description: 'Fine artist linen weave with soft non-glare illumination',
      assetPath: 'assets/board/canvas2.jpg',
      thumbnailPath: 'assets/board/canvas2.thumbnail.jpg',
      fallbackLight: Color(0xFFF3EFE0),
      fallbackDark: Color(0xFFB6A68E),
      tag: 'WARM',
      specCode: 'SPEC-CNV-06',
    ),
    BoardThemeInfo(
      id: 'green-plastic',
      name: 'Green Plastic',
      description: 'Club competition matte polymer finish for rapid play',
      assetPath: 'assets/board/green-plastic.png',
      thumbnailPath: 'assets/board/green-plastic.thumbnail.png',
      fallbackLight: Color(0xFFE2EAD6),
      fallbackDark: Color(0xFF678E56),
      tag: 'CLUB',
      specCode: 'SPEC-GPL-08',
    ),
    BoardThemeInfo(
      id: 'leather',
      name: 'Vintage Leather',
      description: 'Hand-stitched dark buffalo hide matrix with aged patina',
      assetPath: 'assets/board/leather.jpg',
      thumbnailPath: 'assets/board/leather.thumbnail.jpg',
      fallbackLight: Color(0xFFCFB396),
      fallbackDark: Color(0xFF7E523A),
      tag: 'LUXURY',
      specCode: 'SPEC-LTH-10',
    ),
    BoardThemeInfo(
      id: 'maple',
      name: 'Maple Wood',
      description: 'Fine grain Canadian maple with solid walnut inlays',
      assetPath: 'assets/board/maple.jpg',
      thumbnailPath: 'assets/board/maple.thumbnail.jpg',
      fallbackLight: Color(0xFFECE5D8),
      fallbackDark: Color(0xFFA57D52),
      tag: 'WOOD',
      specCode: 'SPEC-MPL-11',
    ),
    BoardThemeInfo(
      id: 'maple2',
      name: 'Maple Duo',
      description: 'Deep amber stained maple with rich satin sheen',
      assetPath: 'assets/board/maple2.jpg',
      thumbnailPath: 'assets/board/maple2.thumbnail.jpg',
      fallbackLight: Color(0xFFE8D4B4),
      fallbackDark: Color(0xFF9E6534),
      tag: 'WOOD',
      specCode: 'SPEC-MP2-12',
    ),
    BoardThemeInfo(
      id: 'marble',
      name: 'Classic Marble',
      description: 'Carrara white and nero marquina polished stone',
      assetPath: 'assets/board/marble.jpg',
      thumbnailPath: 'assets/board/marble.thumbnail.jpg',
      fallbackLight: Color(0xFFEAEAEA),
      fallbackDark: Color(0xFF7C878E),
      tag: 'STONE',
      specCode: 'SPEC-MRB-13',
    ),
    BoardThemeInfo(
      id: 'metal',
      name: 'Titanium Metal',
      description: 'Brushed aerospace alloy and gunmetal titanium plating',
      assetPath: 'assets/board/metal.jpg',
      thumbnailPath: 'assets/board/metal.thumbnail.jpg',
      fallbackLight: Color(0xFFBCC3CA),
      fallbackDark: Color(0xFF636D77),
      tag: 'CYBER',
      specCode: 'SPEC-MTL-14',
    ),
    BoardThemeInfo(
      id: 'ncf-board',
      name: 'NCF Championship',
      description: 'Nordic Chess Federation broadcast championship spec',
      assetPath: 'assets/board/ncf-board.png',
      fallbackLight: Color(0xFFFAF2E6),
      fallbackDark: Color(0xFFC0A080),
      tag: 'EVENT',
      specCode: 'SPEC-NCF-15',
    ),
    BoardThemeInfo(
      id: 'olive',
      name: 'Tactical Olive',
      description: 'Combat muted field olive drab and tactical khaki',
      assetPath: 'assets/board/olive.jpg',
      thumbnailPath: 'assets/board/olive.thumbnail.jpg',
      fallbackLight: Color(0xFFD3D8BC),
      fallbackDark: Color(0xFF6B754B),
      tag: 'TACTICAL',
      specCode: 'SPEC-OLV-16',
    ),
    BoardThemeInfo(
      id: 'pink-pyramid',
      name: 'Pink Pyramid',
      description: 'Synthwave pastel neon geometric contrast pattern',
      assetPath: 'assets/board/pink-pyramid.png',
      thumbnailPath: 'assets/board/pink-pyramid.thumbnail.png',
      fallbackLight: Color(0xFFFBE4EA),
      fallbackDark: Color(0xFFD67D9C),
      tag: 'SYNTH',
      specCode: 'SPEC-PNK-17',
    ),
    BoardThemeInfo(
      id: 'purple',
      name: 'Cyber Purple',
      description: 'Deep violet phosphor and ultraviolet energy grid',
      assetPath: 'assets/board/purple.png',
      thumbnailPath: 'assets/board/purple.thumbnail.png',
      fallbackLight: Color(0xFFD8C7E8),
      fallbackDark: Color(0xFF7B52AB),
      tag: 'NEON',
      specCode: 'SPEC-PRP-18',
    ),
    BoardThemeInfo(
      id: 'purple-diag',
      name: 'Purple Matrix',
      description: 'Diagonal etched ultraviolet energy gridlines',
      assetPath: 'assets/board/purple-diag.png',
      thumbnailPath: 'assets/board/purple-diag.thumbnail.png',
      fallbackLight: Color(0xFFE2D6F5),
      fallbackDark: Color(0xFF885FC7),
      tag: 'MATRIX',
      specCode: 'SPEC-PDI-19',
    ),
    BoardThemeInfo(
      id: 'wood',
      name: 'Rustic Wood',
      description: 'Hand-carved solid mahogany and beech tournament board',
      assetPath: 'assets/board/wood.jpg',
      thumbnailPath: 'assets/board/wood.thumbnail.jpg',
      fallbackLight: Color(0xFFECD5A7),
      fallbackDark: Color(0xFFA36B39),
      tag: 'NATURAL',
      specCode: 'SPEC-WD1-20',
    ),
    BoardThemeInfo(
      id: 'wood2',
      name: 'Dark Mahogany',
      description: 'Rich dark ebony stain with satin protective lacquer',
      assetPath: 'assets/board/wood2.jpg',
      thumbnailPath: 'assets/board/wood2.thumbnail.jpg',
      fallbackLight: Color(0xFFD7B88C),
      fallbackDark: Color(0xFF82532E),
      tag: 'WOOD',
      specCode: 'SPEC-WD2-21',
    ),
    BoardThemeInfo(
      id: 'wood3',
      name: 'Oak Rustic',
      description: 'Aged highland oak with authentic natural grain texture',
      assetPath: 'assets/board/wood3.jpg',
      thumbnailPath: 'assets/board/wood3.thumbnail.jpg',
      fallbackLight: Color(0xFFE1C699),
      fallbackDark: Color(0xFF91683E),
      tag: 'WOOD',
      specCode: 'SPEC-WD3-22',
    ),
    BoardThemeInfo(
      id: 'wood4',
      name: 'Cedar Wood',
      description: 'Light golden cedar with subtle rings and warm tones',
      assetPath: 'assets/board/wood4.jpg',
      thumbnailPath: 'assets/board/wood4.thumbnail.jpg',
      fallbackLight: Color(0xFFF2DFC0),
      fallbackDark: Color(0xFFA87E50),
      tag: 'WOOD',
      specCode: 'SPEC-WD4-23',
    ),
    BoardThemeInfo(
      id: 'ic',
      name: 'ICC Classic',
      description: 'Internet Chess Club heritage green and buff theme',
      assetPath: 'assets/board/ic.png',
      thumbnailPath: 'assets/board/ic.thumbnail.png',
      fallbackLight: Color(0xFFEAE6D2),
      fallbackDark: Color(0xFF8B9D77),
      tag: 'RETRO',
      specCode: 'SPEC-ICC-24',
    ),
    BoardThemeInfo(
      id: 'horsey',
      name: 'Horsey Meme',
      description: 'Playful lichess mascot easter egg board pattern',
      assetPath: 'assets/board/horsey.jpg',
      thumbnailPath: 'assets/board/horsey.thumbnail.jpg',
      fallbackLight: Color(0xFFFFF2D6),
      fallbackDark: Color(0xFFC79E5E),
      tag: 'MEME',
      specCode: 'SPEC-HRS-25',
    ),
  ];

  // All 44 authentic piece sets mapped to assets/piece/
  static const List<PieceSetInfo> pieceSetList = [
    PieceSetInfo(
      id: 'cburnett',
      name: 'CBurnett',
      description: 'Clean modern international tournament standard',
      styleCategory: 'TOURNAMENT',
    ),
    PieceSetInfo(
      id: 'alpha',
      name: 'Alpha',
      description: 'Crisp classical Staunton vectors with bold profiles',
      styleCategory: 'CLASSIC',
    ),
    PieceSetInfo(
      id: 'merida',
      name: 'Merida',
      description: 'World championship broadcast standard styling',
      styleCategory: 'PRO',
    ),
    PieceSetInfo(
      id: 'staunty',
      name: 'Staunty',
      description: 'Authentic 1849 Jacques of London Staunton pattern',
      styleCategory: 'HERITAGE',
    ),
    PieceSetInfo(
      id: 'caliente',
      name: 'Caliente',
      description: 'Sharp dynamic curves with fiery Latin flair',
      styleCategory: 'MODERN',
    ),
    PieceSetInfo(
      id: 'california',
      name: 'California',
      description: 'West Coast sleek minimalist tournament contours',
      styleCategory: 'MINIMAL',
    ),
    PieceSetInfo(
      id: 'cardinal',
      name: 'Cardinal',
      description: 'Heavy gothic mitre curves and striking crown',
      styleCategory: 'GOTHIC',
    ),
    PieceSetInfo(
      id: 'celtic',
      name: 'Celtic',
      description: 'Intricate insular knotwork and ancient silhouettes',
      styleCategory: 'FANTASY',
    ),
    PieceSetInfo(
      id: 'chess7',
      name: 'Chess 7',
      description: 'Glossy 3D rendered bevels and specular shine',
      styleCategory: 'GLOSS',
    ),
    PieceSetInfo(
      id: 'chessboart',
      name: 'Chessboart',
      description: 'Artistic chalk sketch on chalkboard texture',
      styleCategory: 'ART',
    ),
    PieceSetInfo(
      id: 'chessnut',
      name: 'Chessnut',
      description: 'Smooth rounded friendly modern gaming vectors',
      styleCategory: 'CASUAL',
    ),
    PieceSetInfo(
      id: 'companion',
      name: 'Companion',
      description: 'Soft ergonomic geometry for extended blitz play',
      styleCategory: 'CASUAL',
    ),
    PieceSetInfo(
      id: 'cooke',
      name: 'Cooke',
      description: 'Handcrafted mid-century woodcarver aesthetic',
      styleCategory: 'HERITAGE',
    ),
    PieceSetInfo(
      id: 'disguised',
      name: 'Disguised',
      description: 'Geometric camouflage stealth vectors',
      styleCategory: 'TACTICAL',
    ),
    PieceSetInfo(
      id: 'dubrovny',
      name: 'Dubrovnik',
      description: 'Famous 1950 IX Chess Olympiad design preferred by Fischer',
      styleCategory: 'OLYMPIAD',
    ),
    PieceSetInfo(
      id: 'fantasy',
      name: 'Fantasy',
      description: 'High fantasy medieval knight and sorcery pieces',
      styleCategory: 'FANTASY',
    ),
    PieceSetInfo(
      id: 'firi',
      name: 'Firi',
      description: 'Futuristic sci-fi cybernetic silhouettes',
      styleCategory: 'CYBER',
    ),
    PieceSetInfo(
      id: 'fresca',
      name: 'Fresca',
      description: 'Italian fresco airy minimalist line art',
      styleCategory: 'MINIMAL',
    ),
    PieceSetInfo(
      id: 'gioco',
      name: 'Gioco',
      description: 'Balanced classical European tournament carving',
      styleCategory: 'CLASSIC',
    ),
    PieceSetInfo(
      id: 'governor',
      name: 'Governor',
      description: 'Majestic tall silhouettes with commanding crowns',
      styleCategory: 'ROYAL',
    ),
    PieceSetInfo(
      id: 'horsey',
      name: 'Horsey',
      description: 'Whimsical legendary lichess mascot knight set',
      styleCategory: 'MEME',
    ),
    PieceSetInfo(
      id: 'icpieces',
      name: 'IC Pieces',
      description: 'Internet Chess Club nostalgia 90s vectors',
      styleCategory: 'RETRO',
    ),
    PieceSetInfo(
      id: 'kiwen-suwi',
      name: 'Kiwen Suwi',
      description: 'Toki Pona hieroglyphic cute glyphs',
      styleCategory: 'INDIE',
    ),
    PieceSetInfo(
      id: 'kosal',
      name: 'Kosal',
      description: 'Expressive calligraphic brush strokes',
      styleCategory: 'ART',
    ),
    PieceSetInfo(
      id: 'leipzig',
      name: 'Leipzig',
      description: 'German Bundesliga traditional turnier pattern',
      styleCategory: 'GERMAN',
    ),
    PieceSetInfo(
      id: 'letter',
      name: 'Letter',
      description: 'Typographical monospaced characters',
      styleCategory: 'TYPO',
    ),
    PieceSetInfo(
      id: 'maestro',
      name: 'Maestro',
      description: 'Grandmaster tournament heavy weighting',
      styleCategory: 'PRO',
    ),
    PieceSetInfo(
      id: 'minimal-warmth',
      name: 'Minimal Warmth',
      description: 'Pure geometric minimalism with rounded junctions',
      styleCategory: 'MINIMAL',
    ),
    PieceSetInfo(
      id: 'monarchy',
      name: 'Monarchy',
      description: 'Detailed renaissance imperial portraits',
      styleCategory: 'ROYAL',
      isWebp: true,
    ),
    PieceSetInfo(
      id: 'mono',
      name: 'Mono Wireframe',
      description: 'Continuous single-stroke technical blueprints',
      styleCategory: 'CYBER',
    ),
    PieceSetInfo(
      id: 'mpchess',
      name: 'MP Chess',
      description: 'Low-poly faceted polygonal 3D aesthetics',
      styleCategory: 'POLYGON',
    ),
    PieceSetInfo(
      id: 'papercut',
      name: 'Papercut',
      description: 'Hand-cut origami layered paper silhouettes',
      styleCategory: 'CRAFT',
    ),
    PieceSetInfo(
      id: 'pirouetti',
      name: 'Pirouetti',
      description: 'Playful curved spirals and dynamic ballet forms',
      styleCategory: 'WHIMSICAL',
    ),
    PieceSetInfo(
      id: 'pixel',
      name: 'Pixel 8-Bit',
      description: 'Retro arcade 8-bit sprites from golden era gaming',
      styleCategory: 'RETRO',
    ),
    PieceSetInfo(
      id: 'reillycraig',
      name: 'Reilly Craig',
      description: 'Bold woodblock print with tactile edge cuts',
      styleCategory: 'ART',
    ),
    PieceSetInfo(
      id: 'rhosgfx',
      name: 'Rhos GFX',
      description: 'High-tech neon geometric circuit board vectors',
      styleCategory: 'CYBER',
    ),
    PieceSetInfo(
      id: 'riohacha',
      name: 'Riohacha',
      description: 'South American geometric native abstraction',
      styleCategory: 'INDIE',
    ),
    PieceSetInfo(
      id: 'shahi-ivory-brown',
      name: 'Shahi Ivory',
      description: 'Ancient royal Indian palace handcrafted ivory',
      styleCategory: 'HERITAGE',
    ),
    PieceSetInfo(
      id: 'shapes',
      name: 'Shapes',
      description: 'Bauhaus pure geometric primary shape system',
      styleCategory: 'BAUHAUS',
    ),
    PieceSetInfo(
      id: 'spatial',
      name: 'Spatial',
      description: 'Cosmic orbit trajectories and planetary rings',
      styleCategory: 'SCI-FI',
    ),
    PieceSetInfo(
      id: 'tatiana',
      name: 'Tatiana',
      description: 'Delicate cursive filigree and royal emblems',
      styleCategory: 'ELEGANT',
    ),
    PieceSetInfo(
      id: 'totoy',
      name: 'Totoy',
      description: 'Charming carved wooden pegboard toy aesthetic',
      styleCategory: 'CASUAL',
    ),
    PieceSetInfo(
      id: 'xkcd',
      name: 'XKCD Comic',
      description: 'Humorous webcomic stick figure chess pieces',
      styleCategory: 'COMIC',
    ),
    PieceSetInfo(
      id: 'anarcandy',
      name: 'Anarcandy',
      description: 'Colorful pastel candy confections',
      styleCategory: 'POP',
    ),
  ];

  // Board themes fallback color map (ensures 100% compatibility with tests)
  static final Map<String, List<Color>> boardThemes = {
    'classic_wood': [const Color(0xFFF0D9B5), const Color(0xFFB58863)],
    'tournament_green': [const Color(0xFFEEEED2), const Color(0xFF769656)],
    'midnight_dark': [const Color(0xFF4A4A6A), const Color(0xFF1E1E3A)],
    'cyber_slate': [const Color(0xFFCFD8DC), const Color(0xFF16202C)],
    'tactical_dark': [const Color(0xFF242A33), const Color(0xFF161C24)],
    'neon_night': [const Color(0xFF1C2535), const Color(0xFF0D1520)],
    for (final b in boardThemeList) b.id: [b.fallbackLight, b.fallbackDark],
  };

  // Piece style themes lookup
  static final Map<String, String> pieceThemes = {
    for (final p in pieceSetList) p.id: p.name,
    'tactical': 'CBurnett',
    'classic': 'Alpha',
    'neon_phosphor': 'Rhos GFX',
    'obsidian': 'Merida',
  };

  static BoardThemeInfo getBoardTheme(String id) {
    // Check aliases
    final canonicalId = switch (id) {
      'classic_wood' => 'brown',
      'tournament_green' => 'green',
      'midnight_dark' => 'grey',
      'cyber_slate' => 'blue3',
      'tactical_dark' => 'olive',
      'neon_night' => 'purple',
      _ => id,
    };

    return boardThemeList.firstWhere(
      (b) => b.id == canonicalId || b.id == id,
      orElse: () => boardThemeList.firstWhere((b) => b.id == 'green'),
    );
  }

  static PieceSetInfo getPieceSet(String id) {
    // Check aliases
    final canonicalId = switch (id) {
      'tactical' => 'cburnett',
      'classic' => 'alpha',
      'neon_phosphor' => 'rhosgfx',
      'obsidian' => 'merida',
      _ => id,
    };

    return pieceSetList.firstWhere(
      (p) => p.id == canonicalId || p.id == id,
      orElse: () => pieceSetList.firstWhere((p) => p.id == 'cburnett'),
    );
  }

  static ThemeData get darkTheme => ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.neonGreen,
          secondary: AppColors.gold,
          surface: AppColors.bg2,
          onPrimary: AppColors.bg1,
          onSecondary: AppColors.bg1,
          onSurface: AppColors.textPrimary,
          error: AppColors.loss,
        ),
        scaffoldBackgroundColor: AppColors.bg1,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg1,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.bg2,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppDimensions.radiusMedium),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.bg3,
          selectedColor: AppColors.neonGreenFaint,
          side: const BorderSide(color: AppColors.border),
          labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          bodyMedium: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
          bodySmall: TextStyle(
            color: AppColors.textDim,
            fontSize: 11,
          ),
          labelSmall: TextStyle(
            color: AppColors.textDim,
            fontSize: 10,
          ),
        ),
      );
}
