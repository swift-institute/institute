import Console
public import Institute_CI_Model
import Institute_CI_Validation
public import Institute_Model

import struct Swift.String

extension Institute.CI.Command {
    static func control(_ arguments: [Swift.String]) {
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

        let run = Institute.CI.Control.Validation.run(
            repository: repository,
            root: root
        )
        if !run.tsv.isEmpty { print(run.tsv) }
        if let defect = run.defect {
            Console.Output.error("institute ci: control validate: \(defect.message)")
            terminate(2)
        }
        if !run.findings.isEmpty { terminate(1) }
    }
}
