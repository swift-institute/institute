public import Build_Coordinator
public import Institute_Model

extension Institute.Verification.Operation {
  /// The full invocation ``Institute/Verification/Run/run(_:request:started:now:)``
  /// executes: which `Build.Action`, against which package root, and
  /// under which execution settings. Groups the facts every caller
  /// (``Institute/Verification/Run/realBuild(_:_:_:_:)``,
  /// ``Institute/Verification/Run/realTest(_:_:_:_:)``, and each nested
  /// test package ``Institute/Verification/Run/realNestedTests(_:_:_:_:)``
  /// discovers) already carries together.
  struct Request {
    let action: Build.Action
    let path: Swift.String
    let subpath: Swift.String?
    let fresh: Swift.Bool
    let jobs: Swift.Int?
    let arguments: [Swift.String]

    init(
      action: Build.Action,
      path: Swift.String,
      subpath: Swift.String?,
      fresh: Swift.Bool,
      jobs: Swift.Int?,
      arguments: [Swift.String]
    ) {
      self.action = action
      self.path = path
      self.subpath = subpath
      self.fresh = fresh
      self.jobs = jobs
      self.arguments = arguments
    }
  }
}
