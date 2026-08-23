import struct Swift.String
public import Institute_CI_Model
public import Institute_Model

// Nest.Name namespace shell.
//
// `Institute.CI.Validation` owns both halves of the reabsorbed validator
// surface. The *contract* — what a rule is, what it is run against, what
// it emits, and how an implementation is proved — was
// `Institute.CI.Validation` in the retired
// swift-github-continuous-integration package. The Institute's *policy*
// validators — the corpus-and-convention predicates (skill hygiene,
// gitignore canon, README conventions, schema correspondence, manifest
// binding) that are Institute doctrine rather than GitHub Actions
// mechanics — declared against that contract. Reabsorption puts both in
// this one nest.
//
// A rule implementation declares a `Validator`; it never prints, never
// exits, and never reads argv.
extension Institute.CI {
    public enum Validation {}
}
