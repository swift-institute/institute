public import Institute_Model
public import Lint
internal import Institute_Linter_Rule_Architecture
internal import Institute_Linter_Rule_Manifest
internal import Institute_Linter_Rule_Platform

extension Array where Element == Lint.Rule.Configuration {
    public func located(in repository: Institute.Repository.Coordinate?) -> Self {
        let located: [Lint.Rule.ID: Lint.Rule] = [
            Lint.Rule.`upward layer edge`.id: .`upward layer edge`(in: repository),
            Lint.Rule.`libc import in composition`.id: .`libc import in composition`(in: repository),
            Lint.Rule.`top level type owner`.id: .`top level type owner`(in: repository),
        ]
        return map { configuration in
            guard let rule = located[configuration.rule.id] else { return configuration }
            return Lint.Rule.Configuration(rule: rule, mode: configuration.mode, severity: configuration.severity)
        }
    }
}
