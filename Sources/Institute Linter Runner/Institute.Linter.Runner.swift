import Environment
import Institute_Model
import Linter
import Linter_Institute_Rules
import Linter_Primitives_Rules
import Linter_Standards_Rules

@main
enum Runner {
    static func main() {
        let repository = Environment.read(Institute.Repository.Coordinate.variable)
            .flatMap(Institute.Repository.Coordinate.init)
        Lint.run(bundles: [
            "app": Lint.Rule.Bundle.app.located(in: repository),
            "institute": Lint.Rule.Bundle.institute.located(in: repository),
            "primitives": Lint.Rule.Bundle.primitives.located(in: repository),
            "standards": Lint.Rule.Bundle.standards.located(in: repository),
        ])
    }
}
