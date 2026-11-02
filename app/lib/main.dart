import 'package:flutter/material.dart';

import 'src/repositories/repository_service.dart';
import 'src/rust/api.dart' as rust_api;
import 'src/symbols/symbol_index_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CodexisApp());
}

class CodexisApp extends StatelessWidget {
  const CodexisApp({
    super.key,
    this.repositoryService,
    this.symbolIndexService,
  });

  final RepositoryService? repositoryService;
  final SymbolIndexService? symbolIndexService;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Codexis',
    debugShowCheckedModeBanner: false,
    theme: _buildTheme(),
    home: HomeScreen(
      service: repositoryService ?? AndroidRepositoryService(),
      symbolIndexService: symbolIndexService ?? RustSymbolIndexService(),
    ),
  );

  ThemeData _buildTheme() {
    const ink = Color(0xFF101B1A);
    const canvas = Color(0xFFF3F6F3);
    const teal = Color(0xFF087F72);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        surface: canvas,
        primary: teal,
        secondary: const Color(0xFFB45C40),
        onSurface: ink,
      ),
      scaffoldBackgroundColor: canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE0E7E1)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE4DE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE4DE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: teal, width: 1.5),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.service,
    required this.symbolIndexService,
  });

  final RepositoryService service;
  final SymbolIndexService symbolIndexService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<LocalRepository> _repositories = const [];
  bool _loading = true;
  bool _importing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repositories = await widget.service.listRepositories();
      if (!mounted) return;
      setState(() => _repositories = repositories);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importRepository() async {
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final repository = await widget.service.pickAndImportRepository();
      if (repository == null || !mounted) return;
      await _reload();
      if (!mounted) return;
      await _openRepository(repository);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openRepository(LocalRepository repository) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RepositoryScreen(
          service: widget.service,
          symbolIndexService: widget.symbolIndexService,
          repository: repository,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _removeRepository(LocalRepository repository) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove local copy?'),
        content: Text(
          'Remove ${repository.name} and its imported app copy? The original folder is not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove copy'),
          ),
        ],
      ),
    );
    if (remove != true) return;
    try {
      await widget.service.removeRepository(repository.id);
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const _BrandLockup(),
        actions: [
          IconButton(
            tooltip: 'Refresh repositories',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _WelcomeCard(onImport: _importRepository, importing: _importing),
              const SizedBox(height: 16),
              const _CapabilityNotice(),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _ErrorPanel(message: _error!, onRetry: _reload),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your workspaces',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  if (_repositories.isNotEmpty)
                    Text(
                      '${_repositories.length} local',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading && _repositories.isEmpty)
                const _LoadingPanel()
              else if (_repositories.isEmpty)
                _EmptyRepositories(onImport: _importRepository)
              else
                ..._repositories.map(
                  (repository) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RepositoryCard(
                      repository: repository,
                      onTap: () => _openRepository(repository),
                      onRemove: () => _removeRepository(repository),
                    ),
                  ),
                ),
              if (_repositories.isNotEmpty) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _importing ? null : _importRepository,
                  icon: _importing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('Import another repository'),
                ),
              ],
              const SizedBox(height: 26),
              const _PrivacyFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class RepositoryScreen extends StatefulWidget {
  const RepositoryScreen({
    super.key,
    required this.service,
    required this.symbolIndexService,
    required this.repository,
  });

  final RepositoryService service;
  final SymbolIndexService symbolIndexService;
  final LocalRepository repository;

  @override
  State<RepositoryScreen> createState() => _RepositoryScreenState();
}

