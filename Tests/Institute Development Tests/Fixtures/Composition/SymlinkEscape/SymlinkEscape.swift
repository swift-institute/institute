// SymlinkEscape fixture.
//
// Constructed at runtime: a symlinked prefix inside a hierarchy root
// pointing outside it, which `Institute.Root.preflight(_:under:)` must
// refuse. A symlink is filesystem state, not source, so nothing beyond
// this marker is committed. Excluded from compilation with the rest of
// the fixture tree.
