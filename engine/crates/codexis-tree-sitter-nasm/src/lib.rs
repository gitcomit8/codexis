use tree_sitter_language::LanguageFn;

unsafe extern "C" {
    fn tree_sitter_nasm() -> *const ();
}

/// Tree-sitter NASM grammar generated with language ABI 14.
/// Runtime 0.25 supports ABI 14 (minimum compatible ABI 13).
pub const LANGUAGE: LanguageFn = unsafe { LanguageFn::from_raw(tree_sitter_nasm) };
