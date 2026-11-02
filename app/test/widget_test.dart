import 'package:codexis/main.dart';
import 'package:codexis/src/repositories/repository_service.dart';
import 'package:codexis/src/rust/api.dart' as rust_api;
import 'package:codexis/src/symbols/symbol_index_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

void main() {
  testWidgets('shows local import onboarding and honest LSP status', (
    tester,
  ) async {
    await tester.pumpWidget(
      CodexisApp(repositoryService: _FakeRepositoryService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Choose repository folder'), findsOneWidget);
    expect(
      find.textContaining('Semantic navigation is not available yet'),
      findsOneWidget,
    );
  });

  testWidgets('imports a repository and opens source in read-only viewer', (
    tester,
  ) async {
    final service = _FakeRepositoryService();
    await tester.pumpWidget(CodexisApp(repositoryService: service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import a repository'));
    await tester.pumpAndSettle();

    expect(find.text('sample-rust'), findsOneWidget);
    await tester.tap(find.text('src'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Parent folder'), findsOneWidget);
    await tester.tap(find.text('main.rs'));
    await tester.pumpAndSettle();

    expect(find.text('READ ONLY'), findsOneWidget);
    expect(find.textContaining('fn main()'), findsOneWidget);
    expect(find.text('LSP server not connected'), findsOneWidget);
  });

  testWidgets('shows and retries native repository access errors', (
    tester,
  ) async {
    final service = _FakeRepositoryService()..failListing = true;
    await tester.pumpWidget(CodexisApp(repositoryService: service));
    await tester.pumpAndSettle();

    expect(find.textContaining('Native storage unavailable'), findsOneWidget);
    service.failListing = false;
    await tester.tap(find.byTooltip('Retry').first);
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('indexes static symbols and opens the declaration location', (
    tester,
  ) async {
    final repositoryService = _FakeRepositoryService();
    final indexService = _FakeSymbolIndexService(
      symbols: const [
        rust_api.IndexedSymbol(
          relativePath: 'src/main.rs',
          language: 'rust',
          name: 'calculate',
          kind: 'function',
          startLine: 2,
          startColumn: 0,
          endLine: 4,
          endColumn: 1,
        ),
      ],
    );
    await tester.pumpWidget(
      CodexisApp(
        repositoryService: repositoryService,
        symbolIndexService: indexService,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import a repository'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Symbols'));
    await tester.pumpAndSettle();

    expect(find.text('Build a local symbol index'), findsOneWidget);
    await tester.tap(find.text('Index symbols'));
    await tester.pumpAndSettle();

    expect(
      find.text('Tree-sitter static symbols · not semantic LSP results'),
      findsOneWidget,
    );
    expect(find.text('calculate'), findsOneWidget);
    expect(find.textContaining('src/main.rs:2'), findsOneWidget);
    await tester.tap(find.text('calculate'));
    await tester.pumpAndSettle();

    expect(find.text('Static symbol: calculate'), findsOneWidget);
    expect(find.text('LINE 2'), findsOneWidget);
    expect(find.text('LSP server not connected'), findsOneWidget);
  });

  testWidgets('shows symbol loading, empty and parser error states', (
    tester,
  ) async {
    final repositoryService = _FakeRepositoryService();
    final pendingIndex = Completer<List<rust_api.IndexedSymbol>>();
    final indexService = _FakeSymbolIndexService(completer: pendingIndex);
    await tester.pumpWidget(
      CodexisApp(
        repositoryService: repositoryService,
        symbolIndexService: indexService,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import a repository'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Symbols'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Index symbols'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));

    pendingIndex.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('No Rust or NASM declarations found.'), findsOneWidget);
  });

  testWidgets('shows parser errors and supports retry', (tester) async {
    final repositoryService = _FakeRepositoryService()
      ..repositories.add(_FakeRepositoryService.repository);
    final failingIndex = _FakeSymbolIndexService(
      error: 'Tree-sitter parser failed',
    );
    await tester.pumpWidget(
      CodexisApp(
        repositoryService: repositoryService,
        symbolIndexService: failingIndex,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('sample-rust'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Symbols'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Index repository symbols'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tree-sitter parser failed'), findsOneWidget);
  });
}

class _FakeRepositoryService implements RepositoryService {
  static const repository = LocalRepository(
    id: 'repo-1',
    name: 'sample-rust',
    path: '/private/repositories/repo-1',
  );

  static const source = RepositoryFile(
    path: '/private/repositories/repo-1/src/main.rs',
    name: 'main.rs',
    isDirectory: false,
    size: 14,
  );
  static const sourceDirectory = RepositoryFile(
    path: '/private/repositories/repo-1/src',
    name: 'src',
    isDirectory: true,
    size: 0,
  );

  bool failListing = false;
  final repositories = <LocalRepository>[];

  @override
  Future<List<LocalRepository>> listRepositories() async {
    if (failListing) throw StateError('Native storage unavailable');
    return List.unmodifiable(repositories);
  }

  @override
  Future<LocalRepository?> pickAndImportRepository() async {
    repositories.add(repository);
    return repository;
  }

  @override
  Future<List<RepositoryFile>> listFiles(
    LocalRepository repository, {
    String? directoryPath,
  }) async => directoryPath == repository.path
      ? const [sourceDirectory]
      : const [source];

  @override
  Future<String> readFile(RepositoryFile file) async =>
      'fn main() {\n    println!("hi");\n}\n';

  @override
  Future<void> removeRepository(String id) async {
    repositories.removeWhere((repository) => repository.id == id);
  }
}

class _FakeSymbolIndexService implements SymbolIndexService {
  _FakeSymbolIndexService({
    this.symbols = const [],
    this.error,
    this.completer,
  });

  final List<rust_api.IndexedSymbol> symbols;
  final String? error;
  final Completer<List<rust_api.IndexedSymbol>>? completer;

  @override
  Future<List<rust_api.IndexedSymbol>> indexRepository(String root) {
    if (error != null) throw StateError(error!);
    if (completer != null) return completer!.future;
    return Future.value(symbols);
  }
}
