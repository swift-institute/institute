#if LinterRuleBuildErrors
    import Byte
    import File_System
    import Lint
    import Institute_Linter_Rule_Build_Errors
    import Process

    let outcome = Lint.Build.run(
        arguments: [Swift::String](Swift::CommandLine.arguments.dropFirst()),
        rules: Lint.Rule.Bundle.buildErrors
    )
    for line in outcome.lines {
        print(line)
    }
    if let stamp = outcome.stamp {
        let empty: [Byte] = []
        do {
            let path = try File.Path(stamp)
            try File.System.Write.Atomic.write(empty.span, to: path)
        } catch {
            print("swift-linter-build-errors: could not write the stamp file \(stamp)")
            Process.Exit.normal(1)
        }
    }
    Process.Exit.normal(outcome.status)
#endif
