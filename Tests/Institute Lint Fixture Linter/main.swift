#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#elseif canImport(ucrt)
    import ucrt
#endif

func record(_ text: Swift.String, at path: Swift.String) -> Swift.Bool {
    guard let file = unsafe fopen(path, "wb") else { return false }
    let written = unsafe fputs(text, file) >= 0
    return unsafe fclose(file) == 0 && written
}

let arguments = CommandLine.arguments.dropFirst().map { $0 + "\n" }.joined()
let format = unsafe getenv("SWIFT_LINTER_FORMAT").map { unsafe Swift.String(cString: $0) } ?? ""

guard
    record(arguments, at: ".swift-linter-arguments"),
    record(format, at: ".swift-linter-format")
else {
    unsafe fputs("fixture linter cannot record its invocation\n", stderr)
    exit(70)
}

if format == "sarif" {
    print(#"{"version":"2.1.0","runs":[{"results":[]}]}"#)
}
unsafe fputs("swift-affine-algebra-primitives · 1 active rules · 1 files linted · 0 violations\n", stderr)
