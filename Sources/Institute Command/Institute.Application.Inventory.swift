public import Command
public import Command_Schema
import Console
import Environment
import File_System
import Institute_Inventory
public import Institute_Model

extension Institute.Application {
    /// `institute inventory` — every Swift package under a directory, its
    /// targets, imports, declared types and the places those types are
    /// named, as one JSON table per file, for deciding from data where a
    /// type, a target, a product, a repository or an organization splits.
    public struct Inventory: Sendable, Command_Schema::Command.`Protocol` {
        public var root: Swift.String
        public var output: Swift.String
        public var exclude: [Swift.String]

        public init(root: Swift.String = "", output: Swift.String = "", exclude: [Swift.String] = []) {
            self.root = root
            self.output = output
            self.exclude = exclude
        }
    }
}

extension Institute.Application.Inventory {
    public static var configuration: Command_Schema::Command.Configuration {
        .init(
            name: "inventory",
            abstract: "Write the packages, targets, types and type references under a directory as JSON tables.",
            discussion: """
                Every directory under --root holding a Package.swift is a package; .build, .swiftpm, \
                checkouts, DerivedData, .claude, node_modules and each --exclude prefix (relative to \
                the root) are not walked. Manifests are evaluated with swift package dump-package in a \
                scratch directory, so no working tree changes; a manifest that does not evaluate goes \
                to failures.json and the run goes on. Sources are read by syntax alone. Each table is \
                one JSON array of flat objects in --output:
                repositories.json: path, origin (owner/name), organization, layer, head, dirty.
                packages.json: package (the key other tables use), repository, name, nested, tools_version, targets, products.
                package_dependencies.json: package, identity, kind, location, requirement, traits.
                traits.json: package, name, enables.
                products.json: package, name, kind, library_type, targets.
                targets.json: package, name, kind, path, files, lines.
                target_dependencies.json: package, target, kind, name, dependency_package, platforms, traits.
                imports.json: package, target, module, access, exported, attributes, condition, files.
                types.json: id, package, target, path, name, kind, access, generic_parameters, associated_types, cases, \
                stored_properties, inherits, aliased, in_extension, module_selector, condition, file, line.
                extensions.json: package, target, extended, module_selector, conformances, where_clause, \
                public_members, nested_types, condition, file, line.
                members.json: package, target, owner, in_extension, kind, name, access, static, mutating, async, \
                throws, generic_parameters, parameters, parameter_types, result, stored, condition, file, line; \
                one row per function, initializer, property, subscript and enum case that is not local \
                to a body; kind is func, init, var, let, subscript or case; name is spelled as a \
                reference, parse(_:from:); throws is empty, throws, rethrows or the written error type.
                member_uses.json: package, target, name, count; a member access x.name or .name counts \
                under name, a call under name(a:_:) with the labels of the call site; by syntax \
                alone, for matching by name; names that start uppercase are left to references.json.
                references.json: package, target, from, written, position, generic_parameter, count; \
                position is stored, parameter, return, inheritance, extension, constraint, alias, \
                generic_argument, case, body or other.
                resolved_references.json: package, target, from, position, type_path, type_target, \
                type_package, ambiguous, count; a written chain resolved lexically against the types \
                of the target and of every target it reaches through its dependencies.
                unresolved_references.json: package, target, written, count.
                failures.json: package, reason.
                Load a table into SQLite with: sqlite3 inventory.db "create table types as select \
                value ->> 'id' as id, value ->> 'path' as path, value ->> 'target' as target from \
                json_each(readfile('types.json'))"
                """
        )
    }

    public static var schema: Command_Schema::Command.Schema.Definition<Self> {
        .init {
            Command_Schema::Command.Option(
                \.root,
                name: .long(.literal("root")),
                placeholder: "directory",
                help: .init(abstract: "The directory whose packages are read.")
            )
            Command_Schema::Command.Option(
                \.output,
                name: .long(.literal("output")),
                placeholder: "directory",
                help: .init(abstract: "The directory the JSON tables are written into.")
            )
            Command_Schema::Command.Option.Many(
                \.exclude,
                name: .long(.literal("exclude")),
                placeholder: "path-prefix",
                help: .init(abstract: "A directory, relative to the root, that is not walked; repeatable.")
            )
        }
    }

    public mutating func validate() throws(Command_Schema::Command.Error) {
        guard !root.isEmpty, !output.isEmpty else {
            throw .validationFailed(reason: "inventory needs --root and --output")
        }
    }

    public mutating func run() async throws(Institute.Error) {
        let path: File.Path
        do throws(File.Path.Error) {
            path = try File.Path(root)
        } catch {
            throw .filesystem("--root \(root) is not a path: \(error)")
        }
        let resolved: Swift.String
        do throws(File.System.Canonical.Error) {
            resolved = "\(try File.System.Canonical.resolve(path))"
        } catch {
            throw .filesystem("cannot resolve --root \(root): \(error)")
        }
        // WHY: git status takes no optional index lock, so a checkout another
        // process is working in is left alone.
        do throws(Kernel.Environment.Error) {
            try Environment.write("GIT_OPTIONAL_LOCKS", to: "0")
        } catch {}
        let started = ContinuousClock.now
        let summary = try await Institute.Inventory.run(
            .init(root: resolved, output: output, excluded: exclude),
            progress: { Console.Output.error("institute inventory: \($0)\n") }
        )
        let elapsed = started.duration(to: ContinuousClock.now).components.seconds
        Console.Output.error("institute inventory: \(summary.description); \(elapsed) s; tables in \(output)\n")
    }
}
