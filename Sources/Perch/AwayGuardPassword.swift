import CommonCrypto
import Foundation
import Security

/// Perch stores a salted verifier for the privacy overlay password.
struct AwayGuardPassword {
    static let minimumLength = 4
    static let maximumLength = 128

    private static let saltSize = 16
    private static let hashSize = 32
    private static let version: UInt8 = 1
    private static let rounds: UInt32 = 600_000

    let data: Data

    init?(data: Data) {
        guard data.count == 1 + Self.saltSize + Self.hashSize,
              data.first == Self.version else { return nil }
        self.data = data
    }

    init?(password: String) {
        guard Self.isValidLength(password) else { return nil }
        var salt = [UInt8](repeating: 0, count: Self.saltSize)
        let status = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess, let hash = Self.derive(password, salt: salt) else { return nil }
        data = Data([Self.version] + salt + hash)
    }

    static func isValidLength(_ password: String) -> Bool {
        (minimumLength...maximumLength).contains(password.count)
    }

    func matches(_ password: String) -> Bool {
        guard Self.isValidLength(password) else { return false }
        let salt = Array(data.dropFirst().prefix(Self.saltSize))
        let expected = data.suffix(Self.hashSize)
        guard let actual = Self.derive(password, salt: salt) else { return false }
        return zip(expected, actual).reduce(UInt8(0)) { difference, pair in
            difference | (pair.0 ^ pair.1)
        } == 0
    }

    private static func derive(_ password: String, salt: [UInt8]) -> [UInt8]? {
        let normalized = password.precomposedStringWithCanonicalMapping
        var hash = [UInt8](repeating: 0, count: hashSize)
        let status = normalized.withCString { bytes in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), bytes, normalized.utf8.count,
                                 salt, salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                                 rounds, &hash, hashSize)
        }
        return status == kCCSuccess ? hash : nil
    }
}
