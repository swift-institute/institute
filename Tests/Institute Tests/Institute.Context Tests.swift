import File_System
import Testing

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Model
@testable import Institute_Pages

extension Institute.Context {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Institute.Context.Test {
    /// Materializes a hierarchy and an account root that are siblings, never
    /// nested, so nothing here can pass by resolving relative to the checkout.
    ///
    /// - Parameter roots: The canonical skill roots to materialize. The default
    ///   is all four; passing fewer models an account that clones fewer
    ///   repositories, which is every contributor outside the Institute.
    private static func fixture<Result>(
        roots: Set<Swift.String> = [
            "public-skill", "internal-skill", "engagement-skill", "rule-skill",
        ],
        _ body: (Institute.Context) throws -> Result
    ) throws -> Result {
        let base = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
        defer { try? MainFixtureFiles.remove(base) }
        try MainFixtureFiles.createDirectory(base)

        let temporary = try File.Directory(validating: base)
        let home = temporary[directory: "home"]
        let entry = temporary[directory: "entry"]
        let institute = entry[directory: "swift-institute"]
        let checkout = institute[directory: "Institute"]
        let publicSkills = institute[directory: "Skills"]
        let internalSkills = institute[directory: "Internal"][directory: "Skills"]
        let engagementSkills = institute[directory: "Engagement"][directory: "Skills"]
        let ruleSkills = entry[directory: "rule-institute"][directory: "Skills"]

        let sources = [
            (publicSkills, "public-skill"),
            (internalSkills, "internal-skill"),
            (engagementSkills, "engagement-skill"),
            (ruleSkills, "rule-skill"),
        ].filter { roots.contains($0.1) }

        try home.create.recursive()
        try checkout[directory: "Context"].create.recursive()
        try checkout[file: "Institute.json"].write.atomic("")
        for (root, name) in sources {
            let skill = root[directory: try File.Path.Component(name)]
            try skill.create.recursive()
            try skill[file: "SKILL.md"].write.atomic(
                "---\nname: \(name)\ndescription: fixture\n---\n\n# Fixture\n"
            )
        }

        return try body(
            Institute.Context(
                root: Institute.Root(checkout: checkout),
                home: File.Directory(try File.System.Canonical.resolve(home.path))
            )
        )
    }

    /// The installed projection directory for a fixture context.
    fileprivate static func projections(_ context: Institute.Context) -> File.Directory {
        context.home[directory: ".claude"][directory: "skills"]
    }

