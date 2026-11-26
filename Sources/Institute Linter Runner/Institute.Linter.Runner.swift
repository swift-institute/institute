import Console
import Environment
import GitHub_Standard
import Institute_Linter_Catalog
import Institute_Model
import Linter
import Linter_Institute_Rules
import Linter_Primitives_Rules
import Linter_Standards_Rules
import Process

@main
enum Runner {
    static func main() {
        let repository = Environment.read(Institute.Repository.Coordinate.variable)
            .flatMap { GitHub.Repository.Slug($0) }
            .flatMap(Institute.Repository.Coordinate.init)
        let bundles: [Lint.Rule.Bundle.Baked: [Lint.Rule.Configuration]] = [
            "institute": Lint.Rule.Bundle.institute.located(in: repository),
            "primitives": Lint.Rule.Bundle.primitives.located(in: repository),
            "standards": Lint.Rule.Bundle.standards.located(in: repository),
        ]
        let arguments = [Swift.String](Swift.CommandLine.arguments.dropFirst())
        guard arguments.first == Institute.Catalog.option else {
            Lint.run(bundles: bundles)
            return
        }
        do throws(Institute.Error) {
            let request = try Institute.Catalog.Request(arguments: [Swift.String](arguments.dropFirst()))
            guard let bundle = bundles[.init(request.bundle)] else {
                throw .configuration("this runner does not bake bundle '\(request.bundle)'")
            }
            let catalog = Institute.Catalog(bundle)
            print(catalog.summary(of: request.bundle, for: request.kind))
            print("")
            for line in catalog.lines(for: request.kind) { print(line) }
        } catch {
            Console.Output.error("\(error)\n")
            Process.Exit.normal(1)
        }
    }
}
