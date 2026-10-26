import CryptoKit
import Foundation

#if canImport(DeviceCheck)
    import DeviceCheck
#endif

struct AttestedRequest: Sendable {
    let keyID: String
    let challenge: String
}

actor AppAttestor {
    static let shared = AppAttestor()

    private struct Challenge: Decodable {
        let challenge: String
    }

    private struct KeyRegistration: Encodable {
        let keyId: String
        let attestation: String
        let challenge: String
    }

    private let keyIDDefaults = "AppAttestKeyID"

    func prepare(base: URL, session: URLSession) async -> AttestedRequest? {
        #if canImport(DeviceCheck)
            let service = DCAppAttestService.shared
            guard service.isSupported else { return nil }
            guard var challenge = await Self.challenge(base: base, session: session) else {
                return nil
            }
            if let keyID = UserDefaults.standard.string(forKey: keyIDDefaults) {
                return AttestedRequest(keyID: keyID, challenge: challenge)
            }
            guard let raw = Self.base64URL(challenge),
                let keyID = try? await service.generateKey(),
                let attestation = try? await service.attestKey(
                    keyID, clientDataHash: Data(SHA256.hash(data: raw))),
                await Self.register(
                    KeyRegistration(
                        keyId: keyID, attestation: attestation.base64EncodedString(),
                        challenge: challenge), base: base, session: session),
                let next = await Self.challenge(base: base, session: session)
            else { return nil }
            UserDefaults.standard.set(keyID, forKey: keyIDDefaults)
            challenge = next
            return AttestedRequest(keyID: keyID, challenge: challenge)
        #else
            return nil
        #endif
    }

    func assertion(keyID: String, body: Data) async -> String? {
        #if canImport(DeviceCheck)
            let hash = Data(SHA256.hash(data: body))
            guard
                let assertion = try? await DCAppAttestService.shared.generateAssertion(
                    keyID, clientDataHash: hash)
            else {
                forget()
                return nil
            }
            return assertion.base64EncodedString()
        #else
            return nil
        #endif
    }

    func forget() {
        UserDefaults.standard.removeObject(forKey: keyIDDefaults)
    }

    private static func challenge(base: URL, session: URLSession) async -> String? {
        var request = URLRequest(url: base.appending(path: "v1/attest/challenge"))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        guard let (data, response) = try? await session.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let body = try? JSONDecoder().decode(Challenge.self, from: data)
        else { return nil }
        return body.challenge
    }

    private static func register(_ body: KeyRegistration, base: URL, session: URLSession) async
        -> Bool
    {
        var request = URLRequest(url: base.appending(path: "v1/attest/keys"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try? JSONEncoder().encode(body)
        guard let (_, response) = try? await session.data(for: request) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 204
    }

    static func base64URL(_ text: String) -> Data? {
        var value = text.replacing("-", with: "+").replacing("_", with: "/")
        while !value.count.isMultiple(of: 4) { value += "=" }
        return Data(base64Encoded: value)
    }
}
