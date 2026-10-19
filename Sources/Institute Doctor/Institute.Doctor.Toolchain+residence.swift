internal import File_System
public import Institute_Model

extension Institute.Doctor.Toolchain {
    /// A residence assertion over the canonical forms of what the tools
    /// reported.
    ///
    /// ## Why canonical
    ///
    /// `xcode-select --print-path` reports the path that was selected, links
    /// included, while `xcrun --find` reports where the tool really is.
    /// GitHub's macOS images install each Xcode behind a versioned link
    /// (`Xcode_27.1.app` → `Xcode_27.1_Release_Candidate.app`), so the raw
    /// paths disagreed for the very toolchain that was selected and every
    /// runner failed this check (contributor-path 39244873288, roster-currency
    /// 39244848785). A path that does not resolve is compared as reported:
    /// the comparison stays component-wise either way.
    static func residence(
        of tool: Swift.String,
        resolved: Swift.String,
        developer: Swift.String
    ) -> Self {
        .residence(tool: tool, resolved: canonical(resolved), developer: canonical(developer))
    }

    private static func canonical(_ reported: Swift.String) -> Swift.String {
        let path: File.Path
        do throws(File.Path.Error) {
            path = try File.Path(reported)
        } catch {
            return reported
        }
        do throws(File.System.Canonical.Error) {
            return try File.System.Canonical.resolve(path).description
        } catch {
            return reported
        }
    }
}
