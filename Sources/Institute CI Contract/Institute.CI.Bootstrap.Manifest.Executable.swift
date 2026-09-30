public import Institute_Model
public import Institute_CI_Model
public import Byte
import FIPS_180_4

extension Institute.CI.Bootstrap.Manifest {
    /// One restored executable's identity inside a cache entry.
    public struct Executable: Sendable, Equatable {
        /// Path relative to the cache-entry root.
        public let path: String
        /// Lowercase hex SHA-256 of the executable bytes.
        public let digest: String

        public init(path: String, digest: String) {
            self.path = path
            self.digest = digest
        }

        /// Digests the executable bytes through the R37 witness, so
        /// producers never hash outside this seam.
        public init(path: String, bytes: [Byte]) {
            self.path = path
            self.digest = FIPS_180_4.SHA256.digest(bytes).hex
        }
    }
}
