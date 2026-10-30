import Institute_Model
import Institute_Version
import Synchronization

/// An in-memory organization behind an `Institute.Version.Client`: its
/// repositories, `main` heads, tags, CI verdicts and ancestry, and a record
/// of every tag creation the sweep asked for.
final class Fixture: Sendable {
    struct State {
        var subjects: [Institute.Version.Subject] = []
        var heads: [Institute.Repository.Coordinate: Swift.String] = [:]
        var tags: [Institute.Repository.Coordinate: [Institute.Version.Tag]] = [:]
        /// Keyed by commit; a commit without an entry has no `main` run.
        var gates: [Swift.String: Institute.Version.Gate] = [:]
        /// Keyed by "base...head"; an absent pair is `ahead`.
        var relations: [Swift.String: Institute.Version.Relation] = [:]
        /// Repositories whose head read fails.
        var broken: Swift.Set<Institute.Repository.Coordinate> = []
        /// A tag another writer creates just before the sweep's own write:
        /// the commit it names.
        var racer: Swift.String? = nil
        var creations: [(Institute.Repository.Coordinate, Institute.Version.Tag)] = []
    }

    let state: Mutex<State>

    init(_ state: State = .init()) {
        self.state = Mutex(state)
    }

    static let organization = Institute.Organization.`swift-atoms`

    static func repository(_ name: Swift.String) -> Institute.Repository.Coordinate {
        .init(organization: organization, name: name)
    }

    /// A 40-hex commit id derived from a short label.
    static func commit(_ label: Swift.Character) -> Swift.String {
        Swift.String(repeating: label, count: 40)
    }

    /// Adds a public, unarchived repository with `main` at `head`.
    func add(
        _ name: Swift.String,
        head: Swift.String?,
        tags: [Institute.Version.Tag] = [],
        archived: Swift.Bool = false,
        private: Swift.Bool = false
    ) {
        let repository = Self.repository(name)
        state.withLock {
            $0.subjects.append(.init(repository: repository, archived: archived, private: `private`))
            $0.heads[repository] = head
            $0.tags[repository] = tags
        }
    }

    var creations: [(Institute.Repository.Coordinate, Institute.Version.Tag)] {
        state.withLock { $0.creations }
    }

    var client: Institute.Version.Client {
        .init(
            subjects: { organization throws(Institute.Version.Error) in
                self.state.withLock { state in state.subjects.filter { $0.repository.organization == organization } }
            },
            head: { repository throws(Institute.Version.Error) in
                let (broken, head) = self.state.withLock { ($0.broken.contains(repository), $0.heads[repository]) }
                if broken { throw .status(method: "GET", path: "/repos/\(repository.description)", status: 500) }
                return head
            },
            tags: { repository, prefix throws(Institute.Version.Error) in
                self.state.withLock { ($0.tags[repository] ?? []).filter { $0.name.hasPrefix(prefix) } }
            },
            gate: { _, commit throws(Institute.Version.Error) in
                self.state.withLock { $0.gates[commit] ?? .absent }
            },
            relation: { _, base, head throws(Institute.Version.Error) in
                if base == head { return .identical }
                return self.state.withLock { $0.relations["\(base)...\(head)"] ?? .ahead }
            },
            create: { repository, tag throws(Institute.Version.Error) in
                self.state.withLock { state in
                    if let racer = state.racer {
                        state.racer = nil
                        state.tags[repository, default: []].append(.init(name: tag.name, commit: racer))
                    }
                    if let existing = state.tags[repository]?.first(where: { $0.name == tag.name }) {
                        return .exists(commit: existing.commit)
                    }
                    state.creations.append((repository, tag))
                    state.tags[repository, default: []].append(tag)
                    return .created
                }
            }
        )
    }
}
