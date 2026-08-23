public import Institute_Model

// Nest.Name namespace shell for the Swift-native programme surfaces
// (FT1-ratification.json; naming-annex-nest-name.md). The pre-existing flat
// `RepositoryPolicy` namespace stays until its owners migrate; new
// programme-era types nest under `Institute.Repository.Policy`, the
// policy surface of the domain's own `Institute.Repository`.
extension Institute.Repository {
    public enum Policy {}
}
