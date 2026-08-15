internal import Institute_Development
internal import Institute_Doctor
internal import Institute_Inventory
internal import Institute_Lint
public import Institute_Model

extension Institute.Verification.Inventory.Digest {
    /// The fixed literals the `inventoryDigest` wire field can carry that
    /// are not themselves digests.
    public enum Token {}
}

extension Institute.Verification.Inventory.Digest.Token {
    /// What a receipt carries when nothing was measured. Fixed here rather
    /// than spelled at each site, because the control plane's envelope
    /// compares against exactly this string.
    public static let unmeasured: Swift.String = "unmeasured"
}
