import CryptoKit
import DeviceCheck
import Foundation

extension SakuraCloud {

    /// Made and registered with the Worker the first time it is needed; requests that arrive
    /// meanwhile wait for the same key.
    func keyID() async throws -> String {
        if let stored = SakuraCloudKeychain.read(account: SakuraCloudKeychain.keyIDAccount) {
            return stored
        }
        if let attesting { return try await attesting.value }
        let task = Task { try await attest() }
        attesting = task
        defer { attesting = nil }
        return try await task.value
    }

    private func attest() async throws -> String {
        let service = DCAppAttestService.shared
        guard service.isSupported else { throw SakuraCloudError.unsupported }
        let keyID = try await service.generateKey()
        let challenge = try await fetchChallenge()
        let attestation = try await service.attestKey(
            keyID, clientDataHash: Data(SHA256.hash(data: Data(challenge.utf8)))
        )
        let body = try JSONSerialization.data(withJSONObject: [
            "keyId": keyID,
            "attestation": attestation.base64EncodedString(),
            "challenge": challenge
        ])
        let (data, response) = try await URLSession.shared.data(for: try Self.post(.attest, body: body))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 || status == 409 else {
            throw SakuraCloudError.server(status, try? JSONDecoder().decode(Failure.self, from: data).error)
        }
        SakuraCloudKeychain.write(keyID, account: SakuraCloudKeychain.keyIDAccount)
        log("SakuraCloud", "Registered App Attest key \(keyID)")
        return keyID
    }

    private func fetchChallenge() async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: try Self.post(.challenge, body: Data()))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw SakuraCloudError.server(status, try? JSONDecoder().decode(Failure.self, from: data).error)
        }
        guard let challenge = try? JSONDecoder().decode(Challenge.self, from: data).challenge else {
            throw SakuraCloudError.noResponse
        }
        return challenge
    }

    private struct Challenge: Decodable {
        let challenge: String
    }
}
