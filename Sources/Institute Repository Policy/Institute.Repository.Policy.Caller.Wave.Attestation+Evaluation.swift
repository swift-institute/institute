public import Institute_Model
public import Foundation

extension Institute.Repository.Policy.Caller.Wave.Attestation {
    public static func read(
        at path: String
    ) throws(Institute.Repository.Policy.Caller.Wave.Error) -> (attestation: Self, digest: String) {
        let data: Data
        do {
            data = try Data(contentsOf: URL(filePath: path))
        } catch {
            throw .attestation("token issuance attestation is missing at \(path): \(error)")
        }
        let attestation: Self
        do {
            attestation = try JSONDecoder().decode(Self.self, from: data)
        } catch {
            throw .attestation("token issuance attestation at \(path) is malformed: \(error)")
        }
        return (attestation, Institute.Repository.Policy.Caller.Wave.digest(data))
    }

    public func authorize(
        repository: String
    ) throws(Institute.Repository.Policy.Caller.Wave.Error) {
        let components = repository.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 2, !components[0].isEmpty, !components[1].isEmpty else {
            throw .invalidRepository("invalid repository coordinate \(repository)")
        }
        guard !appClientID.isEmpty, !appSlug.isEmpty, installationID > 0, runID > 0 else {
            throw .attestation(
                "\(repository): token issuance attestation identity is incomplete"
            )
        }
        guard permissions["contents"] == "write" else {
            throw .attestation(
                "\(repository): token issuance attestation does not grant contents: write"
            )
        }
        guard permissions["administration"] == "write" else {
            throw .attestation(
                "\(repository): token issuance attestation does not grant administration: write"
            )
        }
        // The wave rewrites .github/workflows/ci.yml, and GitHub refuses
        // workflow-file writes from an App token without the workflows
        // permission (wave run 31826746776: every Apply job 403ed on its
        // first subject's tree creation). A token minted without it
        // cannot complete the transaction, so preflight refuses before
        // any measurement rather than letting apply discover it.
        guard permissions["workflows"] == "write" else {
            throw .attestation(
                "\(repository): token issuance attestation does not grant workflows: write"
            )
        }
        guard organization == String(components[0]),
            repositories.contains(String(components[1]))
        else {
            throw .attestation(
                "\(repository): token issuance attestation scope does not cover the subject"
            )
        }
    }
}
