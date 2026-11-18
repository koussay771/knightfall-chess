import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/theme_constants.dart';
import '../../core/providers/theme_provider.dart';
import '../game/board_widget.dart';

/// Next-Gen Themes & Visual Rig screen matching design/screen_theme (Pixel-for-pixel):
/// - Dual-section / multi-tab selector: Board Canvas, Piece Matrix, Showcase
/// - Live 8x8 Board Preview Container with real assets and instant touch feedback
/// - Maps strictly to authentic assets inside assets/board/ and assets/piece/
/// - Telemetry micro-stat row and sticky bottom command bar with [Apply] & [Inspect]
class ThemeScreen extends ConsumerStatefulWidget {
  const ThemeScreen({super.key});

  @override
  ConsumerState<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends ConsumerState<ThemeScreen> {
  // Tabs: 0 = Board Canvas, 1 = Piece Matrix, 2 = Showcase
  int _activeTab = 0;
  bool _isFlipped = false;
  String _previewBoardId = 'green';
  String _previewPieceId = 'cburnett';

  // Standard preview FEN
  static const String _previewFen =
      'r1bqkb1r/pppp1ppp/2n5/4p3/2B1n3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 5';

  @override
  void initState() {
    super.initState();
    _loadCurrentThemes();
  }

  Future<void> _loadCurrentThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBoard = prefs.getString('board_theme') ?? 'green';
    final savedPiece = prefs.getString('piece_theme') ?? 'cburnett';

    if (mounted) {
      setState(() {
        _previewBoardId = savedBoard;
        _previewPieceId = savedPiece;
      });
    }
  }

  Future<void> _applyTheme({required String boardId, required String pieceId}) async {
    // Save to Riverpod providers & SharedPreferences
    await ref.read(boardThemeProvider.notifier).setTheme(boardId);
    await ref.read(pieceThemeProvider.notifier).setTheme(pieceId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('board_theme', boardId);
    await prefs.setString('piece_theme', pieceId);

    final boardInfo = AppThemes.getBoardTheme(boardId);
    final pieceInfo = AppThemes.getPieceSet(pieceId);

    _showToast('Applied ${boardInfo.name} & ${pieceInfo.name} to Board Engine');
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF161C24),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF242A33)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBoardId = ref.watch(boardThemeProvider);
    final currentPieceId = ref.watch(pieceThemeProvider);

    final activeBoard = AppThemes.getBoardTheme(_previewBoardId);
    final activePiece = AppThemes.getPieceSet(_previewPieceId);

    return Scaffold(
      backgroundColor: const Color(0xFF0E141C),
      body: SafeArea(
        child: Column(
          children: [
            // ── 1. Top Navigation & Branding Header ──
            _buildTopHeader(),

            // ── 2. Top Segmented Navigation (Board Canvas / Piece Matrix / Showcase) ──
            _buildSegmentedNav(),

            // ── 3. Scrollable Visual Rig Area ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sub-bar Mode indicator
                    _buildSubBar(activeBoard, activePiece),
                    const SizedBox(height: 8),

                    // Active Section Content based on selected Tab
                    if (_activeTab == 0)
                      _buildBoardCanvasGrid(currentBoardId)
                    else if (_activeTab == 1)
                      _buildPieceMatrixGrid(currentPieceId)
                    else
                      _buildShowcaseDualSelector(currentBoardId, currentPieceId),

                    const SizedBox(height: 14),

                    // Hero 8x8 Live Board Preview Container
                    _buildHeroPreviewContainer(activeBoard, activePiece),
                    const SizedBox(height: 12),

                    // Telemetry Micro-Stat Row
                    _buildTelemetryRow(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── 4. Bottom Sticky Command Bar [ Inspect ] & [ Apply Canvas ] ──
            _buildBottomCommandBar(),
          ],
        ),
      ),
    );
  }