    /// The materialization contract's observable outcome: the entry at
    /// `path` resolves canonically to the same object as `target`,
    /// whatever mechanism materialized it (symbolic link, junction).
    /// Asserted instead of reading stored link text, per the Windows-lane
    /// adjudication of 2026-08-17 (provisional pending ratification).
    fileprivate static func resolves(
        _ path: File.Path,
        to target: File.Path
    ) throws -> Swift.Bool {
        try File.System.Canonical.resolve(path) == File.System.Canonical.resolve(target)
    }
}

extension Institute.Context.Test.Unit {
    @Test
    func `install materializes every canonical skill source`() throws {
        try Institute.Context.Test.fixture { context in
            try context.install()

            let skills = Institute.Context.Test.projections(context)
            let institute = context.entry[directory: "swift-institute"]

            #expect(try context.diagnostics().isEmpty)
            #expect(
                try Institute.Context.Test.resolves(
                    context.home[directory: ".agents"].path / "skills",
                    to: skills.path
                )
            )
            #expect(
                try Institute.Context.Test.resolves(
                    skills.path / "public-skill",
                    to: institute[directory: "Skills"].path / "public-skill"
                )
            )
            #expect(
                try Institute.Context.Test.resolves(
                    skills.path / "internal-skill",
                    to: institute[directory: "Internal"][directory: "Skills"].path
                        / "internal-skill"
                )
            )
            #expect(
                try Institute.Context.Test.resolves(
                    skills.path / "engagement-skill",
                    to: institute[directory: "Engagement"][directory: "Skills"].path
                        / "engagement-skill"
                )
            )
            #expect(
                try Institute.Context.Test.resolves(
                    skills.path / "rule-skill",
                    to: context.entry[directory: "rule-institute"][directory: "Skills"].path
                        / "rule-skill"
                )
            )
            // The projection is not reachable by walking down from the checkout,
            // which is the whole point: it is reachable from every root instead.
            #expect(!context.entry[directory: ".claude"].stat.exists)
            #expect(!context.entry[directory: ".agents"].stat.exists)
            #expect(!context.entry[file: "AGENTS.md"].stat.exists)
            #expect(!context.entry[file: "CLAUDE.md"].stat.exists)
        }
    }

    @Test
    func `install is idempotent`() throws {
        try Institute.Context.Test.fixture { context in
            try context.install()
            try context.install()

            #expect(try context.diagnostics().isEmpty)
        }
    }

    @Test(
        arguments: [
            "# Local instructions\n",
            "<!-- Generated by `institute context install`; edit the canonical template in institute-application/Context. -->\n# Hand-edited instructions\n",
        ]
    )
    func `install leaves workspace entry documents unchanged`(
        contents: Swift.String
    ) throws {
        try Institute.Context.Test.fixture { context in
            let agents = context.entry[file: "AGENTS.md"]
            let claude = context.entry[file: "CLAUDE.md"]
            try agents.write.atomic(contents)
            try claude.write.atomic(contents)

            try context.install()

            #expect(try context.diagnostics().isEmpty)
            #expect(
                try MainFixtureFiles.readStrictUTF8(agents.path.description) == contents
            )
            #expect(
                try MainFixtureFiles.readStrictUTF8(claude.path.description) == contents
            )
        }
    }

    @Test
    func `install removes a retired generated skill projection`() throws {
        try Institute.Context.Test.fixture { context in
            try context.install()
            let institute = context.entry[directory: "swift-institute"]
            let skill = institute[directory: "Skills"][directory: "public-skill"]
            try skill[file: "SKILL.md"].delete()

            try context.install()

            let skills = Institute.Context.Test.projections(context)
            #expect(!skills[file: "public-skill"].stat.exists)
            #expect(try context.diagnostics().isEmpty)
        }
    }

    @Test
    func `install preserves a retired skill link to an unmanaged target`() throws {
        try Institute.Context.Test.fixture { context in
            let institute = context.entry[directory: "swift-institute"]
            let source = institute[directory: "Skills"][directory: "public-skill"]
            try source[file: "SKILL.md"].delete()
            let unmanaged = context.home[directory: "unmanaged"]
            try unmanaged.create.recursive()
            try unmanaged[file: "notes.txt"].write.atomic("Keep this content.\n")
            let skills = Institute.Context.Test.projections(context)
            try skills.create.recursive()
            let projection = skills.path / "public-skill"
            try MainFixtureFiles.createSymbolicLink(
                atPath: projection.description,
                destinationPath: unmanaged.path.description
            )

            try context.install()

            #expect(try Institute.Context.Test.resolves(projection, to: unmanaged.path))
            #expect(
                try MainFixtureFiles.readStrictUTF8(unmanaged[file: "notes.txt"].path.description)
                    == "Keep this content.\n"
            )
        }
    }

    #if os(Windows)
        @Test
        func `install removes a retired generated skill copy`() throws {
            try Institute.Context.Test.fixture { context in
                let institute = context.entry[directory: "swift-institute"]
                let source = institute[directory: "Skills"][directory: "public-skill"]
                let skills = Institute.Context.Test.projections(context)
                let projection = skills[directory: "public-skill"]
                try projection.create.recursive()
                try projection[file: ".institute-materialization"].write.atomic(
                    source.path.description
                )
                try projection[file: "SKILL.md"].write.atomic("# Generated copy\n")
                try source[file: "SKILL.md"].delete()

                try context.install()

                #expect(!skills[file: "public-skill"].stat.exists)
                #expect(try context.diagnostics().isEmpty)
            }
        }

        @Test(arguments: [false, true])
        func `install preserves unmanaged or changed-marker retired skill directories`(
            changedMarker: Swift.Bool
        ) throws {
            try Institute.Context.Test.fixture { context in
                let institute = context.entry[directory: "swift-institute"]
                let source = institute[directory: "Skills"][directory: "public-skill"]
                try source[file: "SKILL.md"].delete()
                let skills = Institute.Context.Test.projections(context)
                let projection = skills[directory: "public-skill"]
                try projection.create.recursive()
                try projection[file: "notes.txt"].write.atomic("Keep this content.\n")
                let marker = projection[file: ".institute-materialization"]
                let changedTarget = context.home[directory: "unmanaged"].path.description
                if changedMarker {
                    try marker.write.atomic(changedTarget)
                }

                try context.install()

                #expect(
                    try MainFixtureFiles.readStrictUTF8(projection[file: "notes.txt"].path.description)
                        == "Keep this content.\n"
                )
                if changedMarker {
                    #expect(try MainFixtureFiles.readStrictUTF8(marker.path.description) == changedTarget)
                } else {
                    #expect(!marker.stat.exists)
                }
            }
        }
    #endif

}

