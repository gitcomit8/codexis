use serde::{Deserialize, Serialize};
use std::path::Path;
use std::sync::OnceLock;

static LOGGING_INITIALIZED: OnceLock<()> = OnceLock::new();

#[flutter_rust_bridge::frb]
pub fn initialize_logging() {
    LOGGING_INITIALIZED.get_or_init(|| {
        let subscriber = tracing_subscriber::fmt()
            .with_writer(std::io::stderr)
            .with_ansi(false)
            .finish();
        let _ = tracing::subscriber::set_global_default(subscriber);
    });
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuntimeInfo {
    pub product: String,
    pub engine: String,
    pub version: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IndexedSymbol {
    pub relative_path: String,
    pub language: String,
    pub name: String,
    pub kind: String,
    pub start_line: u32,
    pub start_column: u32,
    pub end_line: u32,
    pub end_column: u32,
}

#[flutter_rust_bridge::frb]
pub fn index_repository(root: String) -> anyhow::Result<Vec<IndexedSymbol>> {
    let index = codexis_parser::scan_repository(Path::new(&root))?;
    let symbols = index
        .files
        .into_iter()
        .flat_map(|file| {
            let language = match file.parse.language {
                codexis_parser::Language::Rust => "rust",
                codexis_parser::Language::Nasm => "nasm",
            };
            file.parse
                .symbols
                .into_iter()
                .map(move |symbol| IndexedSymbol {
                    relative_path: file.relative_path.clone(),
                    language: language.to_owned(),
                    name: symbol.name,
                    kind: format!("{:?}", symbol.kind).to_ascii_lowercase(),
                    start_line: symbol.location.start_line,
                    start_column: symbol.location.start_column,
                    end_line: symbol.location.end_line,
                    end_column: symbol.location.end_column,
                })
        })
        .collect();
    Ok(symbols)
}

#[flutter_rust_bridge::frb]
pub fn parse_source_file(path: String, source: String) -> anyhow::Result<Vec<IndexedSymbol>> {
    let parsed = codexis_parser::parse_source(&path, &source)?;
    let language = match parsed.language {
        codexis_parser::Language::Rust => "rust",
        codexis_parser::Language::Nasm => "nasm",
    };
    Ok(parsed
        .symbols
        .into_iter()
        .map(|symbol| IndexedSymbol {
            relative_path: path.clone(),
            language: language.to_owned(),
            name: symbol.name,
            kind: format!("{:?}", symbol.kind).to_ascii_lowercase(),
            start_line: symbol.location.start_line,
            start_column: symbol.location.start_column,
            end_line: symbol.location.end_line,
            end_column: symbol.location.end_column,
        })
        .collect())
}

#[flutter_rust_bridge::frb]
pub fn runtime_info() -> RuntimeInfo {
    tracing::info!("Codexis Rust runtime queried");
    RuntimeInfo {
        product: "Codexis".to_owned(),
        engine: "Rust".to_owned(),
        version: 1,
    }
}

#[flutter_rust_bridge::frb]
pub async fn greet(name: String) -> anyhow::Result<String> {
    let name = name.trim();
    if name.is_empty() {
        anyhow::bail!("Name must not be empty");
    }
    Ok(format!("Hello, {name}. Rust is running locally."))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn runtime_info_is_structured() {
        let info = runtime_info();
        assert_eq!(info.product, "Codexis");
        assert_eq!(info.engine, "Rust");
        assert_eq!(info.version, 1);
    }

    #[tokio::test]
    async fn greet_rejects_empty_name() {
        assert_eq!(
            greet("  ".to_owned()).await.unwrap_err().to_string(),
            "Name must not be empty"
        );
    }
}
