import Foundation

extension Institute.Application.CI {
    static func control(_ arguments: [String]) {
        guard arguments.first == "validate" else {
            refuse("control requires validate")
        }
        let rest = Array(arguments.dropFirst())
        let repository = value("--repository", in: rest)
        let root = value("--root", in: rest)
        guard !repository.isEmpty, !root.isEmpty else {
            refuse(
                "control validate requires --repository <owner/name> --root <candidate-directory>"
            )
        }

        let run = ContinuousIntegration.Control.Validation.run(
            repository: repository,
            root: root
        )
        if !run.tsv.isEmpty { print(run.tsv) }
        if let defect = run.defect {
            FileHandle.standardError.write(
                Data("institute ci: control validate: \(defect.message)\n".utf8)
            )
            terminate(2)
        }
        if !run.findings.isEmpty { terminate(1) }
    }
}
