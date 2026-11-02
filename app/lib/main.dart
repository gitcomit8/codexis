import 'package:codexis/src/rust/api.dart' as rust_api;
import 'package:codexis/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CodexisApp());
}

class CodexisApp extends StatelessWidget {
  const CodexisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Codexis',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4568DC)),
      ),
      home: const RuntimeScreen(),
    );
  }
}

class RuntimeScreen extends StatefulWidget {
  const RuntimeScreen({super.key});

  @override
  State<RuntimeScreen> createState() => _RuntimeScreenState();
}

class _RuntimeScreenState extends State<RuntimeScreen> {
  late final Future<rust_api.RuntimeInfo> _runtime = _initializeRust();
  final TextEditingController _nameController = TextEditingController(
    text: 'Android',
  );
  String? _greeting;
  String? _error;
  bool _callingRust = false;

  Future<rust_api.RuntimeInfo> _initializeRust() async {
    await RustLib.init();
    await rust_api.initializeLogging();
    return rust_api.runtimeInfo();
  }

  Future<void> _callRust() async {
    setState(() {
      _callingRust = true;
      _error = null;
    });
    try {
      final greeting = await rust_api.greet(name: _nameController.text);
      if (!mounted) return;
      setState(() => _greeting = greeting);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _callingRust = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Codexis')),
      body: SafeArea(
        child: FutureBuilder<rust_api.RuntimeInfo>(
          future: _runtime,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _StatusPanel(
                title: 'Rust engine unavailable',
                detail: snapshot.error.toString(),
                color: colors.error,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final runtime = snapshot.requireData;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Local source intelligence',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Phase 0 runtime check',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.memory),
                    title: Text('${runtime.product} ${runtime.engine} engine'),
                    subtitle: Text(
                      'Bridge call succeeded · engine version ${runtime.version}',
                    ),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Call Rust',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _callingRust ? null : _callRust,
                  icon: _callingRust
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Run asynchronous Rust call'),
                ),
                if (_greeting case final greeting?) ...[
                  const SizedBox(height: 16),
                  _StatusPanel(
                    title: 'Rust response',
                    detail: greeting,
                    color: colors.primary,
                  ),
                ],
                if (_error case final error?) ...[
                  const SizedBox(height: 16),
                  _StatusPanel(
                    title: 'Rust returned an error',
                    detail: error,
                    color: colors.error,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.title,
    required this.detail,
    required this.color,
  });

  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    color: color.withValues(alpha: 0.08),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: color),
          ),
          const SizedBox(height: 6),
          SelectableText(detail),
        ],
      ),
    ),
  );
}
