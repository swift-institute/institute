package func manifestSourceTarget(ofPath path: Swift::String) -> Swift::String? {
    let directories = path.split(separator: "/").dropLast().map(Swift::String.init)
    guard let sources = directories.lastIndex(of: "Sources"), sources + 1 < directories.count
    else { return nil }
    return directories[sources + 1]
}