class _RepositoryScreenState extends State<RepositoryScreen> {
  List<RepositoryFile> _files = const [];
  List<rust_api.IndexedSymbol> _symbols = const [];
  late String _currentPath = widget.repository.path;
  bool _loading = true;
  bool _indexing = false;
  bool _symbolsIndexed = false;
  bool _showSymbols = false;
  String? _error;
  String? _indexError;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await widget.service.listFiles(
        widget.repository,
        directoryPath: _currentPath,
      );
      if (!mounted) return;
      setState(() => _files = files);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _indexRepository() async {
    setState(() {
      _indexing = true;
      _indexError = null;
    });
    try {
      final symbols = await widget.symbolIndexService.indexRepository(
        widget.repository.path,
      );
      if (!mounted) return;
      setState(() {
        _symbols = symbols;
        _symbolsIndexed = true;
        _showSymbols = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _indexError = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _indexing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleFiles = _files.where((file) {
      final searchable = '${file.name} ${file.path}'.toLowerCase();
      return searchable.contains(_query.toLowerCase());
    }).toList();
    final visibleSymbols = _symbols.where((symbol) {
      final searchable =
          '${symbol.name} ${symbol.kind} ${symbol.language} ${symbol.relativePath}'
              .toLowerCase();
      return searchable.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: _currentPath == widget.repository.path
            ? null
            : IconButton(
                tooltip: 'Parent folder',
                onPressed: _openParent,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
        title: Text(
          _currentPath == widget.repository.path
              ? widget.repository.name
              : _currentPath.split('/').where((part) => part.isNotEmpty).last,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh files',
            onPressed: _loading ? null : _loadFiles,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _WorkspaceTrustCard(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment<bool>(
                              value: false,
                              icon: Icon(Icons.folder_outlined),
                              label: Text('Files'),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              icon: Icon(Icons.account_tree_outlined),
                              label: Text('Symbols'),
                            ),
                          ],
                          selected: {_showSymbols},
                          onSelectionChanged: (selection) =>
                              setState(() => _showSymbols = selection.single),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: _symbolsIndexed
                            ? 'Rebuild static symbol index'
                            : 'Index repository symbols',
                        onPressed: _indexing ? null : _indexRepository,
                        icon: _indexing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.account_tree_rounded),
                      ),
                    ],
                  ),
                  if (_showSymbols) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Tree-sitter static symbols · not semantic LSP results',
                      style: TextStyle(color: Color(0xFF63746E), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() => _query = value.trim()),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search names and paths',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _showSymbols
                  ? _buildSymbolsList(visibleSymbols)
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _ErrorPanel(
                          message: _error!,
                          onRetry: _loadFiles,
                        ),
                      ),
                    )
                  : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visibleFiles.isEmpty
                  ? Center(
                      child: Text(
                        _query.isEmpty
                            ? 'No supported source files found.'
                            : 'No files match “$_query”.',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 2, 18, 24),
                      itemCount: visibleFiles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final file = visibleFiles[index];
                        return _FileRow(
                          file: file,
                          onTap: file.isDirectory
                              ? () => _openDirectory(file)
                              : () => _openFile(context, file),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymbolsList(List<rust_api.IndexedSymbol> symbols) {
    if (_indexing && !_symbolsIndexed) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_indexError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _ErrorPanel(message: _indexError!, onRetry: _indexRepository),
        ),
      );
    }
    if (!_symbolsIndexed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_tree_outlined,
                size: 34,
                color: Color(0xFF087F72),
              ),
              const SizedBox(height: 10),
              Text(
                'Build a local symbol index',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Parse Rust and NASM source locally to list declarations and their locations. This is syntax indexing, not semantic navigation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF596863), height: 1.45),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _indexing ? null : _indexRepository,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Index symbols'),
              ),
            ],
          ),
        ),
      );
    }
    if (symbols.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty
              ? 'No Rust or NASM declarations found.'
              : 'No symbols match “$_query”.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      itemCount: symbols.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final symbol = symbols[index];
        return _SymbolRow(symbol: symbol, onTap: () => _openSymbol(symbol));
      },
    );
  }

  Future<void> _openSymbol(rust_api.IndexedSymbol symbol) async {
    final path = '${widget.repository.path}/${symbol.relativePath}';
    final separator = path.lastIndexOf('/');
    final file = RepositoryFile(
      path: path,
      name: path.substring(separator + 1),
      isDirectory: false,
      size: 0,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CodeScreen(
          service: widget.service,
          file: file,
          initialLine: symbol.startLine,
          selectedSymbol: symbol.name,
        ),
      ),
    );
  }

  Future<void> _openFile(BuildContext context, RepositoryFile file) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CodeScreen(service: widget.service, file: file),
      ),
    );
  }

  void _openDirectory(RepositoryFile directory) {
    setState(() => _currentPath = directory.path);
    _loadFiles();
  }

  void _openParent() {
    final parent = _currentPath.substring(0, _currentPath.lastIndexOf('/'));
    if (parent.length < widget.repository.path.length) return;
    setState(() => _currentPath = parent);
    _loadFiles();
  }
}

