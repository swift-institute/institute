import GitHub
import Tagged_Primitives

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages

extension GitHub.Repository.Summary {
  init(
    fixture id: UInt64,
    name: Swift.String,
    archived: Bool = false,
    disabled: Bool = false,
    fork: Bool = false,
    visibility: GitHub.Repository.Visibility = .public
  ) {
    self.init(
      id: .init(id),
      name: .init(name),
      archived: archived,
      disabled: disabled,
      fork: fork,
      visibility: visibility
    )
  }
}
