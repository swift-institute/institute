public import Command
public import Command_Schema
import Console
import Environment
import File_System
public import Institute_Model
import Institute_Shader
import Process

extension Institute.Application {
    /// `institute shader` — the generated files of the package in the current
    /// directory, written again from the kernels they are made from, or with
    /// `--check` compared with them.
    public struct Shader: Sendable, Command_Schema::Command.`Protocol` {
        public var check: Swift.Bool

        public init(check: Swift.Bool = false) {
            self.check = check
        }
    }
}

extension Institute.Application.Shader {
    public static var configuration: Command_Schema::Command.Configuration {
        .init(
            name: "shader",
            abstract: "Write the package's kernels in a GPU's language.",
            discussion: """
                Run it in a package directory. Every Swift file of Sources whose first line is \
                "// institute shader: target, constant, condition", or "// institute shader (WGSL): ..." \
                for WGSL, is written again: the target is compiled to WebAssembly with the swift.org \
                release Institute.Shader names, and its kernels are written in the file's language \
                into the constant: Metal's shading language as one text, or WGSL as a module for each \
                kernel by name. --check writes \
                nothing. The exit status is 0 when every file is written or fresh, 1 when a checked \
                file is stale, 2 when a file could not be made.
                """
        )
    }

    public static var schema: Command_Schema::Command.Schema.Definition<Self> {
        .init {
            Command_Schema::Command.Flag(
                \.check,
                name: .long(.literal("check")),
                help: .init(abstract: "Say whether the files are fresh, and write nothing.")
            )
        }
    }

    public mutating func run() async throws(Institute.Error) {
        let code: Swift.Int32
        do throws(Institute.Error) {
            code = try outcome()
        } catch {
            Console.Output.error("institute shader: \(error)\n")
            code = 2
        }
        Process.Exit.normal(code)
    }

    private func outcome() throws(Institute.Error) -> Swift.Int32 {
        let root: File.Path
        do throws(File.System.Canonical.Error) {
            root = try File.System.Canonical.resolve(".")
        } catch {
            throw .filesystem("cannot resolve the current directory: \(error)")
        }
        guard File.Directory(root)[file: "Package.swift"].stat.isFile else {
            throw .configuration("run it in a package directory; \(root) has no Package.swift")
        }
        guard let home = Environment.read("HOME") else { throw .configuration("HOME is not set") }
        let name = "swift-\(Institute.Shader.release)-RELEASE"
        let toolchain = "\(home)/Library/Developer/Toolchains/\(name).xctoolchain/usr/bin"
        let package = Institute.Shader.Package(root: root, toolchain: toolchain)
        let generated = try package.generated()
        guard !generated.isEmpty else {
            throw .configuration("no file of Sources begins with \"// institute shader:\"")
        }
        for file in generated where !file.fresh && !check { try package.write(file) }
        for file in generated {
            print("\(file.path): \(file.fresh ? "fresh" : check ? "stale" : "written")")
        }
        return check && !generated.allSatisfy(\.fresh) ? 1 : 0
    }
}
