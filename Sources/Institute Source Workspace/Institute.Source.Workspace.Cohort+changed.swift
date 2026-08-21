public import Async_Fanout
public import Git_Foundation
public import Institute_Model
public import Source_Measurement

extension Institute.Source.Workspace.Cohort {
    public func changed(
        using git: Git.Client = .init(),
        jobs: Swift.Int? = nil
    ) async -> Institute.Source.Workspace.Selection {
        let results = await Async.Fanout(jobs: jobs).map(measurable) { row in
            Self.change(row, using: git)
        }
        var rows: [Institute.Source.Workspace.Row] = []
        var reasons: [Source.Reason] = []
        for result in results {
            switch result {
            case .success(.some(let row)): rows.append(row)
            case .success(.none): break
            case .failure(let reason): reasons.append(reason)
            }
        }
        return .init(rows: rows, reasons: reasons)
    }

    private static func change(
        _ row: Institute.Source.Workspace.Row,
        using git: Git.Client
    ) -> Result<Institute.Source.Workspace.Row?, Source.Reason> {
        do throws(Git.Client.Error) {
            guard try git.repository(at: row.directory) else {
                return .failure(
                    .init(code: "git-repository", detail: "\(row.identity): not a Git repository")
                )
            }
            if !(try git.status(at: row.directory)).isEmpty { return .success(row) }
            let branch = try git.branch(at: row.directory)
            guard !branch.isEmpty else {
                return .failure(
                    .init(code: "git-branch", detail: "\(row.identity): detached or unknown branch")
                )
            }
            let upstream = try git.upstream(branch, at: row.directory)
            guard !upstream.isEmpty else {
                return .failure(
                    .init(code: "git-upstream", detail: "\(row.identity): no tracked upstream")
                )
            }
            return .success(
                try git.count("\(upstream)..HEAD", at: row.directory) > 0 ? row : nil
            )
        } catch {
            return .failure(
                .init(code: "git-scope", detail: "\(row.identity): \(error)")
            )
        }
    }
}
