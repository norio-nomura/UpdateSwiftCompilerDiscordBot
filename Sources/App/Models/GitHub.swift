import Vapor

enum GitHub {
    static let baseURL = URL(string: "https://api.github.com")!
    static let headers: HTTPHeaders = Environment.get("GITHUB_TOKEN").map { ["Authorization": "token \($0)"] } ?? [:]

    struct Repository {
        let owner: String
        let name: String
    }

    struct Content: Decodable {
        let type: String
        let encoding: String
        let size: Int
        let name: String
        let path: String
        let content: String
        let sha: String
        let url: String
        let git_url: String
        let html_url: String
        let download_url: String

        var decodedContent: String? {
            switch encoding {
            case "base64": return Data(base64Encoded: content, options: .ignoreUnknownCharacters).flatMap {
                String.init(data: $0, encoding: .utf8)
                }
            case "utf-8": return content
            default: fatalError("unkown encoding: \(encoding)")
            }
        }
    }
}

extension GitHub.Repository {
    func get(contents path: String, in branch: String? = nil, on request: Request) throws -> Future<GitHub.Content> {
        let components = ["repos", owner, name, "contents", path]
        var url = components.reduce(GitHub.baseURL) { $0.appendingPathComponent($1) }.absoluteString
        if let branch = branch {
            url += "?ref=\(branch)"
        }
        return try request.client().get(url, headers: GitHub.headers).flatMap { try $0.content.decode(GitHub.Content.self) }
    }
}

extension GitHub.Content {
    func update(with content: String,
                in branch: String? = nil,
                message: String,
                on request: Request) throws -> Future<HTTPStatus> {
        var headers = GitHub.headers
        headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
        var url = self.url
        if let index = url.index(where: { $0 == "?"}) {
            url = String(url.prefix(upTo: index))
        }
        return try request.client().put(url, headers: headers, beforeSend: { request in
            struct Payload: Encodable {
                let path: String
                let message: String
                let content: String
                let sha: String
                let branch: String?
            }

            let payload = Payload(path: path,
                                  message: message,
                                  content: Data(content.utf8).base64EncodedString(),
                                  sha: sha, branch: branch)
            try request.content.encode(json: payload)
        }).map { $0.http.status }
    }
}
