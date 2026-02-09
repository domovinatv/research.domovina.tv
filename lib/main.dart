import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const _bgDeep = Color(0xFF0c0a09);
const _bgSurface = Color(0xFF1c1917);
const _bgSurfaceAlt = Color(0xFF171412);
const _bgCard = Color(0xFF292524);
const _borderSubtle = Color(0xFF44403c);
const _borderFaint = Color(0xFF292524);
const _textPrimary = Color(0xFFfafaf9);
const _textSecondary = Color(0xFFa8a29e);
const _accentGold = Color(0xFFd4a24e);
const _accentGoldMuted = Color(0xFF8b6914);
const _accentGreen = Color(0xFF16a34a);
const _errorRed = Color(0xFFef4444);

const _marker = 'MHS_OK:';

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
      home: const AppShell(),
    );
  }
}

// ── App shell — routes between unlock and viewer ─────────────────────────────

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _enContent;
  String? _hrContent;

  void _onUnlocked(String en, String hr) {
    setState(() {
      _enContent = en;
      _hrContent = hr;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_enContent != null && _hrContent != null) {
      return DualMarkdownViewer(enMarkdown: _enContent!, hrMarkdown: _hrContent!);
    }
    return UnlockScreen(onUnlocked: _onUnlocked);
  }
}

// ── Decryption helper ────────────────────────────────────────────────────────

String? _decryptAsset(String base64Data, String passphrase) {
  try {
    final keyBytes = sha256.convert(utf8.encode(passphrase)).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));
    final raw = base64.decode(base64Data);
    final iv = enc.IV(Uint8List.fromList(raw.sublist(0, 16)));
    final encrypted = enc.Encrypted(Uint8List.fromList(raw.sublist(16)));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decrypt(encrypted, iv: iv);
    if (!decrypted.startsWith(_marker)) return null;
    return decrypted.substring(_marker.length);
  } catch (_) {
    return null;
  }
}

// ── Unlock screen ────────────────────────────────────────────────────────────

class UnlockScreen extends StatefulWidget {
  final void Function(String en, String hr) onUnlocked;
  const UnlockScreen({super.key, required this.onUnlocked});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final passphrase = _controller.text.trim();
    if (passphrase.isEmpty) {
      setState(() => _error = 'Please enter the access key');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // Small delay so spinner shows
    await Future.delayed(const Duration(milliseconds: 100));

    final enRaw = await rootBundle.loadString('assets/mhs-001.en.enc');
    final hrRaw = await rootBundle.loadString('assets/mhs-001.hr.enc');

    final en = _decryptAsset(enRaw, passphrase);
    final hr = _decryptAsset(hrRaw, passphrase);

    if (en != null && hr != null) {
      widget.onUnlocked(en, hr);
    } else {
      setState(() {
        _loading = false;
        _error = 'Invalid access key';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gold bar
                Container(
                  width: 48,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _accentGold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  'DOMOVINA.tv',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'RESEARCH DOSSIER',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _accentGold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 48),
                // Card
                Container(
                  width: 400,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: _bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderSubtle, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_outline, size: 18, color: _textSecondary),
                          const SizedBox(width: 10),
                          Text(
                            'Encrypted Document',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the access key to decrypt and view this document.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Input
                      Container(
                        decoration: BoxDecoration(
                          color: _bgDeep,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _error != null ? _errorRed : _borderSubtle,
                            width: 0.5,
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          obscureText: _obscure,
                          onSubmitted: (_) => _submit(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Access key',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 14,
                              color: _textSecondary.withValues(alpha: 0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 18,
                                color: _textSecondary,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                      ),
                      // Error
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: GoogleFonts.inter(fontSize: 12, color: _errorRed),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentGold,
                            foregroundColor: _bgDeep,
                            disabledBackgroundColor: _accentGoldMuted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _bgDeep,
                                  ),
                                )
                              : Text(
                                  'Unlock Document',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Subtle footer
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: _textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(width: 6),
                    Text(
                      'AES-256 encrypted  ·  Decrypted in your browser only',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _textSecondary.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

// ── Dual markdown viewer ─────────────────────────────────────────────────────

class DualMarkdownViewer extends StatefulWidget {
  final String enMarkdown;
  final String hrMarkdown;
  const DualMarkdownViewer({super.key, required this.enMarkdown, required this.hrMarkdown});

  @override
  State<DualMarkdownViewer> createState() => _DualMarkdownViewerState();
}

class _DualMarkdownViewerState extends State<DualMarkdownViewer> {
  late final List<String> _enSections;
  late final List<String> _hrSections;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _enSections = _splitBySections(widget.enMarkdown);
    _hrSections = _splitBySections(widget.hrMarkdown);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Expanded(child: _ColumnHeader(label: 'ENGLISH', flag: '🇬🇧')),
                const SizedBox(width: 48),
                const Expanded(child: _ColumnHeader(label: 'HRVATSKI', flag: '🇭🇷')),
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

// ── Column header ────────────────────────────────────────────────────────────

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
        border: const Border(bottom: BorderSide(color: _borderFaint, width: 0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionGutter(index: index),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 32, 28),
                child: _buildMarkdown(context, enContent),
              ),
            ),
            Container(width: 1, color: _borderSubtle.withValues(alpha: 0.4)),
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
        strong: bodyStyle.copyWith(fontWeight: FontWeight.w600, color: _textPrimary),
        em: bodyStyle.copyWith(fontStyle: FontStyle.italic),
        listBullet: bodyStyle.copyWith(color: _accentGold),
        listBulletPadding: const EdgeInsets.only(right: 8),
        listIndent: 20,
        blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _accentGold, width: 2)),
          color: Color(0xFF1a1816),
        ),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _borderSubtle, width: 0.5)),
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
