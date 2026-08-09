internal import Institute_Model
internal import Institute_Inventory

extension Institute.Dependency {
    /// Resolution of one declared key through GitHub repository redirects.
    struct Resolution: Sendable {
        let declared: Institute.Repository.Key
        let fetch: Fetch<Metadata>
    }
}
