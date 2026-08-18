public import Institute_Model

extension Institute {
    /// Local-development namespace: machinery that exists so a developer can
    /// point consumers at local mutable sources and verify them — as opposed
    /// to the composition primitives themselves, which live under
    /// ``Institute/Composition``.
    public enum Development {}
}
