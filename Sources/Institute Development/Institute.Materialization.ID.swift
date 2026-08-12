public import File_System
public import Institute_Model
public import JSON

extension Institute.Materialization {
  /// An immutable, validated registry key for one materialisation.
  ///
  /// This is a **registry key, not a filesystem path**: it carries no
  /// directory separators and no traversal components, so an absolute path
  /// can never be folded into it — validation is the same single-path-
  /// component rule ``Institute/Peer/Registry`` already applies to a peer
  /// name. It is stable across a locator change; only ``Institute/
  /// Materialization/Registry`` decides whether two ids may coexist.
  public struct ID: Swift.Equatable, Swift.Hashable, Swift.Sendable, Swift.CustomStringConvertible
  {
    public let value: Swift.String

    public init(_ value: Swift.String) throws(Institute.Error) {
      guard !value.isEmpty else {
        throw .configuration("materialization id must not be empty")
      }
      guard value != ".", value != ".." else {
        throw .configuration("materialization id must not be a traversal component")
      }
      do throws(File.Path.Component.Error) {
        _ = try File.Path.Component(value)
      } catch {
        throw .configuration(
          "materialization id \(value) is not a single valid path component: \(error)"
        )
      }
      self.value = value
    }

    public var description: Swift.String { value }
  }
}

extension Institute.Materialization.ID: JSON.Serializable {
  public static func serialize(_ value: Self) -> JSON {
    value.value.json
  }

  public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
    let raw = try Swift.String(json: json)
    do throws(Institute.Error) {
      return try Self(raw)
    } catch {
      throw .typeMismatch(expected: "a valid materialization id", got: "\(raw): \(error)")
    }
  }
}
