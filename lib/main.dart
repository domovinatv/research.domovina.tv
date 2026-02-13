import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import 'url_helper.dart' if (dart.library.js_interop) 'url_helper_web.dart';

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

void main() => runApp(const DomovinaResearchApp());

class DomovinaResearchApp extends StatelessWidget {
  const DomovinaResearchApp({super.key});

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
  // URL-provided initial toggle preferences (null = default/both)
  String? _initialLang;
  String? _initialSection;

  void _onUnlocked(String en, String hr, {String? lang, String? section}) {
    setState(() {
      _enContent = en;
      _hrContent = hr;
      _initialLang = lang;
      _initialSection = section;
    });
  }

  void _onLogout() {
    setState(() {
      _enContent = null;
      _hrContent = null;
      _initialLang = null;
      _initialSection = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_enContent != null && _hrContent != null) {
      return DualMarkdownViewer(
        enMarkdown: _enContent!,
        hrMarkdown: _hrContent!,
        onLogout: _onLogout,
        initialLang: _initialLang,
        initialSection: _initialSection,
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
  final void Function(String en, String hr, {String? lang, String? section}) onUnlocked;
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
  // Stashed URL params to pass through on unlock
  String? _urlLang;
  String? _urlSection;

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
    _urlLang = uri.queryParameters['lang'];
    _urlSection = uri.queryParameters['section'];
    if (doc != null && doc.isNotEmpty) _docIdController.text = doc;
    if (key != null && key.isNotEmpty) _controller.text = key;

    // Clear URL params after reading so logout doesn't re-trigger auto-submit
    clearUrlParams();

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
        widget.onUnlocked(en, hr, lang: _urlLang, section: _urlSection);
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
                            autocorrect: false,
                            enableSuggestions: false,
                            textCapitalization: TextCapitalization.none,
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
  final String? initialLang; // 'en', 'hr', or null (both)
  final String? initialSection; // 'research', 'podcast', or null (both)
  const DualMarkdownViewer({super.key, required this.enMarkdown, required this.hrMarkdown, this.onLogout, this.initialLang, this.initialSection});

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

  // EN/HR column visibility (at least one must always be true)
  bool _showEn = true;
  bool _showHr = true;

  // RESEARCH / PODCAST FLOW section visibility
  // _podcastFlowStartIndex = first section index that belongs to podcast flow
  // (-1 means no split detected → toggles hidden, show everything)
  int _podcastFlowStartIndex = -1;
  bool _showResearch = true;
  bool _showPodcast = true;

  void _toggleEn() {
    setState(() {
      if (_showEn && !_showHr) return; // can't turn off last one
      _showEn = !_showEn;
      if (!_showEn && !_showHr) _showHr = true;
    });
  }

  void _toggleHr() {
    setState(() {
      if (_showHr && !_showEn) return; // can't turn off last one
      _showHr = !_showHr;
      if (!_showEn && !_showHr) _showEn = true;
    });
  }

  void _toggleResearch() {
    setState(() {
      if (_showResearch && !_showPodcast) return;
      _showResearch = !_showResearch;
      if (!_showResearch && !_showPodcast) _showPodcast = true;
    });
    _ensureVisibleSection();
  }

  void _togglePodcast() {
    setState(() {
      if (_showPodcast && !_showResearch) return;
      _showPodcast = !_showPodcast;
      if (!_showResearch && !_showPodcast) _showResearch = true;
    });
    _ensureVisibleSection();
  }

  bool _isSectionVisible(int i) {
    if (_podcastFlowStartIndex < 0) return true; // no split → all visible
    if (i < _podcastFlowStartIndex) return _showResearch;
    return _showPodcast;
  }

  void _ensureVisibleSection() {
    if (_isSectionVisible(_currentSectionIndex)) return;
    // Current section hidden — jump to first visible one
    for (int i = 0; i < _sectionKeys.length; i++) {
      if (_isSectionVisible(i)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToSection(i);
        });
        return;
      }
    }
  }

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

    // Detect podcast flow boundary: "## BLOCK 1" (EN) or "## BLOK 1" (HR)
    final blockPattern = RegExp(r'^## BLOC?K 1\b', caseSensitive: false);
    for (int i = 1; i < count; i++) {
      final en = i < _enSections.length ? _enSections[i] : '';
      final hr = i < _hrSections.length ? _hrSections[i] : '';
      if (blockPattern.hasMatch(en) || blockPattern.hasMatch(hr)) {
        _podcastFlowStartIndex = i;
        break;
      }
    }

    // Apply URL-provided initial toggle preferences
    final lang = widget.initialLang?.toLowerCase();
    if (lang == 'en') {
      _showEn = true;
      _showHr = false;
    } else if (lang == 'hr') {
      _showEn = false;
      _showHr = true;
    }
    final section = widget.initialSection?.toLowerCase();
    if (section == 'research' && _podcastFlowStartIndex > 0) {
      _showResearch = true;
      _showPodcast = false;
    } else if (section == 'podcast' && _podcastFlowStartIndex > 0) {
      _showResearch = false;
      _showPodcast = true;
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
            if (_currentSectionIndex > 0 && _enH2[_currentSectionIndex] != null && _isSectionVisible(_currentSectionIndex))
              _buildH2Bar(),
            Expanded(
              child: SingleChildScrollView(
                key: _scrollViewKey,
                controller: _scrollController,
                child: Column(
                  children: [
                    for (int i = 0; i < sectionCount; i++)
                      if ((_enStripped[i].isNotEmpty || _hrStripped[i].isNotEmpty) && _isSectionVisible(i))
                        _SectionRow(
                          key: _sectionKeys[i],
                          enContent: _enStripped[i],
                          hrContent: _hrStripped[i],
                          index: i,
                          showEn: _showEn,
                          showHr: _showHr,
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

  Widget _buildLangToggle(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? _accent : _border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? _white : _textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildChapterDropdown() {
    // Only show visible sections in dropdown
    final visibleItems = <DropdownMenuItem<int>>[];
    int? dropdownValue;
    for (int i = 0; i < _sectionTitles.length; i++) {
      if (!_isSectionVisible(i)) continue;
      visibleItems.add(DropdownMenuItem(
        value: i,
        child: Text(
          i == 0 ? _sectionTitles[i] : '${i}. ${_sectionTitles[i]}',
          overflow: TextOverflow.ellipsis,
        ),
      ));
      // Pick closest visible section as dropdown value
      if (dropdownValue == null || (i <= _currentSectionIndex && _isSectionVisible(i))) {
        dropdownValue = i;
      }
    }

    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: _bgPage,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: dropdownValue,
          icon: const Icon(Icons.unfold_more, size: 16, color: _textSecondary),
          isDense: true,
          isExpanded: true,
          style: GoogleFonts.inter(fontSize: 12, color: _textBody),
          items: visibleItems,
          onChanged: (i) {
            if (i != null) _scrollToSection(i);
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 600;

      final brand = Row(
        mainAxisSize: MainAxisSize.min,
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
        ],
      );

      final langToggles = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLangToggle('EN', _showEn, _toggleEn),
          const SizedBox(width: 4),
          _buildLangToggle('HR', _showHr, _toggleHr),
        ],
      );

      final sectionToggles = _podcastFlowStartIndex > 0
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLangToggle('Research', _showResearch, _toggleResearch),
                const SizedBox(width: 4),
                _buildLangToggle('Podcast', _showPodcast, _togglePodcast),
              ],
            )
          : null;

      final logout = widget.onLogout != null
          ? IconButton(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded, size: 18, color: _textSecondary),
              tooltip: 'Switch document',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            )
          : const SizedBox.shrink();

      if (narrow) {
        return Container(
          decoration: const BoxDecoration(
            color: _bgHeader,
            border: Border(bottom: BorderSide(color: _border, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  brand,
                  const Spacer(),
                  langToggles,
                  const SizedBox(width: 8),
                  logout,
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildChapterDropdown()),
                  if (sectionToggles != null) ...[
                    const SizedBox(width: 8),
                    sectionToggles,
                  ],
                ],
              ),
            ],
          ),
        );
      }

      return Container(
        decoration: const BoxDecoration(
          color: _bgHeader,
          border: Border(bottom: BorderSide(color: _border, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            brand,
            const SizedBox(width: 16),
            Flexible(child: _buildChapterDropdown()),
            if (sectionToggles != null) ...[
              const SizedBox(width: 8),
              sectionToggles,
            ],
            const SizedBox(width: 8),
            langToggles,
            if (widget.onLogout != null) ...[
              const SizedBox(width: 16),
              logout,
            ],
          ],
        ),
      );
    });
  }

  Widget _buildH2Bar() {
    final h2Style = GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: _textTitle,
    );
    final bothVisible = _showEn && _showHr;

    return Container(
      decoration: BoxDecoration(
        color: _bgHeader,
        border: const Border(bottom: BorderSide(color: _border, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: bothVisible
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(_enH2[_currentSectionIndex] ?? '', style: h2Style, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  Container(width: 1, color: _border),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(_hrH2[_currentSectionIndex] ?? '', style: h2Style, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                (_showEn ? _enH2[_currentSectionIndex] : _hrH2[_currentSectionIndex]) ?? '',
                style: h2Style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
    );
  }

  Widget _buildH1Bar() {
    final h1Style = GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: _textTitle,
      height: 1.3,
    );
    final bothVisible = _showEn && _showHr;

    return Container(
      decoration: const BoxDecoration(
        color: _bgHeader,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: bothVisible
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(_enH1 ?? '', style: h1Style),
                    ),
                  ),
                  Container(width: 1, color: _border),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(_hrH1 ?? '', style: h1Style),
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                (_showEn ? _enH1 : _hrH1) ?? '',
                style: h1Style,
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
  final bool showEn;
  final bool showHr;

  const _SectionRow({
    super.key,
    required this.enContent,
    required this.hrContent,
    required this.index,
    required this.showEn,
    required this.showHr,
  });

  @override
  Widget build(BuildContext context) {
    final bg = index.isEven ? _bgPage : _bgSectionAlt;
    final bothVisible = showEn && showHr;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(bottom: BorderSide(color: _borderLight, width: 1)),
      ),
      child: bothVisible
          ? IntrinsicHeight(
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
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
              child: _md(context, showEn ? enContent : hrContent),
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
