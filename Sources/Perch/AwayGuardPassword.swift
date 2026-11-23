import CommonCrypto
import Foundation
import Security

/// Perch stores a salted verifier for the privacy overlay password.
struct AwayGuardPassword {
    static let pinLength = 4

    private static let saltSize = 16
    private static let hashSize = 32
    private static let passwordVersion: UInt8 = 1
    private static let pinVersion: UInt8 = 2
    private static let rounds: UInt32 = 600_000

    let data: Data
    var isPIN: Bool { data.first == Self.pinVersion }

    init?(data: Data) {
        guard data.count == 1 + Self.saltSize + Self.hashSize,
              data.first == Self.passwordVersion || data.first == Self.pinVersion else { return nil }
        self.data = data
    }

    init?(pin: String) {
        guard Self.isValidPIN(pin) else { return nil }
        var salt = [UInt8](repeating: 0, count: Self.saltSize)
        let status = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess, let hash = Self.derive(pin, salt: salt) else { return nil }
        data = Data([Self.pinVersion] + salt + hash)
    }

    static func isValidPIN(_ pin: String) -> Bool {
        pin.utf8.count == pinLength && pin == pinDigits(in: pin)
    }

    static func pinDigits(in input: String) -> String {
        String(decoding: input.utf8.filter { (48...57).contains($0) }.prefix(pinLength), as: UTF8.self)
    }

    func matches(_ password: String) -> Bool {
        guard isPIN ? Self.isValidPIN(password) : (4...128).contains(password.count) else { return false }
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
