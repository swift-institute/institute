public import Institute_Model

extension Institute {
    /// Development versions of the Institute's packages: the tag each
    /// package's `main` carries once its central CI has passed, so that
    /// consumers depend on a version instead of a branch.
    ///
    /// A tag is created only for the head of `main`, only when that exact
    /// commit has a successful `ci-ok` from a `main` run of the package's
    /// generated CI, only when it descends from the line's latest tag, and
    /// never moved or deleted. Everything here is decided over a
    /// `Client`; the GitHub binding is `Client.github`.
    public enum Version {}
}
