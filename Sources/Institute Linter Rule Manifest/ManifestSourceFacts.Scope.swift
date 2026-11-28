extension ManifestSourceFacts {
    /// Where a declaration sits while a file is walked: the path of the type it is nested in, the requirements of
    /// the extensions around it, the `#if` conditions around it, and whether its extension makes it public.
    internal struct Scope {
        var path: [Swift::String] = []
        var requirements: [Swift::String] = []
        var conditions: [Swift::String] = []
        var publicByDefault = false
    }
}
