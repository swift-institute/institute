import Byte
public import File_System
import Git_Foundation
public import Institute_Model
import Process
import Shader_Compiler
import W3C_WebAssembly

extension Institute.Shader {
    /// A package whose kernels are written into generated files.
    public struct Package: Sendable {
        public var root: File.Path
        /// The directory of the toolchain's programs.
        public var toolchain: Swift.String

        public init(root: File.Path, toolchain: Swift.String) {
            self.root = root
            self.toolchain = toolchain
        }
    }
}

extension Institute.Shader.Package {
    /// The package's generated files, each made again from its target.
    public func generated() throws(Institute.Error) -> [Institute.Shader.Generated] {
        let paths: [Swift.String]
        do throws(Git.Client.Error) {
            paths = try Git.Client().paths(at: root)
        } catch {
            throw .repository("cannot list the files of \(root): \(error)")
        }
        var modules: [Swift.String: W3C.WebAssembly.Module] = [:]
        var generated: [Institute.Shader.Generated] = []
        for path in paths.sorted() where path.hasPrefix("Sources/") && path.hasSuffix(".swift") {
            // WHY: Git lists a file that is deleted and not yet committed.
            guard File(try self.path(path)).stat.isFile else { continue }
            let current = Swift.String(decoding: try bytes(at: path), as: Swift.UTF8.self)
            guard let file = Shader_Compiler::Shader.Compiler.File(reading: current) else { continue }
            let module: W3C.WebAssembly.Module
            if let known = modules[file.target] {
                module = known
            } else {
                module = try self.module(of: file.target)
                modules[file.target] = module
            }
            generated.append(.init(path: path, current: current, wanted: try contents(of: file, from: module)))
        }
        return generated
    }

    /// Writes a generated file as it should be.
    public func write(_ generated: Institute.Shader.Generated) throws(Institute.Error) {
        let path = try path(generated.path)
        let bytes = Swift.Array(generated.wanted.utf8).map(Byte.init(bitPattern:))
        do throws(File.System.Write.Atomic.Error) {
            try File(path).write.atomic(contentsOf: bytes)
        } catch {
            throw .filesystem("cannot write \(generated.path): \(error)")
        }
    }

    /// A generated file's contents: its target's kernels in the file's language.
    private func contents(of file: Shader_Compiler::Shader.Compiler.File, from module: W3C.WebAssembly.Module) throws(Institute.Error) -> Swift.String {
        do throws(Shader_Compiler::Shader.Compiler.Error) {
            switch file.language {
            case .metal: return file.contents(try Shader_Compiler::Shader.Compiler.metal(module).text)
            case .wgsl: return file.contents(try Shader_Compiler::Shader.Compiler.wgsl(module).mapValues(\.text))
            }
        } catch {
            throw .configuration("\(file.target) has no text in \(file.language.rawValue): \(error)")
        }
    }

    /// A target's kernels as one WebAssembly module: compiled and linked.
    private func module(of target: Swift.String) throws(Institute.Error) -> W3C.WebAssembly.Module {
        let build = "\(root)/.build/wasm32-unknown-wasip1/release"
        try run(
            "\(toolchain)/swift",
            [
                "build", "--swift-sdk", "swift-\(Institute.Shader.release)-RELEASE_wasm-embedded", "--build-system", "native",
                "-c", "release", "--target", target, "-Xswiftc", "-Ounchecked", "-Xswiftc", "-DSHADER",
                "-Xswiftc", "-Wwarning", "-Xswiftc", "StrictMemorySafety",
                "-Xswiftc", "-Xfrontend", "-Xswiftc", "-disable-stack-protector",
                // WHY: A buffer's number must stay a constant: no branches merged that read different buffers.
                "-Xswiftc", "-Xllvm", "-Xswiftc", "-sink-common-insts=false", "-Xswiftc", "-Xllvm", "-Xswiftc", "-hoist-common-insts=false",
                "-Xswiftc", "-Xllvm", "-Xswiftc", "-enable-tail-merge=false",
            ],
            as: "compile \(target)"
        )
        let own = "\(build)/\(target.replacing(" ", with: "_")).build/"
        let found = try run("/usr/bin/find", [build, "-name", "*.o", "-type", "f"], as: "list \(build)")
        let objects = found.split(separator: "\n").map(Swift.String.init).sorted()
        let linked = "\(build)/shader.wasm"
        // WHY: --strip-debug keeps the name section, whose data segment names let the compiler leave Swift's module
        // hashes, which change with the build's paths, out of the kernels' data image.
        try run(
            "\(toolchain)/wasm-ld",
            ["--no-entry", "--gc-sections", "--allow-undefined", "--strip-debug"] + objects.filter { $0.hasPrefix(own) }
                + ["--start-lib"] + objects.filter { !$0.hasPrefix(own) } + ["--end-lib", "-o", linked],
            as: "link \(target)"
        )
        let binary = try bytes(at: ".build/wasm32-unknown-wasip1/release/shader.wasm")
        do throws(W3C.WebAssembly.Error) {
            return try .parse(binary)
        } catch {
            throw .configuration("\(target) did not link to a module: \(error)")
        }
    }

    private func path(_ relative: Swift.String) throws(Institute.Error) -> File.Path {
        let whole: Swift.String = "\(root)/" + relative
        do throws(File.Path.Error) {
            return try File.Path(whole)
        } catch {
            throw .filesystem("\(relative) is not a path: \(error)")
        }
    }

    private func bytes(at relative: Swift.String) throws(Institute.Error) -> [Byte] {
        let path = try path(relative)
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try File(path).read.full { view in
                var storage: [Byte] = []
                storage.reserveCapacity(view.count)
                for index in view.indices { storage.append(view[index]) }
                return storage
            }
        } catch {
            throw .filesystem("cannot read \(relative): \(error)")
        }
    }

    /// Runs a program and returns what it printed; what it says when it fails is the error.
    @discardableResult
    private func run(_ program: Swift.String, _ arguments: [Swift.String], as step: Swift.String) throws(Institute.Error) -> Swift.String {
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(executable: program, arguments: arguments, stdout: .pipe, stderr: .pipe, directory: root)
            )
        } catch {
            throw .process("cannot \(step): \(program) did not start: \(error)")
        }
        let printed = Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
        guard output.status == .exited(code: 0) else {
            let said = Swift.String(decoding: output.stderr ?? [], as: Swift.UTF8.self)
            throw .process("cannot \(step):\n\(printed)\(said)")
        }
        return printed
    }
}
