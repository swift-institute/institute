public import Command
public import Command_Schema
import Console
import Institute_Doctor
public import Institute_Inventory
public import Institute_Model
import Institute_Pages
import Process

extension Institute.Inventory.Command {
    /// `institute inventory pages` — enumerate Pages posture over the
    /// effective selection.
    public struct Pages: Sendable, Command_Schema.Command.`Protocol` {
        public init() {}

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "pages", abstract: "Enumerate Pages posture over the selection.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init(nodes: [])
        }

        public mutating func run() async throws(Institute.Error) {
            let root = try Institute.Inventory.Command.root()
            let configuration = try Institute.Configuration.load(at: root.checkout)
            let selection = try Institute.Selection.effective(
                at: root.checkout,
                in: configuration
            )
            let inventory = await Institute.Pages.enumerate(root: root, selection: selection)
            print(inventory.canonical)
            let digest = inventory.digest
            let counts = inventory.nonCanonicalCounts
            let countsDescription =
                counts.isEmpty
                ? "0 non-canonical"
                : counts.sorted { $0.key < $1.key }.map { "\($1) \($0)" }.joined(
                    separator: ", "
                )
                    + " non-canonical"
            let summaryLine =
                "inventory pages: \(inventory.repositories.count) repositories, "
                + "\(countsDescription)"
                + ", digest \(digest)" + "\n"
            Console.Output.error(summaryLine)
            Process.Exit.normal(inventory.isFullyCanonical ? 0 : 1)
        }
    }
}
