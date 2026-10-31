public import Lint

extension Lint.Rule.Bundle {

    public static func sql(exceptions: Lint.SQL.Exceptions) -> [Lint.Rule.Configuration] {
        [
            .enable(.`sql label`),
            .enable(.`sql string`),
            .enable(.`sql registry`(exceptions: exceptions)),
            .enable(.`sql fragment`),
            .enable(.`sql edge`),
            .enable(.`grdb import`),
            .enable(.`database closure type`),
        ]
    }
}
