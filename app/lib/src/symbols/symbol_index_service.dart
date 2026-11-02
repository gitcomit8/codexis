import 'package:codexis/src/rust/api.dart' as rust_api;
import 'package:codexis/src/rust/frb_generated.dart';

abstract interface class SymbolIndexService {
  Future<List<rust_api.IndexedSymbol>> indexRepository(String root);
}

class RustSymbolIndexService implements SymbolIndexService {
  static Future<void>? _initialization;

  static Future<void> _initializeOnce() async {
    await RustLib.init();
    await rust_api.initializeLogging();
  }

  static Future<void> _ensureInitialized() =>
      _initialization ??= _initializeOnce();

  @override
  Future<List<rust_api.IndexedSymbol>> indexRepository(String root) async {
    await _ensureInitialized();
    return rust_api.indexRepository(root: root);
  }
}
