public import Command
public import Command_Schema
import Console
import GitHub_App
public import Institute_GitHub
public import Institute_Model
import Paths

extension Institute.GitHub.Command {
    /// `institute github token` — mint one installation token.
    ///
    /// Minting a credential has nothing to do with an Institute checkout,
    /// so no root is resolved: the command works from any directory on the
    /// machine, which is what makes `GH_TOKEN=$(institute github token
    /// --org X)` usable in a lane standing inside a package.
    public struct Token: Sendable, Command_Schema.Command.`Protocol` {
        public var organization: Swift.String
        public var application: Swift.String
        public var permissions: [Swift.String]
        public var applicationIdentity: Swift.String
        public var keyPath: Swift.String

        public init(
            organization: Swift.String = "",
            application: Swift.String = "swift-institute-bot",
            permissions: [Swift.String] = [],
            applicationIdentity: Swift.String = "",
            keyPath: Swift.String = ""
        ) {
            self.organization = organization
            self.application = application
            self.permissions = permissions
            self.applicationIdentity = applicationIdentity
            self.keyPath = keyPath
        }

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "token", abstract: "Mint one GitHub App installation token.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Option(
                    \.organization,
                    name: .long(.literal("org")),
                    placeholder: "organization",
                    help: .init(
                        abstract:
                            "GitHub organization whose installation token is minted."
                    )
                )
                Command_Schema.Command.Option(
                    \.application,
                    name: .long(.literal("app")),
                    placeholder: "bot",
                    help: .init(
                        abstract:
                            "GitHub App to mint as: the login-keychain item of that service holds its "
                            + "key and identity; defaults to swift-institute-bot."
                    )
                )
                Command_Schema.Command.Option<Self, Swift.String>.Many(
                    \.permissions,
                    name: .long(.literal("permission")),
                    placeholder: "name=level",
                    help: .init(
                        abstract:
                            "Narrow the minted token to this permission (repeatable). "
                            + "Without one the token carries the installation's whole grant."
                    )
                )
                Command_Schema.Command.Option(
                    \.applicationIdentity,
                    name: .long(.literal("app-id")),
                    placeholder: "identity",
                    help: .init(
                        abstract:
                            "GitHub App identity to mint as; defaults to GITHUB_APP_ID, then "
                            + "the keychain item's account."
                    )
                )
                Command_Schema.Command.Option(
                    \.keyPath,
                    name: .long(.literal("key")),
                    placeholder: "path",
                    help: .init(
                        abstract:
                            "Signing key file to use; defaults to GITHUB_APP_PRIVATE_KEY_PATH, then "
                            + "the login-keychain item named by --app."
                    )
                )
            }
        }

        public mutating func validate() throws(Command_Schema.Command.Error) {
            guard !organization.isEmpty else {
                throw .validationFailed(reason: "github token requires --org.")
            }
            guard !application.isEmpty else {
                throw .validationFailed(reason: "github token requires a non-empty --app.")
            }
        }

        public mutating func run() async throws(Institute.Error) {
            let name: Paths.Path.Component
            do throws(Paths.Path.Component.Error) {
                name = try .init(application)
            } catch {
                throw .configuration("github token: --app \(application) is not a usable name")
            }
            let app: GitHub_App.GitHub.App
            let result: (token: GitHub_App.GitHub.App.Token, cached: Swift.Bool)
            do throws(GitHub_App.GitHub.App.Error) {
                app = try .resolve(
                    identity: applicationIdentity.isEmpty ? nil : applicationIdentity,
                    keyPath: keyPath.isEmpty ? nil : keyPath,
                    // The bot's name: the login-keychain service holding its
                    // key and identity, and its token cache under ~/.config.
                    name: name
                )
                result = try app.token(
                    organization: organization,
                    permissions: try permissions.map { value throws(GitHub_App.GitHub.App.Error) in
                        try .init(argument: value)
                    }
                )
            } catch {
                throw .configuration("github token: \(error)")
            }
            // The token is the whole of stdout, with no trailing commentary,
            // so command substitution captures a credential and nothing else.
            // Everything a human wants to know goes to stderr, where it cannot
            // end up inside an Authorization header.
            print(result.token.value)
            Console.Output.error(
                "github token: \(result.cached ? "cache hit" : "minted") for \(organization)\n"
            )
        }
    }
}

extension Institute.GitHub {
    /// `institute github` — the GitHub credential verbs.
    public enum Command: Sendable, Command_Schema.Command.`Protocol` {
        case token(Token)

        public static var configuration: Command_Schema.Command.Configuration {
            .init(name: "github", abstract: "Mint GitHub App installation credentials.")
        }

        public static var schema: Command_Schema.Command.Schema.Definition<Self> {
            .init {
                Command_Schema.Command.Subcommand.Group {
                    Command_Schema.Command.Subcommand.Case(
                        "token",
                        help: .init(abstract: "Mint one GitHub App installation token."),
                        initial: { .init() },
                        map: Self.token
                    )
                }
            }
        }

        public mutating func run() async throws(Institute.Error) {
            switch self {
            case .token(var command):
                try await command.run()
                self = .token(command)
            }
        }
    }
}
