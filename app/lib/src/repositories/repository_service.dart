import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract interface class RepositoryService {
  Future<List<LocalRepository>> listRepositories();

  Future<LocalRepository?> pickAndImportRepository();

  Future<List<RepositoryFile>> listFiles(
    LocalRepository repository, {
    String? directoryPath,
  });

  Future<String> readFile(RepositoryFile file);

  Future<void> removeRepository(String id);
}

class AndroidRepositoryService implements RepositoryService {
  AndroidRepositoryService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('dev.codexis/runtime');

  final MethodChannel _channel;

  @override
  Future<List<LocalRepository>> listRepositories() async {
    final values = await _channel.invokeListMethod<Object?>('listRepositories');
    return (values ?? const <Object?>[])
        .map((value) => LocalRepository.fromMap(_asMap(value)))
        .toList(growable: false);
  }

  @override
  Future<LocalRepository?> pickAndImportRepository() async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      'pickAndImportRepository',
    );
    return value == null ? null : LocalRepository.fromMap(_asMap(value));
  }

  @override
  Future<List<RepositoryFile>> listFiles(
    LocalRepository repository, {
    String? directoryPath,
  }) async {
    final values = await _channel.invokeListMethod<Object?>('listFiles', {
      'path': directoryPath ?? repository.path,
    });
    return (values ?? const <Object?>[])
        .map((value) => RepositoryFile.fromMap(_asMap(value)))
        .where((file) => file.isDirectory || file.isSupportedSource)
        .toList(growable: false);
  }

  @override
  Future<String> readFile(RepositoryFile file) async {
    final contents = await _channel.invokeMethod<String>('readFile', {
      'path': file.path,
    });
    if (contents == null) {
      throw StateError('The selected file could not be read.');
    }
    return contents;
  }

  @override
  Future<void> removeRepository(String id) async {
    await _channel.invokeMethod<void>('removeRepository', {'id': id});
  }
}

class LocalRepository {
  const LocalRepository({
    required this.id,
    required this.name,
    required this.path,
  });

  final String id;
  final String name;
  final String path;

  factory LocalRepository.fromMap(Map<Object?, Object?> map) => LocalRepository(
    id: _requiredString(map, 'id'),
    name: _requiredString(map, 'name'),
    path: _requiredString(map, 'path'),
  );
}

class RepositoryFile {
  const RepositoryFile({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
  });

  final String path;
  final String name;
  final bool isDirectory;
  final int size;

  factory RepositoryFile.fromMap(Map<Object?, Object?> map) => RepositoryFile(
    path: _requiredString(map, 'path'),
    name: _requiredString(map, 'name'),
    isDirectory: map['isDirectory'] == true,
    size: (map['size'] as num?)?.toInt() ?? 0,
  );

  String get extension {
    final index = name.lastIndexOf('.');
    return index < 0 ? '' : name.substring(index + 1).toLowerCase();
  }

  bool get isSupportedSource =>
      const {'rs', 'asm', 's', 'nasm'}.contains(extension);

  String get languageLabel => switch (extension) {
    'rs' => 'Rust',
    'asm' || 'nasm' || 's' => 'Assembly',
    _ => 'Text',
  };

  IconData get languageIcon => switch (extension) {
    'rs' => Icons.code_rounded,
    'asm' || 'nasm' || 's' => Icons.memory_rounded,
    _ => Icons.insert_drive_file_outlined,
  };

  String get parentPath {
    final separator = path.lastIndexOf('/');
    return separator <= 0 ? '' : path.substring(0, separator);
  }
}

Map<Object?, Object?> _asMap(Object? value) {
  if (value is Map<Object?, Object?>) return value;
  if (value is Map) return Map<Object?, Object?>.from(value);
  throw const FormatException('Native repository response was not an object.');
}

String _requiredString(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Native repository response is missing "$key".');
}
