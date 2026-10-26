import Command
import Institute_Application
import Institute_Model

await Command.main(Institute.Application.CLI.self, initial: .install(.init()))
