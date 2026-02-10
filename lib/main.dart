import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Palette — clean light theme inspired by YouTube / GitHub ─────────────────
const _white = Color(0xFFFFFFFF);
const _bgPage = Color(0xFFF9F9F9); // YouTube light gray
const _bgSectionAlt = Color(0xFFFFFFFF);
const _bgHeader = Color(0xFFFFFFFF);
const _border = Color(0xFFE5E5E5);
const _borderLight = Color(0xFFF0F0F0);
const _textTitle = Color(0xFF0F0F0F); // YouTube title black
const _textBody = Color(0xFF1A1A1A);
const _textSecondary = Color(0xFF606060); // YouTube secondary
const _textMuted = Color(0xFF909090);
const _accent = Color(0xFF065FD4); // YouTube blue
const _accentSubtle = Color(0xFFE8F0FE);
const _errorRed = Color(0xFFCC0000);

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
        brightness: Brightness.light,
        scaffoldBackgroundColor: _bgPage,
        colorScheme: const ColorScheme.light(
          surface: _white,
          primary: _accent,
          outline: _border,
        ),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

// ── App shell ────────────────────────────────────────────────────────────────

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

// ── Decryption ───────────────────────────────────────────────────────────────

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
    final keyboardUp = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _bgPage,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Visibility keeps widgets in tree (no focus loss)
                // but collapses their space when keyboard is up
                Visibility(
                  visible: !keyboardUp,
                  maintainState: true,
                  maintainAnimation: true,
                  child: Column(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 48, color: _textMuted),
                      const SizedBox(height: 24),
                      Text(
                        'DOMOVINA.tv',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _textTitle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Research Dossier',
                        style: GoogleFonts.inter(fontSize: 14, color: _textSecondary),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
                    Container(
                      width: 380,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: _white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter access key',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _textTitle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'This document is encrypted. Enter the key to view.',
                            style: GoogleFonts.inter(fontSize: 13, color: _textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            obscureText: _obscure,
                            onSubmitted: (_) => _submit(),
                            style: GoogleFonts.inter(fontSize: 14, color: _textBody),
                            decoration: InputDecoration(
                              hintText: 'Access key',
                              hintStyle: GoogleFonts.inter(fontSize: 14, color: _textMuted),
                              filled: true,
                              fillColor: _bgPage,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: _error != null ? _errorRed : _border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: _error != null ? _errorRed : _border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _accent, width: 2),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20,
                                  color: _textMuted,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: _errorRed)),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: _accent,
                                disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: _white),
                                    )
                                  : Text(
                                      'Unlock',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Visibility(
                      visible: !keyboardUp,
                      maintainState: true,
                      maintainAnimation: true,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          'AES-256 encrypted  \u00b7  Decrypted in your browser',
                          style: GoogleFonts.inter(fontSize: 11, color: _textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
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
  if (buffer.isNotEmpty) sections.add(buffer.toString().trim());
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
  late final List<String> _sectionTitles;
  late final List<GlobalKey> _sectionKeys;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _enSections = _splitBySections(widget.enMarkdown);
    _hrSections = _splitBySections(widget.hrMarkdown);
    _sectionKeys = List.generate(
      _enSections.length > _hrSections.length ? _enSections.length : _hrSections.length,
      (_) => GlobalKey(),
    );
    _sectionTitles = _enSections.map((s) {
      final match = RegExp(r'^## (.+)$', multiLine: true).firstMatch(s);
      if (match != null) return match.group(1)!;
      final h1 = RegExp(r'^# (.+)$', multiLine: true).firstMatch(s);
      return h1 != null ? h1.group(1)! : 'Introduction';
    }).toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(int index) {
    final key = _sectionKeys[index];
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionCount = _sectionKeys.length;

    return Scaffold(
      backgroundColor: _bgPage,
      body: SafeArea(
        bottom: false,
        child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: List.generate(sectionCount, (i) {
                  return _SectionRow(
                    key: _sectionKeys[i],
                    enContent: i < _enSections.length ? _enSections[i] : '',
                    hrContent: i < _hrSections.length ? _hrSections[i] : '',
                    index: i,
                  );
                }),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: _bgHeader,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Text(
            'DOMOVINA.tv',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textTitle,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _accentSubtle,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Research Dossier',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _accent,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Chapter jump dropdown
          Container(
            height: 32,
            padding: const EdgeInsets.only(left: 12, right: 4),
            decoration: BoxDecoration(
              color: _bgPage,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: null,
                hint: Text(
                  'Jump to section...',
                  style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                ),
                icon: const Icon(Icons.unfold_more, size: 16, color: _textSecondary),
                isDense: true,
                style: GoogleFonts.inter(fontSize: 12, color: _textBody),
                items: List.generate(_sectionTitles.length, (i) {
                  return DropdownMenuItem(
                    value: i,
                    child: Text(
                      i == 0 ? _sectionTitles[i] : '${i}. ${_sectionTitles[i]}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
                onChanged: (i) {
                  if (i != null) _scrollToSection(i);
                },
              ),
            ),
          ),
          const Spacer(),
          Text('English', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary)),
          const SizedBox(width: 8),
          Container(width: 1, height: 16, color: _border),
          const SizedBox(width: 8),
          Text('Hrvatski', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary)),
        ],
      ),
    );
  }
}

// ── Section row ──────────────────────────────────────────────────────────────

class _SectionRow extends StatelessWidget {
  final String enContent;
  final String hrContent;
  final int index;

  const _SectionRow({
    super.key,
    required this.enContent,
    required this.hrContent,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final bg = index.isEven ? _bgPage : _bgSectionAlt;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(bottom: BorderSide(color: _borderLight, width: 1)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 24, 32),
                child: _md(context, enContent),
              ),
            ),
            Container(width: 1, color: _border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 32, 32),
                child: _md(context, hrContent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Claude Desktop / GitHub-quality markdown ────────────────────────────

  Widget _md(BuildContext context, String data) {
    // Body text — optimised for long-form reading
    final body = GoogleFonts.inter(
      fontSize: 15,
      height: 1.8,
      color: _textBody,
    );

    return MarkdownBody(
      data: data,
      selectable: true,
      fitContent: false,
      styleSheet: MarkdownStyleSheet(
        // ── Headings ─────────────────────────────────────────────────
        // h1: document title — large, bold, breathing room below
        h1: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: _textTitle,
          height: 1.3,
        ),
        h1Padding: const EdgeInsets.only(bottom: 16),

        // h2: part/section — clear separator with top space
        h2: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _textTitle,
          height: 1.35,
        ),
        h2Padding: const EdgeInsets.only(bottom: 12),

        // h3: subsection — medium weight, extra top gap to separate from previous block
        h3: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _textTitle,
          height: 1.4,
        ),
        h3Padding: const EdgeInsets.only(top: 24, bottom: 8),

        // ── Body ─────────────────────────────────────────────────────
        p: body,
        pPadding: const EdgeInsets.only(bottom: 16),

        strong: body.copyWith(fontWeight: FontWeight.w600, color: _textTitle),
        em: body.copyWith(fontStyle: FontStyle.italic),

        // ── Lists — generous spacing like Claude Desktop ─────────────
        listBullet: body.copyWith(color: _textSecondary),
        listBulletPadding: const EdgeInsets.only(top: 1, right: 8),
        listIndent: 24,

        // ── Blockquotes ──────────────────────────────────────────────
        blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: _border, width: 3)),
          color: Color(0xFFF6F6F6),
        ),

        // ── Horizontal rules — subtle like GitHub ────────────────────
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _border, width: 1)),
        ),

        // ── Links ────────────────────────────────────────────────────
        a: body.copyWith(color: _accent, decoration: TextDecoration.none),

        // ── Tables ───────────────────────────────────────────────────
        tableHead: body.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
        tableBody: body.copyWith(fontSize: 13),
        tableBorder: TableBorder.all(color: _border, width: 1),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

        // ── Code ─────────────────────────────────────────────────────
        code: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: _textBody,
          backgroundColor: const Color(0xFFF0F0F0),
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _border),
        ),
        codeblockPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
