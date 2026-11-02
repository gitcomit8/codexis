fn main() {
    let source = "src/parser.c";
    cc::Build::new()
        .include("src")
        .flag_if_supported("-Wno-unused-parameter")
        .file(source)
        .compile("codexis_tree_sitter_nasm");
    println!("cargo:rerun-if-changed={source}");
    println!("cargo:rerun-if-changed=src/tree_sitter/parser.h");
}
