import Vapor

struct BotRepository {
    static let regexForRelease = try! NSRegularExpression(pattern: "^(\\d+)$", options: [])
    static let regexForSnapshots = try! NSRegularExpression(pattern: "^(\\d+)(\\d{8}a)$", options: [])
    static let regexForHerokuYML = try! NSRegularExpression(pattern: "DOCKER_IMAGE: (.*)$", options: .anchorsMatchLines)

    static func isRelease(_ tag: String) -> Bool {
        let range = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        return regexForSnapshots.firstMatch(in: tag, range: range) == nil ? false : true
    }

    static func snapshot(_ tag: String) -> (version: String, dateString: String)? {
        guard let ranges = regexForSnapshots.firstMatchRanges(in: tag) else { return nil }
        return (String(tag[ranges[1]]), String(tag[ranges[2]]))
    }

    static func update(with image: String, _ tag: String, on request: Request) throws -> Future<HTTPStatus> {
        guard image == "norionomura/swift" else {
            return request.eventLoop.newSucceededFuture(result: .badRequest)
        }

        let version: String
        if isRelease(tag) {
            version = tag
        } else if let snapshot = snapshot(tag) {
            version = snapshot.version
        } else { // ignore unknown patterns of tag
            return request.eventLoop.newSucceededFuture(result: .ok)
        }
        let repo = GitHub.Repository(owner: "norio-nomura", name: "SwiftCompilerDiscordappBot")
        let branch = (Environment.get("RELEASE") == "YES" ? "swift" : "test") + version.prefix(2)
        return try repo.get(contents: "heroku.yml", in: branch, on: request)
            .flatMap { source in
                guard var content = source.decodedContent,
                    let rangeOfImage = regexForHerokuYML.firstMatchRanges(in: content)?[1] else {
                        return request.eventLoop.newSucceededFuture(result: .badRequest)
                }

                let dockerImage = "\(image):\(tag)"
                content.replaceSubrange(rangeOfImage, with: dockerImage)
                return try source.update(with: content, in: branch, message: "Use \(dockerImage)", on: request)
        }
    }
}
