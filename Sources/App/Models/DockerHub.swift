import Vapor

enum DockerHub {
    struct Image: CustomStringConvertible {
        let name: String
        let tag: String
        var description: String { return "\(name):\(tag)" }
    }

    struct ImagePushed: Decodable {
        let callback_url: String
        let push_data: PushedData
        let repository: Repository

        var image: Image {
            return .init(name: repository.repo_name, tag: push_data.tag)
        }
    }

    struct PushedData: Decodable {
        let images: [String]
        let pushed_at: Date
        let pusher: String
        let tag: String
    }

    struct Repository: Decodable {
//        let comment_count: Int?
//        let date_created: Date
//        let description: String?
//        let dockerfile: String?
//        let full_description: String?
//        let is_official: Bool?
//        let is_private: Bool?
//        let is_trusted: Bool?
        let name: String
        let namespace: String
        let owner: String
        let repo_name: String
        let repo_url: String
//        let star_count: Int?
        let status: String?
    }

}
