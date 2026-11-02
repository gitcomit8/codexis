use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use thiserror::Error;
use tree_sitter::{Language as TsLanguage, Node, Parser};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Language {
    Rust,
    Nasm,
}

impl Language {
    pub fn from_path(path: &Path) -> Option<Self> {
        match path.extension()?.to_str()?.to_ascii_lowercase().as_str() {
            "rs" => Some(Self::Rust),
            "asm" | "nasm" | "s" => Some(Self::Nasm),
            _ => None,
        }
    }

    fn tree_sitter_language(self) -> TsLanguage {
        match self {
            Self::Rust => tree_sitter_rust::LANGUAGE.into(),
            Self::Nasm => codexis_tree_sitter_nasm::LANGUAGE.into(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SymbolKind {
    Function,
    Method,
    Struct,
    Class,
    Trait,
    Interface,
    Enum,
    Import,
    Module,
    Label,
    Macro,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SourceLocation {
    /// One-based line number for display in an editor.
    pub start_line: u32,
    /// One-based Unicode scalar column for display in an editor.
    pub start_column: u32,
    pub end_line: u32,
    pub end_column: u32,
    /// UTF-8 byte offsets into the source buffer.
    pub start_byte: u32,
    pub end_byte: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Symbol {
    pub name: String,
    pub kind: SymbolKind,
    pub location: SourceLocation,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ParseResult {
    pub language: Language,
    pub symbols: Vec<Symbol>,
    pub has_syntax_errors: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct IndexedFile {
    pub relative_path: String,
    pub parse: ParseResult,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ScanIssue {
    pub relative_path: String,
    pub message: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RepositoryIndex {
    pub files: Vec<IndexedFile>,
    pub issues: Vec<ScanIssue>,
}

#[derive(Debug, Error)]
pub enum ParserError {
    #[error("unsupported source file: {0}")]
    UnsupportedFile(String),
    #[error("Tree-sitter could not configure the {language:?} grammar: {message}")]
    Grammar { language: Language, message: String },
    #[error("Tree-sitter failed to parse source")]
    ParseFailed,
    #[error("repository path is not a directory: {0}")]
    NotDirectory(String),
    #[error("could not inspect repository: {0}")]
    Io(#[from] std::io::Error),
}

/// Parse a UTF-8 source buffer and return normalized declarations and locations.
/// Syntax errors are reported in `has_syntax_errors`; valid symbols are still returned.
pub fn parse_source(path: &str, source: &str) -> Result<ParseResult, ParserError> {
    let path = Path::new(path);
    let language = Language::from_path(path)
        .ok_or_else(|| ParserError::UnsupportedFile(path.display().to_string()))?;
    let mut parser = Parser::new();
    parser
        .set_language(&language.tree_sitter_language())
        .map_err(|error| ParserError::Grammar {
            language,
            message: error.to_string(),
        })?;
    let tree = parser.parse(source, None).ok_or(ParserError::ParseFailed)?;
    let mut symbols = Vec::new();
    collect_symbols(tree.root_node(), language, source, &mut symbols);
    Ok(ParseResult {
        language,
        symbols,
        has_syntax_errors: tree.root_node().has_error(),
    })
}

fn collect_symbols(node: Node<'_>, language: Language, source: &str, out: &mut Vec<Symbol>) {
    if language == Language::Rust && node.kind() == "use_declaration" {
        if let Ok(text) = node.utf8_text(source.as_bytes()) {
            let name = text
                .trim()
                .strip_prefix("use")
                .unwrap_or(text.trim())
                .trim()
                .trim_end_matches(';')
                .trim()
                .to_owned();
            out.push(Symbol {
                name,
                kind: SymbolKind::Import,
                location: location(node, source),
            });
        }
    }
    if let Some((name_node, kind)) = symbol_node(node, language) {
        if let Ok(name) = name_node.utf8_text(source.as_bytes()) {
            out.push(Symbol {
                name: name.to_owned(),
                kind,
                location: location(name_node, source),
            });
        }
    }
    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        collect_symbols(child, language, source, out);
    }
}

fn symbol_node<'tree>(node: Node<'tree>, language: Language) -> Option<(Node<'tree>, SymbolKind)> {
    match language {
        Language::Rust => {
            let kind = match node.kind() {
                "function_item" => {
                    if has_ancestor_kind(node, "impl_item") || has_ancestor_kind(node, "trait_item")
                    {
                        SymbolKind::Method
                    } else {
                        SymbolKind::Function
                    }
                }
                "function_signature_item" => SymbolKind::Method,
                "struct_item" => SymbolKind::Struct,
                "enum_item" => SymbolKind::Enum,
                "trait_item" => SymbolKind::Trait,
                "mod_item" => SymbolKind::Module,
                _ => return None,
            };
            let name = node.child_by_field_name("name")?;
            Some((name, kind))
        }
        Language::Nasm => {
            if node.kind() == "label" {
                let name = node
                    .child_by_field_name("name")
                    .or_else(|| node.child_by_field_name("kind"))
                    .or_else(|| {
                        let mut cursor = node.walk();
                        node.named_children(&mut cursor)
                            .find(|child| matches!(child.kind(), "ident" | "word"))
                    })?;
                Some((name, SymbolKind::Label))
            } else {
                None
            }
        }
    }
}

fn has_ancestor_kind(node: Node<'_>, expected: &str) -> bool {
    let mut parent = node.parent();
    while let Some(ancestor) = parent {
        if ancestor.kind() == expected {
            return true;
        }
        parent = ancestor.parent();
    }
    false
}

fn location(node: Node<'_>, source: &str) -> SourceLocation {
    let start = node.start_position();
    let end = node.end_position();
    SourceLocation {
        start_line: start.row as u32 + 1,
        start_column: scalar_column(source, node.start_byte(), start.column),
        end_line: end.row as u32 + 1,
        end_column: scalar_column(source, node.end_byte(), end.column),
        start_byte: node.start_byte().min(u32::MAX as usize) as u32,
        end_byte: node.end_byte().min(u32::MAX as usize) as u32,
    }
}

fn scalar_column(source: &str, byte: usize, tree_sitter_column: usize) -> u32 {
    let line_start = byte.saturating_sub(tree_sitter_column);
    source
        .get(line_start..byte)
        .map(|prefix| prefix.chars().count() as u32 + 1)
        .unwrap_or(tree_sitter_column as u32 + 1)
}

/// Read-only scan for Rust and NASM source. It skips VCS metadata, build output,
/// dependency directories, hidden directories, and symlinks.
pub fn scan_repository(root: &Path) -> Result<RepositoryIndex, ParserError> {
    let root = root.canonicalize()?;
    if !root.is_dir() {
        return Err(ParserError::NotDirectory(root.display().to_string()));
    }
    let mut paths = Vec::new();
    let mut issues = Vec::new();
    collect_paths(&root, &root, &mut paths, &mut issues)?;
    paths.sort();

    let mut files = Vec::new();
    for path in paths {
        let relative_path = relative_path(&root, &path);
        if Language::from_path(&path).is_none() {
            continue;
        }
        match fs::read_to_string(&path) {
            Ok(source) => match parse_source(&path.to_string_lossy(), &source) {
                Ok(parse) => files.push(IndexedFile {
                    relative_path,
                    parse,
                }),
                Err(error) => issues.push(ScanIssue {
                    relative_path,
                    message: error.to_string(),
                }),
            },
            Err(error) => issues.push(ScanIssue {
                relative_path,
                message: error.to_string(),
            }),
        }
    }
    Ok(RepositoryIndex { files, issues })
}

fn collect_paths(
    root: &Path,
    directory: &Path,
    paths: &mut Vec<PathBuf>,
    issues: &mut Vec<ScanIssue>,
) -> Result<(), ParserError> {
    let mut entries = fs::read_dir(directory)?.collect::<Result<Vec<_>, _>>()?;
    entries.sort_by_key(|entry| entry.file_name());
    for entry in entries {
        let path = entry.path();
        let file_type = entry.file_type()?;
        if file_type.is_symlink() {
            continue;
        }
        if file_type.is_dir() {
            let name = entry.file_name();
            let name = name.to_string_lossy();
            if name.starts_with('.') || matches!(name.as_ref(), "target" | "node_modules" | "build")
            {
                continue;
            }
            if let Err(error) = collect_paths(root, &path, paths, issues) {
                issues.push(ScanIssue {
                    relative_path: relative_path(root, &path),
                    message: error.to_string(),
                });
            }
        } else if file_type.is_file() && Language::from_path(&path).is_some() {
            paths.push(path);
        }
    }
    Ok(())
}

fn relative_path(root: &Path, path: &Path) -> String {
    path.strip_prefix(root)
        .unwrap_or(path)
        .to_string_lossy()
        .replace('\\', "/")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_rust_symbols_and_classifies_impl_methods() {
        let source = include_str!("../tests/fixtures/rust/lib.rs");
        let parsed = parse_source("lib.rs", source).unwrap();
        assert!(!parsed.has_syntax_errors);
        assert!(
            parsed
                .symbols
                .iter()
                .any(|s| s.name == "crate::model::Record" && s.kind == SymbolKind::Import)
        );
        assert!(
            parsed
                .symbols
                .iter()
                .any(|s| s.name == "storage" && s.kind == SymbolKind::Module)
        );
        assert!(
            parsed
                .symbols
                .iter()
                .any(|s| s.name == "Store" && s.kind == SymbolKind::Struct)
        );
        assert!(
            parsed
                .symbols
                .iter()
                .any(|s| s.name == "State" && s.kind == SymbolKind::Enum)
        );
        assert!(
            parsed
                .symbols
                .iter()
                .any(|s| s.name == "Readable" && s.kind == SymbolKind::Trait)
        );
        assert!(
            parsed
                .symbols
                .iter()
                .any(|s| s.name == "read" && s.kind == SymbolKind::Method)
        );
        assert!(
            parsed
                .symbols
                .iter()
                .any(|s| s.name == "get" && s.kind == SymbolKind::Method)
        );
        assert!(
            parsed
                .symbols
                .iter()
                .any(|s| s.name == "helper" && s.kind == SymbolKind::Function)
        );
    }

    #[test]
    fn parses_nasm_labels_and_locations_with_unicode_before_symbol() {
        let source = include_str!("../tests/fixtures/nasm/hello.asm");
        let parsed = parse_source("start.asm", source).unwrap();
        assert!(!parsed.has_syntax_errors, "valid NASM fixture should parse");
        assert!(parsed.symbols.iter().any(|s| {
            s.name == "_start"
                && s.kind == SymbolKind::Label
                && s.location.start_line == 8
                && s.location.start_column == 1
        }));
        assert!(
            parsed
                .symbols
                .iter()
                .any(|s| s.name == "message" && s.kind == SymbolKind::Label)
        );
    }

    #[test]
    fn repository_scan_is_read_only_and_only_indexes_supported_files() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures");
        let index = scan_repository(&root).unwrap();
        assert_eq!(index.files.len(), 2);
        assert!(index.issues.is_empty());
        assert!(
            index
                .files
                .iter()
                .any(|file| file.relative_path == "rust/lib.rs")
        );
        assert!(
            index
                .files
                .iter()
                .any(|file| file.relative_path == "nasm/hello.asm")
        );
    }

    #[test]
    fn reports_parse_errors_without_dropping_recoverable_symbols() {
        let parsed = parse_source("broken.asm", "entry:\n    mov rax, [\nnext:\n").unwrap();
        assert!(parsed.has_syntax_errors);
        assert!(parsed.symbols.iter().any(|symbol| symbol.name == "entry"));
    }

    #[test]
    fn rejects_unknown_file_extensions() {
        assert!(matches!(
            parse_source("notes.txt", "hello"),
            Err(ParserError::UnsupportedFile(_))
        ));
    }

    #[test]
    fn source_columns_count_unicode_scalars_while_byte_ranges_remain_utf8() {
        let source = "#[doc = \"café\"] fn locate() {}";
        let parsed = parse_source("lib.rs", source).unwrap();
        let symbol = parsed
            .symbols
            .iter()
            .find(|symbol| symbol.name == "locate")
            .unwrap();
        let byte = source.find("locate").unwrap();
        assert_eq!(symbol.location.start_byte as usize, byte);
        assert_eq!(
            symbol.location.start_column as usize,
            source[..byte].chars().count() + 1
        );
    }
}
