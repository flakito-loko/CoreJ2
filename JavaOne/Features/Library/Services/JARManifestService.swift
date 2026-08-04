import Foundation

/// Reads `META-INF/MANIFEST.MF` from a JAR (ZIP) archive.
final class JARManifestService: ManifestService {

    // MARK: - ManifestService

    func readManifest(from jarURL: URL) throws -> MidletManifest {
        let manifestData: Data
        do {
            guard let entry = try JARArchiveReader.data(
                forEntryNamed: "META-INF/MANIFEST.MF",
                inArchiveAt: jarURL
            ) else {
                throw ManifestServiceError.manifestMissing
            }
            manifestData = entry
        } catch let error as ManifestServiceError {
            throw error
        } catch {
            throw ManifestServiceError.unableToReadJAR
        }

        return try ManifestParser.parse(manifestData)
    }
}

// MARK: - ManifestParser

private enum ManifestParser {
    static func parse(_ data: Data) throws -> MidletManifest {
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw ManifestServiceError.invalidManifest
        }

        var attributes: [String: String] = [:]
        var currentName: String?
        var currentValue = ""

        func commit() {
            guard let name = currentName else { return }
            attributes[name] = currentValue
            currentName = nil
            currentValue = ""
        }

        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            if line.hasPrefix(" ") {
                guard currentName != nil else {
                    throw ManifestServiceError.invalidManifest
                }
                currentValue += line.dropFirst()
                continue
            }

            commit()

            if line.isEmpty {
                continue
            }

            guard let separatorIndex = line.firstIndex(of: ":") else {
                throw ManifestServiceError.invalidManifest
            }

            let name = String(line[..<separatorIndex])
            var value = String(line[line.index(after: separatorIndex)...])
            if value.hasPrefix(" ") {
                value = String(value.dropFirst())
            }

            currentName = name
            currentValue = value
        }

        commit()

        return MidletManifest(
            midletName: attributes["MIDlet-Name"],
            iconPath: iconPath(from: attributes)
        )
    }

    private static func iconPath(from attributes: [String: String]) -> String? {
        if let midletIcon = attributes["MIDlet-Icon"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !midletIcon.isEmpty {
            return JARArchiveReader.normalize(midletIcon)
        }

        if let midletEntry = attributes["MIDlet-1"] {
            let parts = midletEntry
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            if parts.count >= 2, !parts[1].isEmpty {
                return JARArchiveReader.normalize(parts[1])
            }
        }

        return nil
    }
}
