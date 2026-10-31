public import Lint

extension Lint {

    /// Apple-only frameworks, and the targets allowed to import them.
    ///
    /// A framework is imported by its adapter: a target whose name ends in the framework's own name, as
    /// `Reader PDFKit` imports PDFKit. A framework with owners is imported only by an adapter whose name opens
    /// with one of them, so a second package cannot grow a second adapter for it.
    public enum Framework {}
}

extension Lint.Framework {

    /// The frameworks that exist only on Apple platforms.
    package static let apple: Swift::Set<Swift::String> = [
        "ActivityKit", "AppIntents", "AppKit", "AVFoundation", "BackgroundTasks", "CloudKit", "Combine", "Contacts",
        "CoreData", "CoreGraphics", "CoreImage", "CoreLocation", "CoreServices", "CoreSpotlight", "CoreText",
        "CoreTransferable", "CryptoKit", "EventKit", "FoundationModels", "ImageIO", "LocalAuthentication", "MapKit",
        "Network", "OSLog", "os", "PDFKit", "Photos", "PhotosUI", "Quartz", "QuickLook", "QuickLookThumbnailing",
        "Security", "ServiceManagement", "StoreKit", "SwiftData", "SwiftUI", "UIKit", "UniformTypeIdentifiers",
        "UserNotifications", "Vision", "VisionKit", "WebKit", "WidgetKit",
    ]

    /// What an adapter named for a framework may import beside it.
    package static let companions: [Swift::String: Swift::Set<Swift::String>] = [
        "PDFKit": ["AppKit", "CoreGraphics", "UIKit"],
        "Vision": ["CoreGraphics", "CoreImage", "ImageIO"],
        "WebKit": ["AppKit", "Network", "SwiftUI", "UIKit"],
        "SwiftUI": [
            "AppIntents", "AppKit", "CoreTransferable", "PDFKit", "Quartz", "QuickLook", "UIKit",
            "UniformTypeIdentifiers", "VisionKit",
        ],
        "AppKit": ["CoreGraphics", "ServiceManagement", "UniformTypeIdentifiers"],
        "UIKit": ["CoreGraphics", "UniformTypeIdentifiers"],
        "AppIntents": ["CoreSpotlight"],
    ]

    /// The frameworks whose adapters belong to one family, by the first word of the adapter's name.
    package static let owners: [Swift::String: Swift::Set<Swift::String>] = [
        "PDFKit": ["Reader"],
        "Vision": ["Reader"],
        "FoundationModels": ["Reader"],
        "WebKit": ["Affairs"],
        "CloudKit": ["Affairs", "SQLite"],
    ]

    /// What an app's host, outside any package target, may import.
    package static let host: Swift::Set<Swift::String> = [
        "AppIntents", "AppKit", "BackgroundTasks", "CoreSpotlight", "ServiceManagement", "SwiftUI", "UIKit",
        "UniformTypeIdentifiers", "UserNotifications",
    ]

    /// Whether a file at `path` may import `module`.
    package static func admits(_ module: Swift::String, at path: Lint.Source.Path) -> Swift::Bool {
        guard apple.contains(module) else { return true }
        let directories = path.underlying.split(separator: "/", omittingEmptySubsequences: true).dropLast()
        if directories.first == "Hosts" { return host.contains(module) }
        guard let target = Lint.Framework.target(of: path) else { return false }
        let words = target.split(separator: " ").map(Swift::String.init)
        guard words.count > 1, let adapter = words.last else { return false }
        if adapter == module {
            guard let allowed = owners[module] else { return true }
            return allowed.contains(words[0])
        }
        return companions[adapter]?.contains(module) ?? false
    }

    /// The target a file belongs to, read as an adapter: an adapter's test target counts as the adapter.
    package static func target(of path: Lint.Source.Path) -> Swift::String? {
        let components = path.underlying.split(separator: "/", omittingEmptySubsequences: true)
        let directories = components.dropLast()
        guard let anchor = directories.firstIndex(where: { $0 == "Sources" || $0 == "Tests" }) else { return nil }
        let index = directories.index(after: anchor)
        guard index < directories.endIndex else { return nil }
        let name = Swift::String(directories[index])
        guard directories[anchor] == "Tests", name.hasSuffix(" Tests") else { return name }
        return Swift::String(name.dropLast(" Tests".count))
    }
}
