import Command
import Institute_Application
import Institute_Model
import Institute_Workspace_Application

await Command.main(Institute.Application.CLI.self, initial: .sync(.init()))
