import Command
import Institute_Command
import Institute_Model

await Command.main(Institute.Application.CLI.self, initial: .install(.init()))
