import Byte
public import Git_Foundation
public import Institute_Model

extension Institute.Planner.Adoption {
    /// Writes the adoption into the consumer checkout at `checkout` and
    /// records it as one commit there. Refuses unless the checkout is a
    /// clean `main`, so the commit holds the adoption and nothing else.
    /// Never pushes.
    public func record(
        at checkout: Swift.String,
        git: Git.Client = .init()
    ) throws(Institute.Planner.Error) -> Git.Object.ID {
        let isRepository: Swift.Bool
        do throws(Git.Client.Error) {
            isRepository = try git.repository(at: checkout)
        } catch {
            throw .local("cannot read \(checkout): \(error)")
        }
        guard isRepository else { throw .local("\(checkout) is not a git checkout") }
        try require(checkout, git: git)
        try Institute.Planner.write(
            [Byte](utf8: pin),
            to: Institute.Planner.path("\(checkout)/\(Institute.Planner.Consumer.pin)")
        )
        try Institute.Planner.write(
            [Byte](utf8: ledger),
            to: Institute.Planner.path("\(checkout)/\(Institute.Planner.Consumer.ledger)")
        )
        do throws(Git.Client.Error) {
            try git.add(Self.paths, at: checkout)
            return try git.commit(message: message, at: checkout)
        } catch {
            throw .local("cannot commit the adoption in \(checkout): \(error)")
        }
    }

    /// The command a human runs, after their go, to publish the commit.
    public static func push(_ checkout: Swift.String) -> Swift.String {
        "git -C '\(checkout)' push origin main"
    }

    private func require(_ checkout: Swift.String, git: Git.Client) throws(Institute.Planner.Error) {
        let branch: Swift.String
        let changes: Swift.Int
        do throws(Git.Client.Error) {
            branch = try git.branch(at: checkout)
            changes = try git.status(at: checkout).count
        } catch {
            throw .local("cannot read \(checkout): \(error)")
        }
        guard branch == "main" else {
            throw .local("\(checkout) is on \(branch.isEmpty ? "a detached HEAD" : branch), not main")
        }
        guard changes == 0 else {
            throw .local("\(checkout) has \(changes) uncommitted changes; adoption commits only its own")
        }
    }
}