  // ── Top Header Bar ────────────────────────────────────────────────────────
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: const BoxDecoration(
        color: Color(0xFF0E141C),
        border: Border(bottom: BorderSide(color: Color(0xFF161C24), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFFDDE3EE), size: 20),
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 20,
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Board Canvas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDDE3EE),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Vulkan 60FPS Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF242A33),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00FF88),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'VULKAN 60FPS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00FF88),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Board Themes & Visual Rig Studio',
                    style: TextStyle(fontSize: 10, color: Color(0xFF849585)),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.tune, color: Color(0xFFB9CBB9), size: 19),
                onPressed: () {},
                splashRadius: 18,
              ),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1FFEF),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x3300FF88), blurRadius: 8),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.person, color: Color(0xFF003919), size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Segmented Nav Bar (Board Canvas / Piece Matrix / Showcase) ─────────────
  Widget _buildSegmentedNav() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF090F16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF161C24)),
      ),
      child: Row(
        children: [
          _buildNavTab(
            index: 0,
            icon: Icons.grid_view,
            label: 'Board Canvas',
          ),
          _buildNavTab(
            index: 1,
            icon: Icons.token,
            label: 'Piece Matrix',
          ),
          _buildNavTab(
            index: 2,
            icon: Icons.visibility,
            label: 'Showcase',
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF242A33) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x2200FF88),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFF00FF88) : const Color(0xFF849585),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.3,
                  color: isSelected ? const Color(0xFF00FF88) : const Color(0xFFB9CBB9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-bar Mode Indicator ────────────────────────────────────────────────
  Widget _buildSubBar(BoardThemeInfo activeBoard, PieceSetInfo activePiece) {
    final title = _activeTab == 0
        ? 'CANVAS PRESETS'
        : _activeTab == 1
            ? 'PIECE MATRIX SETS'
            : 'TACTICAL RIG SHOWCASE';

    final countStr = _activeTab == 0
        ? '${AppThemes.boardThemeList.length} ACTIVE'
        : _activeTab == 1
            ? '${AppThemes.pieceSetList.length} ACTIVE'
            : 'REAL-TIME COMBO';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF00FF88),
                boxShadow: [
                  BoxShadow(color: Color(0xCC00FF88), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: Color(0xFFDDE3EE),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF242A33),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                countStr,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00FF88),
                ),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF090F16),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF161C24)),
          ),
          child: Text(
            activeBoard.tag,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB9CBB9),
            ),
          ),
        ),
      ],
    );
  }

  // ── Hero 8x8 Live Board Preview Container ─────────────────────────────────
  Widget _buildHeroPreviewContainer(
    BoardThemeInfo activeBoard,
    PieceSetInfo activePiece,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242A33), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Preview Header Meta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F353E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Icon(Icons.visibility, size: 16, color: Color(0xFF00FF88)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Live: ${_activeTab == 1 ? activePiece.name : activeBoard.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDDE3EE),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0x3300FF88),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'PREVIEW',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00FF88),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _activeTab == 1 ? activePiece.description : activeBoard.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF849585)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F353E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'RENDER: 2.1ms',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00FF88),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => setState(() => _isFlipped = !_isFlipped),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF242A33),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Icon(Icons.sync, size: 16, color: Color(0xFFDDE3EE)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 8x8 Tactile Chessboard
          SizedBox(
            width: double.infinity,
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF090F16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: BoardWidget(
                  fen: _previewFen,
                  flipped: _isFlipped,
                  boardTheme: _previewBoardId,
                  pieceTheme: _previewPieceId,
                  lightSquareColor: activeBoard.fallbackLight,
                  darkSquareColor: activeBoard.fallbackDark,
                  lastMoveFrom: 'f3',
                  lastMoveTo: 'e4',
                  onSquareTapped: (sq) {},
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Active Style Specs Pill Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF00FF88),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Vulkan Engine • 60 FPS Locked',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      color: Color(0xFFDDE3EE),
                    ),
                  ),
                ],
              ),
              Text(
                activeBoard.specCode,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: Color(0xFF849585),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 0: Board Canvas Grid (Real Assets from assets/board/) ──────────────
  Widget _buildBoardCanvasGrid(String currentBoardId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Board Themes',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Color(0xFF849585),
              ),
            ),
            Text(
              'TAP TO PREVIEW',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FF88),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.55,
          ),
          itemCount: AppThemes.boardThemeList.length,
          itemBuilder: (context, index) {
            final theme = AppThemes.boardThemeList[index];
            final isPreview = _previewBoardId == theme.id ||
                (_previewBoardId == 'classic_wood' && theme.id == 'brown') ||
                (_previewBoardId == 'tournament_green' && theme.id == 'green') ||
                (_previewBoardId == 'midnight_dark' && theme.id == 'grey');

            return GestureDetector(
              onTap: () async {
                setState(() {
                  _previewBoardId = theme.id;
                });
                final keyToSave = theme.id == 'brown'
                    ? 'classic_wood'
                    : (theme.id == 'green'
                        ? 'tournament_green'
                        : (theme.id == 'grey' ? 'midnight_dark' : theme.id));
                await ref.read(boardThemeProvider.notifier).setTheme(keyToSave);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('board_theme', keyToSave);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPreview ? const Color(0xFF242A33) : const Color(0xFF161C24),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPreview ? const Color(0xFF00FF88) : const Color(0xFF242A33),
                    width: isPreview ? 1.8 : 1.0,
                  ),
                  boxShadow: isPreview
                      ? const [
                          BoxShadow(
                            color: Color(0x3300FF88),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top: Mini swatch & Radio indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 2x2 Board Swatch preview
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: Image.asset(
                              theme.thumbnailPath ?? theme.assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _build2x2Fallback(
                                theme.fallbackLight,
                                theme.fallbackDark,
                              ),
                            ),
                          ),
                        ),
                        // Radio indicator
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPreview
                                ? const Color(0xFF00FF88)
                                : const Color(0xFF2F353E),
                            boxShadow: isPreview
                                ? const [
                                    BoxShadow(
                                      color: Color(0x6600FF88),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isPreview
                              ? const Center(
                                  child: Icon(Icons.check, size: 12, color: Color(0xFF003919)),
                                )
                              : null,
                        ),
                      ],
                    ),

                    // Middle: Title & Description
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          theme.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isPreview ? Colors.white : const Color(0xFFDDE3EE),
                          ),
                        ),
                        Text(
                          theme.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFF849585),
                          ),
                        ),
                      ],
                    ),

                    // Bottom: Tag & Spec code
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090F16),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            theme.tag,
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00FF88),
                            ),
                          ),
                        ),
                        Text(
                          theme.specCode,
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontFamily: 'monospace',
                            color: Color(0xFF849585),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _build2x2Fallback(Color light, Color dark) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: Container(color: light)),
              Expanded(child: Container(color: dark)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: Container(color: dark)),
              Expanded(child: Container(color: light)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab 1: Piece Matrix Grid (Real Assets from assets/piece/) ───────────────
  Widget _buildPieceMatrixGrid(String currentPieceId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PIECE MATRIX SETS (${AppThemes.pieceSetList.length})',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Color(0xFF849585),
              ),
            ),
            const Text(
              'TAP TO PREVIEW',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FF88),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.55,
          ),
          itemCount: AppThemes.pieceSetList.length,
          itemBuilder: (context, index) {
            final pieceSet = AppThemes.pieceSetList[index];
            final isPreview = _previewPieceId == pieceSet.id ||
                (_previewPieceId == 'tactical' && pieceSet.id == 'cburnett') ||
                (_previewPieceId == 'classic' && pieceSet.id == 'alpha');

            return GestureDetector(
              onTap: () {
                setState(() {
                  _previewPieceId = pieceSet.id;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPreview ? const Color(0xFF242A33) : const Color(0xFF161C24),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isPreview ? const Color(0xFF00FF88) : const Color(0xFF242A33),
                    width: isPreview ? 1.8 : 1.0,
                  ),
                  boxShadow: isPreview
                      ? const [
                          BoxShadow(
                            color: Color(0x3300FF88),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top: Mini piece icons & Radio check
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Piece sample strip (King, Knight, Pawn)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090F16),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              _buildMiniPieceAsset(pieceSet, 'K', 16),
                              const SizedBox(width: 3),
                              _buildMiniPieceAsset(pieceSet, 'N', 16),
                              const SizedBox(width: 3),
                              _buildMiniPieceAsset(pieceSet, 'P', 14),
                            ],
                          ),
                        ),
                        // Radio indicator
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPreview
                                ? const Color(0xFF00FF88)
                                : const Color(0xFF2F353E),
                            boxShadow: isPreview
                                ? const [
                                    BoxShadow(
                                      color: Color(0x6600FF88),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isPreview
                              ? const Center(
                                  child: Icon(Icons.check, size: 12, color: Color(0xFF003919)),
                                )
                              : null,
                        ),
                      ],
                    ),

                    // Middle: Title & Description
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pieceSet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isPreview ? Colors.white : const Color(0xFFDDE3EE),
                          ),
                        ),
                        Text(
                          pieceSet.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFF849585),
                          ),
                        ),
                      ],
                    ),

                    // Bottom: Category badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090F16),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            pieceSet.styleCategory,
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00FF88),
                            ),
                          ),
                        ),
                        Text(
                          pieceSet.isWebp ? 'WEBP' : 'SVG',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontFamily: 'monospace',
                            color: Color(0xFF849585),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMiniPieceAsset(PieceSetInfo pieceSet, String symbol, double size) {
    final assetPath = pieceSet.getPieceAsset(symbol);

    if (pieceSet.isWebp) {
      return Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text(
          '♔',
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
      );
    }

    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => const Text(
        '♔',
        style: TextStyle(fontSize: 14, color: Colors.white70),
      ),
    );
  }

  // ── Tab 2: Showcase Dual-Section Selector ─────────────────────────────────
  Widget _buildShowcaseDualSelector(String currentBoardId, String currentPieceId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DUAL-SECTION SYNC RIG',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Color(0xFF849585),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pick both your board canvas and piece set simultaneously with real-time live preview.',
          style: TextStyle(fontSize: 11, color: Color(0xFFB9CBB9)),
        ),
        const SizedBox(height: 12),

        // Quick Board Horizontal Carousel
        const Text(
          'QUICK BOARD PRESETS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: Color(0xFF00FF88),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: AppThemes.boardThemeList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final b = AppThemes.boardThemeList[i];
              final isSel = _previewBoardId == b.id;

              return GestureDetector(
                onTap: () => setState(() => _previewBoardId = b.id),
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF242A33) : const Color(0xFF161C24),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? const Color(0xFF00FF88) : const Color(0xFF242A33),
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: Image.asset(
                            b.thumbnailPath ?? b.assetPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _build2x2Fallback(b.fallbackLight, b.fallbackDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          b.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel ? Colors.white : const Color(0xFFDDE3EE),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // Quick Piece Horizontal Carousel
        const Text(
          'QUICK PIECE SETS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: Color(0xFF00FF88),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: AppThemes.pieceSetList.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final p = AppThemes.pieceSetList[i];
              final isSel = _previewPieceId == p.id;

              return GestureDetector(
                onTap: () => setState(() => _previewPieceId = p.id),
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF242A33) : const Color(0xFF161C24),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel ? const Color(0xFF00FF88) : const Color(0xFF242A33),
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildMiniPieceAsset(p, 'K', 24),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel ? Colors.white : const Color(0xFFDDE3EE),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Telemetry Micro-Stat Row ──────────────────────────────────────────────
  Widget _buildTelemetryRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF090F16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF161C24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.memory, size: 18, color: Color(0xFF00FF88)),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GPU SHADER COMPILATION',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                      color: Color(0xFFDDE3EE),
                    ),
                  ),
                  Text(
                    'Zero-overhead offline cache ready',
                    style: TextStyle(fontSize: 9.5, color: Color(0xFF849585)),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF242A33),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00FF88),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'HOT RELOAD',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00FF88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Fixed Command Bar ──────────────────────────────────────────────
  Widget _buildBottomCommandBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: const BoxDecoration(
        color: Color(0xFF0E141C),
        border: Border(top: BorderSide(color: Color(0xFF161C24), width: 1)),
      ),
      child: Row(
        children: [
          // Secondary Button: Inspect
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showToast(
                    'Board: ${AppThemes.getBoardTheme(_previewBoardId).name} • Piece: ${AppThemes.getPieceSet(_previewPieceId).name}',
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDDE3EE),
                  backgroundColor: const Color(0xFF161C24),
                  side: const BorderSide(color: Color(0xFF242A33)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.center_focus_strong, size: 16),
                label: const Text(
                  'INSPECT',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Primary Emerald Action: Apply Canvas / Rig
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _applyTheme(
                  boardId: _previewBoardId,
                  pieceId: _previewPieceId,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  foregroundColor: const Color(0xFF003919),
                  elevation: 0,
                  shadowColor: const Color(0x6600FF88),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text(
                  'APPLY CANVAS',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
