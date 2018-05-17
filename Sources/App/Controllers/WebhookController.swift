import Vapor

final class WebhookController {
    func dockerImagePushed(_ request: Request) throws -> Future<HTTPStatus> {
        let owner = try request.parameters.next(String.self)
        let repositoryName = try request.parameters.next(String.self)
        let branchPrefix = try request.parameters.next(String.self)

        let decoder = JSONDecoder.custom(dates: .secondsSince1970)
        return try request.content.decode(json: DockerHub.ImagePushed.self, using: decoder).flatMap { payload in
            guard payload.push_data.pusher == "norionomura" else {
                return request.eventLoop.newSucceededFuture(result: .badRequest)
            }
            let repository = GitHub.Repository(owner: owner, name: repositoryName)
            return try WebhookController.updateHerokuYML(in: repository, branchPrefix, with: payload.image, on: request)
        }
    }
    
    static let regexForRelease = try! NSRegularExpression(pattern: "^(\\d+)$", options: [])
    static let regexForSnapshots = try! NSRegularExpression(pattern: "^(\\d*)(\\d{8}a)$", options: [])
    static let regexForHerokuYML = try! NSRegularExpression(pattern: "DOCKER_IMAGE: (.*)$", options: .anchorsMatchLines)

    static func isRelease(_ tag: String) -> Bool {
        let range = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        return regexForRelease.firstMatch(in: tag, range: range) == nil ? false : true
    }

    static func snapshot(_ tag: String) -> (version: String, dateString: String)? {
        guard let ranges = regexForSnapshots.firstMatchRanges(in: tag) else { return nil }
        return (String(tag[ranges[1]]), String(tag[ranges[2]]))
    }

    static func updateHerokuYML(in repository: GitHub.Repository,
                                _ branchPrefix: String,
                                with image: DockerHub.Image,
                                on request: Request) throws -> Future<HTTPStatus> {
        guard image.name.hasPrefix("norionomura/swift") else {
            return request.eventLoop.newSucceededFuture(result: .badRequest)
        }

        let version: String
        if isRelease(image.tag) {
            version = image.tag
        } else if let snapshot = snapshot(image.tag) {
            version = snapshot.version
        } else { // ignore unknown patterns of tag
            return request.eventLoop.newSucceededFuture(result: .ok)
        }
        let branch = (Environment.get("RELEASE") == "YES" ? branchPrefix : "test") + version.prefix(2)
        return try repository.get(contents: "heroku.yml", in: branch, on: request)
            .flatMap { source in
                guard var content = source.decodedContent,
                    let rangeOfImage = regexForHerokuYML.firstMatchRanges(in: content)?[1] else {
                        return request.eventLoop.newSucceededFuture(result: .badRequest)
                }

                content.replaceSubrange(rangeOfImage, with: image.description)
                return try source.update(with: content, in: branch, message: "Use \(image)", on: request)
        }
    }
}
