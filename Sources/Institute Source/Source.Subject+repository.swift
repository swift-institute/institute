package import GitHub_Standard
import Source_Measurement

extension Source_Measurement.Source.Subject {
    /// The `owner/name` before the `@` of a CI subject's identity; any other identity names no repository.
    package var repository: GitHub_Standard::GitHub.Repository.Slug? {
        GitHub_Standard::GitHub.Repository.Slug(identity.prefix { $0 != "@" })
    }
}