extension Institute.Context.Test.`Edge Case` {
    @Test
    func `install rejects malformed canonical skill metadata before projecting`() throws {
        try Institute.Context.Test.fixture { context in
            let institute = context.entry[directory: "swift-institute"]
            let publicSkills = institute[directory: "Skills"]
            let publicSkill = publicSkills[directory: "public-skill"]
            let skill = publicSkill[file: "SKILL.md"]
            try skill.write.atomic(
                """
                ---
                name: public-skill
                description: fixture
                layer: implementation
                ---
                # Fixture
                """
            )

            #expect(throws: Institute.Error.self) {
                try context.install()
            }
            #expect(!context.home[directory: ".claude"].stat.exists)
        }
    }

    @Test
    func `install migrates the checkout-local Codex skill link`() throws {
        try Institute.Context.Test.fixture { context in
            let legacy = context.entry[directory: ".agents"]
            try legacy.create.recursive()
            try Institute.Context.Test.projections(context).create.recursive()
            try MainFixtureFiles.createSymbolicLink(
                atPath: (legacy.path / "skills").description,
                destinationPath: Institute.Context.Test.projections(context).path.description
            )

            try context.install()

            #expect(try context.diagnostics().isEmpty)
            #expect(!legacy[file: "skills"].stat.exists)
            #expect(
                try Institute.Context.Test.resolves(
                    context.home[directory: ".agents"].path / "skills",
                    to: Institute.Context.Test.projections(context).path
                )
            )
        }
    }

    @Test
    func `install refuses a divergent checkout-local Codex link`() throws {
        try Institute.Context.Test.fixture { context in
            let legacy = context.entry[directory: ".agents"]
            try legacy.create.recursive()
            try MainFixtureFiles.createSymbolicLink(atPath: (legacy.path / "skills").description, destinationPath: context.home[directory: "elsewhere"].path.description)

            #expect(
                try context.diagnostics().contains {
                    $0.contains("retired context link has the wrong target")
                }
            )
            #expect(throws: Institute.Error.self) {
                try context.install()
            }
            #expect(!context.home[directory: ".claude"].stat.exists)
            #expect(!context.home[directory: ".agents"].stat.exists)
        }
    }

    @Test
    func `install preserves a user alias into a canonical skill root`() throws {
        try Institute.Context.Test.fixture { context in
            try context.install()
            let institute = context.entry[directory: "swift-institute"]
            let canonical = institute[directory: "Skills"].path / "public-skill"
            let alias = Institute.Context.Test.projections(context).path / "user-alias"
            try MainFixtureFiles.createSymbolicLink(atPath: alias.description, destinationPath: canonical.description)

            try context.install()

            #expect(try Institute.Context.Test.resolves(alias, to: canonical))
            #expect(try context.diagnostics().isEmpty)
        }
    }

    @Test
    func `install projects the canonical roots this account carries and skips the rest`() throws {
        try Institute.Context.Test.fixture(roots: ["public-skill"]) { context in
            try context.install()

            let skills = Institute.Context.Test.projections(context)
            #expect(skills[file: "public-skill"].stat.exists)
            #expect(!skills[file: "internal-skill"].stat.exists)
            #expect(!skills[file: "engagement-skill"].stat.exists)
            #expect(!skills[file: "rule-skill"].stat.exists)
            #expect(try context.diagnostics().isEmpty)
        }
    }

    @Test
    func `install leaves a projection into a root it does not own alone`() throws {
        try Institute.Context.Test.fixture(roots: ["public-skill"]) { context in
            try context.install()

            // A skill installed from somewhere outside every canonical Institute
            // root — a personal dotfiles checkout, say. Institute does not know
            // it exists and must never remove it.
            let foreign = context.home[directory: "elsewhere"][directory: "foreign-skill"]
            try foreign.create.recursive()
            let alias = Institute.Context.Test.projections(context).path / "foreign-skill"
            try MainFixtureFiles.createSymbolicLink(atPath: alias.description, destinationPath: foreign.path.description)

            try context.install()

            #expect(try Institute.Context.Test.resolves(alias, to: foreign.path))
            #expect(try context.diagnostics().isEmpty)
        }
    }
}

// MARK: - An install that projects nothing is not a success (#58)

extension Institute.Context.Test.`Edge Case` {
    /// The defect this guards: a hierarchy carrying no canonical skill root
    /// printed `installed and verified`, exited 0, and wrote no projection —
    /// a report indistinguishable from a complete install.
    @Test
    func `install with no canonical skill root fails and names every root it looked for`() throws {
        try Institute.Context.Test.fixture(roots: []) { context in
            #expect(throws: Institute.Error.self) {
                try context.install()
            }

            do {
                try context.install()
                Issue.record("install reported success with no canonical skill root")
            } catch let error as Institute.Error {
                let message = "\(error)"
                #expect(message.contains("no canonical skill root resolved"))
                // Naming the roots is the difference between a failure a
                // contributor can act on and one they can only report.
                #if os(Windows)
                    let separator = "\\"
                #else
                    let separator = "/"
                #endif
                #expect(message.contains("swift-institute\(separator)Skills"))
                #expect(message.contains("rule-institute\(separator)Skills"))
            }
        }
    }

    @Test
    func `check reports a hierarchy that projects nothing rather than calling it current`() throws {
        try Institute.Context.Test.fixture(roots: []) { context in
            let diagnostics = try context.diagnostics()

            #expect(diagnostics.contains { $0.contains("no canonical skill root resolved") })
        }
    }

    /// The positive control for both assertions above. Without it, a passing
    /// negative control proves only that these fixtures fail — which they
    /// would also do if the fixture itself were broken.
    @Test
    func `install reports the count and the roots it projected from`() throws {
        try Institute.Context.Test.fixture(roots: ["public-skill", "rule-skill"]) { context in
            let projection = try context.install()

            #expect(projection.skills == ["public-skill", "rule-skill"])
            #expect(projection.sources.count == 2)
            #expect(projection.summary.contains("2 skill(s) from 2 root(s)"))
        }
    }
}
