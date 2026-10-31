extension PackageTargetImportEdgeTarget {

    package enum Dependency {

        case target(Swift::String)

        case product(Swift::String)

        case byName(Swift::String)
    }
}
