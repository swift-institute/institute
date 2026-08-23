extension Institute {
    /// The Institute Application: the composition that operates an Institute
    /// checkout, as distinct from the Institute domain model it composes.
    ///
    /// Domain semantics — inventory, dependency, doctor, lint, instruments,
    /// conversion, development — are owned by `Institute` itself. This
    /// namespace owns only the act of operating them: the command surface and
    /// the wiring that binds it to a root.
    public enum Application {}
}
