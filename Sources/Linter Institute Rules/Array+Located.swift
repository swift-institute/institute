internal import Institute_Linter_Rule_Architecture
internal import Institute_Linter_Rule_Manifest
internal import Institute_Linter_Rule_Platform
public import Institute_Model
public import Lint

extension Array where Element == Lint.Rule.Configuration {
    public func located(in repository: Institute.Repository.Coordinate?) -> Self {
        let located: [Lint.Rule.ID: Lint.Rule] = [
            Lint.Rule.`upward layer edge`.id: .`upward layer edge`(in: repository),
            Lint.Rule.`libc import in composition`.id: .`libc import in composition`(in: repository),
            Lint.Rule.`top level type owner`.id: .`top level type owner`(in: repository),
            Lint.Rule.`claimed path owner`.id: .`claimed path owner`(in: repository),
            Lint.Rule.`capability before noun`.id: .`capability before noun`(in: repository),
            Lint.Rule.`cross package type splice`.id: .`cross package type splice`(in: repository),
            Lint.Rule.`domain nesting depth`.id: .`domain nesting depth`(in: repository),
        ]
        return map { configuration in
            guard let rule = located[configuration.rule.id] else { return configuration }
            return Lint.Rule.Configuration(rule: rule, mode: configuration.mode, severity: configuration.severity)
        }
    }
}