class CodeScreen extends StatefulWidget {
  const CodeScreen({
    super.key,
    required this.service,
    required this.file,
    this.initialLine,
    this.selectedSymbol,
  });

  final RepositoryService service;
  final RepositoryFile file;
  final int? initialLine;
  final String? selectedSymbol;

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  late final Future<String> _contents = widget.service.readFile(widget.file);
  late final ScrollController _verticalScrollController = ScrollController(
    initialScrollOffset: widget.initialLine == null
        ? 0
        : (widget.initialLine! - 1) * 20.15,
  );

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.file.languageLabel;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.file.name, overflow: TextOverflow.ellipsis),
            if (widget.selectedSymbol case final symbol?)
              Text(
                'Static symbol: $symbol',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(34),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.file.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                _Pill(label: language.toUpperCase()),
                const SizedBox(width: 6),
                const _Pill(label: 'READ ONLY'),
                if (widget.initialLine case final line?) ...[
                  const SizedBox(width: 6),
                  _Pill(label: 'LINE $line'),
                ],
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<String>(
        future: _contents,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not open this file.\n${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lines = snapshot.requireData.split('\n');
          return Container(
            color: const Color(0xFF17211F),
            child: Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LineNumbers(count: lines.length),
                      const SizedBox(width: 16),
                      SelectableText.rich(
                        TextSpan(
                          children: [
                            for (var index = 0; index < lines.length; index++)
                              TextSpan(
                                text: index == lines.length - 1
                                    ? lines[index]
                                    : '${lines[index]}\n',
                                style: widget.initialLine == index + 1
                                    ? const TextStyle(
                                        backgroundColor: Color(0xFF3B5F54),
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                          ],
                        ),
                        style: const TextStyle(
                          color: Color(0xFFD9E7E1),
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: const _LspUnavailableBar(),
      ),
    );
  }
}

class _LineNumbers extends StatelessWidget {
  const _LineNumbers({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 14),
    child: Text(
      List.generate(count, (index) => '${index + 1}').join('\n'),
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: Color(0xFF71827C),
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.55,
      ),
    ),
  );
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.account_tree_rounded,
          color: Colors.white,
          size: 19,
        ),
      ),
      const SizedBox(width: 10),
      const Text(
        'Codexis',
        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      ),
    ],
  );
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onImport, required this.importing});

  final VoidCallback onImport;
  final bool importing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF173D37), Color(0xFF0D2925)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Pill(label: 'LOCAL CODE WORKSPACE', dark: true),
        const SizedBox(height: 18),
        Text(
          'Understand your\ncode, on device.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.08,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Import a local Rust or x86-64 NASM repository to browse its source.',
          style: TextStyle(color: Color(0xFFC2D8D0), height: 1.45),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: importing ? null : onImport,
          icon: importing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_rounded),
          label: Text(importing ? 'Importing copy…' : 'Import a repository'),
          style: FilledButton.styleFrom(
            foregroundColor: const Color(0xFF10352F),
            backgroundColor: const Color(0xFF8BE0CE),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    ),
  );
}

