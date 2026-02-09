import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
// Warm dark tones inspired by Magisterium.com + Christendom.app
const _bgDeep = Color(0xFF0c0a09); // stone-950
const _bgSurface = Color(0xFF1c1917); // stone-900
const _bgSurfaceAlt = Color(0xFF171412); // between 950 and 900
const _bgCard = Color(0xFF292524); // stone-800
const _borderSubtle = Color(0xFF44403c); // stone-700
const _borderFaint = Color(0xFF292524); // stone-800
const _textPrimary = Color(0xFFfafaf9); // stone-50
const _textSecondary = Color(0xFFa8a29e); // stone-400
const _accentGold = Color(0xFFd4a24e); // warm gold
const _accentGoldMuted = Color(0xFF8b6914); // darker gold
const _accentGreen = Color(0xFF16a34a); // magisterium green

void main() => runApp(const MhsViewerApp());

class MhsViewerApp extends StatelessWidget {
  const MhsViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MHS Dossier — DOMOVINA.tv',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bgDeep,
        colorScheme: const ColorScheme.dark(
          surface: _bgSurface,
          primary: _accentGold,
          secondary: _accentGreen,
          outline: _borderSubtle,
        ),
        useMaterial3: true,
      ),
      home: const DualMarkdownViewer(),
    );
  }
}

// ── Section splitter ─────────────────────────────────────────────────────────

List<String> _splitBySections(String markdown) {
  final lines = markdown.split('\n');
  final sections = <String>[];
  final buffer = StringBuffer();

  for (final line in lines) {
    if (line.startsWith('## ') && buffer.isNotEmpty) {
      sections.add(buffer.toString().trim());
      buffer.clear();
    }
    buffer.writeln(line);
  }
  if (buffer.isNotEmpty) {
    sections.add(buffer.toString().trim());
  }
  return sections;
}

// ── Main viewer ──────────────────────────────────────────────────────────────

class DualMarkdownViewer extends StatefulWidget {
  const DualMarkdownViewer({super.key});

  @override
  State<DualMarkdownViewer> createState() => _DualMarkdownViewerState();
}

class _DualMarkdownViewerState extends State<DualMarkdownViewer> {
  List<String> _enSections = [];
  List<String> _hrSections = [];
  bool _loading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final en = await rootBundle.loadString('mhs-001.en.md');
    final hr = await rootBundle.loadString('mhs-001.hr.md');
    setState(() {
      _enSections = _splitBySections(en);
      _hrSections = _splitBySections(hr);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: _accentGold, strokeWidth: 2),
        ),
      );
    }

    final sectionCount =
        _enSections.length > _hrSections.length ? _enSections.length : _hrSections.length;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: List.generate(sectionCount, (i) {
                  final enText = i < _enSections.length ? _enSections[i] : '';
                  final hrText = i < _hrSections.length ? _hrSections[i] : '';
                  return _SectionRow(
                    enContent: enText,
                    hrContent: hrText,
                    index: i,
                  );
                }),
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: _bgSurface,
        border: Border(bottom: BorderSide(color: _borderSubtle, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          // Logo / title area
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _accentGold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'DOMOVINA.tv',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    border: Border.all(color: _accentGoldMuted, width: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'RESEARCH DOSSIER',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _accentGold,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Column headers
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: _ColumnHeader(label: 'ENGLISH', flag: '🇬🇧'),
                ),
                const SizedBox(width: 48),
                Expanded(
                  child: _ColumnHeader(label: 'HRVATSKI', flag: '🇭🇷'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: const BoxDecoration(
        color: _bgSurface,
        border: Border(top: BorderSide(color: _borderSubtle, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Complete Research Dossier',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: _textSecondary.withValues(alpha: 0.5),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Column header widget ─────────────────────────────────────────────────────

class _ColumnHeader extends StatelessWidget {
  final String label;
  final String flag;
  const _ColumnHeader({required this.label, required this.flag});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(flag, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _textSecondary,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }
}

// ── Section row ──────────────────────────────────────────────────────────────

class _SectionRow extends StatelessWidget {
  final String enContent;
  final String hrContent;
  final int index;

  const _SectionRow({
    required this.enContent,
    required this.hrContent,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isEven = index.isEven;
    final bgColor = isEven ? _bgDeep : _bgSurfaceAlt;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(
          bottom: BorderSide(color: _borderFaint, width: 0.5),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left gutter with section number
            _SectionGutter(index: index),
            // English column
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 32, 28),
                child: _buildMarkdown(context, enContent),
              ),
            ),
            // Center divider
            Container(
              width: 1,
              color: _borderSubtle.withValues(alpha: 0.4),
            ),
            // Croatian column
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 28, 24, 28),
                child: _buildMarkdown(context, hrContent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdown(BuildContext context, String data) {
    final headingStyle = GoogleFonts.cormorantGaramond(
      color: _textPrimary,
      fontWeight: FontWeight.w700,
    );
    final bodyStyle = GoogleFonts.inter(
      fontSize: 13.5,
      height: 1.75,
      color: _textPrimary.withValues(alpha: 0.88),
    );

    return MarkdownBody(
      data: data,
      selectable: true,
      fitContent: false,
      styleSheet: MarkdownStyleSheet(
        h1: headingStyle.copyWith(fontSize: 26),
        h1Padding: const EdgeInsets.only(bottom: 12),
        h2: headingStyle.copyWith(fontSize: 22, color: _accentGold),
        h2Padding: const EdgeInsets.only(bottom: 10),
        h3: headingStyle.copyWith(fontSize: 17),
        h3Padding: const EdgeInsets.only(top: 8, bottom: 6),
        p: bodyStyle,
        pPadding: const EdgeInsets.only(bottom: 10),
        strong: bodyStyle.copyWith(
          fontWeight: FontWeight.w600,
          color: _textPrimary,
        ),
        em: bodyStyle.copyWith(fontStyle: FontStyle.italic),
        listBullet: bodyStyle.copyWith(color: _accentGold),
        listBulletPadding: const EdgeInsets.only(right: 8),
        listIndent: 20,
        blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        blockquoteDecoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: _accentGold, width: 2),
          ),
          color: Color(0xFF1a1816),
        ),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: _borderSubtle, width: 0.5),
          ),
        ),
        a: bodyStyle.copyWith(
          color: _accentGreen,
          decoration: TextDecoration.underline,
          decorationColor: _accentGreen.withValues(alpha: 0.4),
        ),
        tableHead: bodyStyle.copyWith(fontWeight: FontWeight.w600),
        tableBody: bodyStyle,
        tableBorder: TableBorder.all(color: _borderSubtle, width: 0.5),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

// ── Section gutter ───────────────────────────────────────────────────────────

class _SectionGutter extends StatelessWidget {
  final int index;
  const _SectionGutter({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _borderFaint, width: 0.5)),
      ),
      padding: const EdgeInsets.only(top: 28),
      alignment: Alignment.topCenter,
      child: Text(
        index == 0 ? '§' : '$index',
        style: GoogleFonts.cormorantGaramond(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _accentGoldMuted,
        ),
      ),
    );
  }
}
