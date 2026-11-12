public import Institute_Model

extension Institute.CI {
    /// How long one build or test job may run before GitHub ends it: the
    /// `timeout-minutes` every such job in swift-ci.yml binds.
    ///
    /// A repository sets it with `timeout-minutes:` in its own
    /// `.github/metadata.yaml`; without that key it is ``default``.
    /// swift-institute/.github#660.
    public struct Timeout: Sendable, Equatable {
        public enum Error: Swift.Error, Equatable {
            /// The value is not a whole number of minutes from 1 to 360.
            case invalid(String)
        }

        public let minutes: Int

        /// 40 minutes, about 1.5 times the slowest healthy build or test
        /// job measured across the fleet on 12 Nov 2026 (25.6 minutes,
        /// swift-compositions/swift-sqlite's iOS simulator tests; Windows
        /// release builds reach 25.4). The measurements are on
        /// swift-institute/.github#660.
        public static let `default` = Self(checked: 40)

        /// GitHub's own ceiling for a job on a hosted runner.
        public static let maximum = 360

        private init(checked minutes: Int) {
            self.minutes = minutes
        }

        public init(minutes: Int) throws(Error) {
            guard (1...Self.maximum).contains(minutes) else {
                throw .invalid(String(minutes))
            }
            self.minutes = minutes
        }

        /// The `timeout-minutes:` value as written in metadata.yaml. Empty
        /// means the key is absent.
        public init(metadata value: String) throws(Error) {
            if value.isEmpty {
                self = .default
                return
            }
            guard value.allSatisfy({ ("0"..."9").contains($0) }),
                let minutes = Int(value)
            else {
                throw .invalid(value)
            }
            do throws(Error) {
                try self.init(minutes: minutes)
            } catch {
                throw .invalid(value)
            }
        }
    }
}