class _CapabilityNotice extends StatelessWidget {
  const _CapabilityNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4EF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF1D8CC)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: Color(0xFFA95035), size: 20),
        SizedBox(width: 11),
        Expanded(
          child: Text(
            'Semantic navigation is not available yet. File browsing works locally; LSP runtime support is still being validated.',
            style: TextStyle(color: Color(0xFF6F3C2D), height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _WorkspaceTrustCard extends StatelessWidget {
  const _WorkspaceTrustCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF2EE),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      children: [
        Icon(Icons.shield_outlined, color: Color(0xFF167267)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Read-only imported copy · LSP trust controls are not active yet',
            style: TextStyle(fontWeight: FontWeight.w600, height: 1.3),
          ),
        ),
      ],
    ),
  );
}

class _EmptyRepositories extends StatelessWidget {
  const _EmptyRepositories({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Icon(
            Icons.folder_open_rounded,
            size: 32,
            color: Color(0xFF087F72),
          ),
          const SizedBox(height: 10),
          Text(
            'Nothing here yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          const Text(
            'Choose a local Git repository. Codexis creates a private copy and leaves the original untouched.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF596863), height: 1.45),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Choose repository folder'),
          ),
        ],
      ),
    ),
  );
}

class _RepositoryCard extends StatelessWidget {
  const _RepositoryCard({
    required this.repository,
    required this.onTap,
    required this.onRemove,
  });

  final LocalRepository repository;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFE5F2ED),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.folder_copy_outlined, color: Color(0xFF087F72)),
      ),
      title: Text(
        repository.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        repository.path,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Repository actions',
        onSelected: (value) {
          if (value == 'remove') onRemove();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'remove', child: Text('Remove local copy')),
        ],
      ),
    ),
  );
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.onTap});

  final RepositoryFile file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dir = file.isDirectory;
    return ListTile(
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(
        dir ? Icons.folder_outlined : file.languageIcon,
        color: dir ? const Color(0xFFBB8251) : const Color(0xFF18796E),
        size: 21,
      ),
      title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        dir ? file.path : '${file.parentPath} · ${file.languageLabel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: dir ? null : const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _SymbolRow extends StatelessWidget {
  const _SymbolRow({required this.symbol, required this.onTap});

  final rust_api.IndexedSymbol symbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFE7F2EE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.tag_rounded, color: Color(0xFF087F72)),
      ),
      title: Text(
        symbol.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${symbol.kind} · ${symbol.language.toUpperCase()}\n${symbol.relativePath}:${symbol.startLine}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: false,
      trailing: const Icon(Icons.chevron_right_rounded),
    ),
  );
}

class _LspUnavailableBar extends StatelessWidget {
  const _LspUnavailableBar();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF1A2D29),
      borderRadius: BorderRadius.circular(15),
    ),
    child: const Row(
      children: [
        Icon(Icons.hub_outlined, color: Color(0xFF8BE0CE), size: 19),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'LSP server not connected',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          'NOT READY',
          style: TextStyle(
            color: Color(0xFFFFA48C),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _PrivacyFooter extends StatelessWidget {
  const _PrivacyFooter();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF6B7974)),
      SizedBox(width: 6),
      Text(
        'Private copy on this device · source is never edited',
        style: TextStyle(color: Color(0xFF6B7974), fontSize: 12),
      ),
    ],
  );
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEDEA),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFAC493A)),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
        IconButton(
          tooltip: 'Retry',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.dark = false});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: dark
          ? Colors.white.withValues(alpha: 0.12)
          : const Color(0xFFE9F2EE),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: dark ? const Color(0xFFBDE9DF) : const Color(0xFF31675D),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
  );
}

String _friendlyError(Object error) {
  if (error.toString().contains('MissingPluginException')) {
    return 'Repository access is not available on this platform build yet.';
  }
  return error
      .toString()
      .replaceFirst('PlatformException(', '')
      .replaceFirst(')', '');
}
