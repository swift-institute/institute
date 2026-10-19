extension Source.Finding: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        let severity: Swift.String
        switch value.diagnostic.severity {
        case .error: severity = "error"
        case .warning: severity = "warning"
        case .note: severity = "note"
        case .remark: severity = "remark"
        }
        return [
            "rule": value.rule.json,
            "fileID": value.diagnostic.location.fileID.json,
            "filePath": value.diagnostic.location.filePath.json,
            "line": value.diagnostic.location.line.description.json,
            "column": value.diagnostic.location.column.description.json,
            "severity": severity.json,
            "identifier": value.diagnostic.identifier.json,
            "message": value.diagnostic.message.json,
            "repair": value.repair.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        let expected: Set<Swift.String> = [
            "rule", "fileID", "filePath", "line", "column", "severity", "identifier", "message",
            "repair",
        ]
        guard Set(object.keys) == expected else {
            throw .typeMismatch(expected: "source finding keys", got: "foreign keys")
        }
        func required(_ key: Swift.String) throws(JSON.Error) -> JSON {
            guard let value = object[key] else { throw .missingKey(key) }
            return value
        }
        let severity: Diagnostic.Severity
        switch try Swift.String(json: required("severity")) {
        case "error": severity = .error
        case "warning": severity = .warning
        case "note": severity = .note
        case "remark": severity = .remark
        default: throw .typeMismatch(expected: "diagnostic severity", got: "unknown")
        }
        guard let line = Swift.Int(try Swift.String(json: required("line"))),
            let column = Swift.Int(try Swift.String(json: required("column")))
        else {
            throw .typeMismatch(expected: "source location", got: "invalid")
        }
        return try Self(
            rule: Source.Rule.ID(json: required("rule")),
            diagnostic: .init(
                location: .init(
                    fileID: Swift.String(json: required("fileID")),
                    filePath: Swift.String?(json: required("filePath")),
                    line: line,
                    column: column
                ),
                severity: severity,
                identifier: Swift.String(json: required("identifier")),
                message: Swift.String(json: required("message"))
            ),
            repair: Source.Repair.Capability(json: required("repair"))
        )
    }
}
