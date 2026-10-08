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

func diagnose(_ text: Swift.String) {
    var text = text
    text.withUTF8 { bytes in
        guard let base = bytes.baseAddress else { return }
        var offset = 0
        while offset < bytes.count {
            #if os(Windows)
                let written = Swift.Int(
                    unsafe _write(2, base + offset, Swift.UInt32(bytes.count - offset))
                )
            #else
                let written = unsafe write(2, base + offset, bytes.count - offset)
            #endif
            guard written > 0 else { return }
            offset += written
        }
    }
}

let arguments = CommandLine.arguments.dropFirst().map { $0 + "\n" }.joined()
let format = unsafe getenv("SWIFT_LINTER_FORMAT").map { unsafe Swift.String(cString: $0) } ?? ""

guard
    record(arguments, at: ".swift-linter-arguments"),
    record(format, at: ".swift-linter-format")
else {
    diagnose("fixture linter cannot record its invocation\n")
    exit(70)
}

if format == "sarif" {
    print(#"{"version":"2.1.0","runs":[{"results":[]}]}"#)
}
diagnose("swift-affine-algebra-primitives · 1 active rules · 1 files linted · 0 violations\n")
