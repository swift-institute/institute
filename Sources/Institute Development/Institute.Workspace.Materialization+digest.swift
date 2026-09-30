internal import Byte
internal import FIPS_180_4
internal import Institute_Model

extension Institute.Workspace.Materialization {
    static func digest(_ contents: Swift.String) -> Swift.String {
        FIPS_180_4.SHA256.digest(contents.utf8.map(Byte.init(_:))).hex
    }
}
