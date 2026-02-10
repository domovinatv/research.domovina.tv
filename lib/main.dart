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
      title: 'Research — DOMOVINA.tv',
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

  void _onLogout() {
    setState(() {
      _enContent = null;
      _hrContent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_enContent != null && _hrContent != null) {
      return DualMarkdownViewer(
        enMarkdown: _enContent!,
        hrMarkdown: _hrContent!,
        onLogout: _onLogout,
      );
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
  final _docIdController = TextEditingController();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _formKey = GlobalKey();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _readUrlParams();
  }

  void _readUrlParams() {
    final uri = Uri.base;
    final doc = uri.queryParameters['doc'];
    final key = uri.queryParameters['key'];
    if (doc != null && doc.isNotEmpty) _docIdController.text = doc;
    if (key != null && key.isNotEmpty) _controller.text = key;

    // Auto-submit if both params provided
    if (doc != null && doc.isNotEmpty && key != null && key.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _submit();
      });
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus || !mounted) return;
    // After keyboard appears and Visibility collapses the header,
    // the scroll position may be stale (especially on web/iPad Safari
    // where the browser scrolls before Flutter re-layouts).
    // Wait for the layout to settle, then scroll the form into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        final ctx = _formKey.currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
      });
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _docIdController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final docId = _docIdController.text.trim();
    final passphrase = _controller.text.trim();
    if (docId.isEmpty) {
      setState(() => _error = 'Please enter the document ID');
      return;
    }
    if (passphrase.isEmpty) {
      setState(() => _error = 'Please enter the access key');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final enRaw = await rootBundle.loadString('assets/$docId.en.enc');
      final hrRaw = await rootBundle.loadString('assets/$docId.hr.enc');
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
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Document "$docId" not found';
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
                        'Research',
                        style: GoogleFonts.inter(fontSize: 14, color: _textSecondary),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
                    Container(
                      key: _formKey,
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
                            'This document is encrypted. Enter the document ID and key to view.',
                            style: GoogleFonts.inter(fontSize: 13, color: _textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _docIdController,
                            onSubmitted: (_) => _focusNode.requestFocus(),
                            style: GoogleFonts.inter(fontSize: 14, color: _textBody),
                            decoration: InputDecoration(
                              hintText: 'Document ID',
                              hintStyle: GoogleFonts.inter(fontSize: 14, color: _textMuted),
                              filled: true,
                              fillColor: _bgPage,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _accent, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
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

// ── Heading helpers ──────────────────────────────────────────────────────────

String? _extractH1(String markdown) {
  final match = RegExp(r'^# (.+)$', multiLine: true).firstMatch(markdown);
  return match?.group(1);
}

String? _extractH2(String markdown) {
  final match = RegExp(r'^## (.+)$', multiLine: true).firstMatch(markdown);
  return match?.group(1);
}

String _stripH1(String markdown) {
  return markdown.replaceFirst(RegExp(r'^# .+\n?', multiLine: true), '').trim();
}

// ── Dual markdown viewer ─────────────────────────────────────────────────────

class DualMarkdownViewer extends StatefulWidget {
  final String enMarkdown;
  final String hrMarkdown;
  final VoidCallback? onLogout;
  const DualMarkdownViewer({super.key, required this.enMarkdown, required this.hrMarkdown, this.onLogout});

  @override
  State<DualMarkdownViewer> createState() => _DualMarkdownViewerState();
}

class _DualMarkdownViewerState extends State<DualMarkdownViewer> {
  late final List<String> _enSections;
  late final List<String> _hrSections;
  late final List<String> _sectionTitles;
  late final List<GlobalKey> _sectionKeys;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewKey = GlobalKey();
  int _currentSectionIndex = 0;

  // Fixed H1 title (from first section)
  String? _enH1;
  String? _hrH1;

  // Per-section stripped content and H2 titles
  late final List<String> _enStripped;
  late final List<String> _hrStripped;
  late final List<String?> _enH2;
  late final List<String?> _hrH2;

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

    // Extract H1 from first section
    if (_enSections.isNotEmpty) _enH1 = _extractH1(_enSections[0]);
    if (_hrSections.isNotEmpty) _hrH1 = _extractH1(_hrSections[0]);

    // Build stripped sections and H2 titles
    final count = _sectionKeys.length;
    _enStripped = List<String>.filled(count, '');
    _hrStripped = List<String>.filled(count, '');
    _enH2 = List<String?>.filled(count, null);
    _hrH2 = List<String?>.filled(count, null);

    for (int i = 0; i < count; i++) {
      final en = i < _enSections.length ? _enSections[i] : '';
      final hr = i < _hrSections.length ? _hrSections[i] : '';
      if (i == 0) {
        _enStripped[i] = _stripH1(en);
        _hrStripped[i] = _stripH1(hr);
      } else {
        _enH2[i] = _extractH2(en);
        _hrH2[i] = _extractH2(hr);
        _enStripped[i] = en;
        _hrStripped[i] = hr;
      }
    }

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrollCtx = _scrollViewKey.currentContext;
    if (scrollCtx == null) return;
    final scrollBox = scrollCtx.findRenderObject() as RenderBox;
    final scrollTop = scrollBox.localToGlobal(Offset.zero).dy;

    int newIndex = 0;
    for (int i = _sectionKeys.length - 1; i >= 0; i--) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox;
      final sectionTop = box.localToGlobal(Offset.zero).dy;
      if (sectionTop <= scrollTop + 10) {
        newIndex = i;
        break;
      }
    }
    if (newIndex != _currentSectionIndex) {
      setState(() => _currentSectionIndex = newIndex);
    }
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
            if (_enH1 != null || _hrH1 != null) _buildH1Bar(),
            if (_currentSectionIndex > 0 && _enH2[_currentSectionIndex] != null)
              _buildH2Bar(),
            Expanded(
              child: SingleChildScrollView(
                key: _scrollViewKey,
                controller: _scrollController,
                child: Column(
                  children: [
                    for (int i = 0; i < sectionCount; i++)
                      if (_enStripped[i].isNotEmpty || _hrStripped[i].isNotEmpty)
                        _SectionRow(
                          key: _sectionKeys[i],
                          enContent: _enStripped[i],
                          hrContent: _hrStripped[i],
                          index: i,
                        ),
                  ],
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
              'Research',
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
                value: _currentSectionIndex,
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
          if (widget.onLogout != null) ...[
            const SizedBox(width: 16),
            IconButton(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded, size: 18, color: _textSecondary),
              tooltip: 'Switch document',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildH2Bar() {
    return Container(
      decoration: BoxDecoration(
        color: _bgHeader,
        border: const Border(bottom: BorderSide(color: _border, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _enH2[_currentSectionIndex] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textTitle,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Container(width: 1, color: _border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _hrH2[_currentSectionIndex] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textTitle,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildH1Bar() {
    return Container(
      decoration: const BoxDecoration(
        color: _bgHeader,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _enH1 ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textTitle,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            Container(width: 1, color: _border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _hrH1 ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textTitle,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
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
