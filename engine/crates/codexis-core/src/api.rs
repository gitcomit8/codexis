use serde::{Deserialize, Serialize};
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
pub async fn greet(name: String) -> Result<String, String> {
    let name = name.trim();
    if name.is_empty() {
        return Err("Name must not be empty".to_owned());
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
            greet("  ".to_owned()).await,
            Err("Name must not be empty".to_owned())
        );
    }
}
