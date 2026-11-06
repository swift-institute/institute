public import Byte
public import FIPS_180_4
public import File_System
public import Institute_CI_Model
public import Institute_Model

extension Institute.CI.Bootstrap.Manifest {
    /// One restored executable's identity inside a cache entry.
    public struct Executable: Sendable, Equatable {
        /// Path relative to the cache-entry root.
        public let path: File.Path
        /// Lowercase hex SHA-256 of the executable bytes.
        public let digest: FIPS_180_4.Digest

        public init(path: File.Path, digest: FIPS_180_4.Digest) {
            self.path = path
            self.digest = digest
        }

        /// Digests the executable bytes through the R37 witness, so
        /// producers never hash outside this seam.
        public init(path: File.Path, bytes: [Byte]) {
            self.path = path
            self.digest = FIPS_180_4.SHA256.digest(bytes)
        }
    }
}
