import Vapor

final class WebhookController {
    func dockerImagePushed(_ request: Request) throws -> Future<HTTPStatus> {
        let decoder = JSONDecoder.custom(dates: .secondsSince1970)
        return try request.content.decode(json: DockerHub.ImagePushed.self, using: decoder).flatMap { payload in
            guard payload.push_data.pusher == "norionomura" else {
                return request.eventLoop.newSucceededFuture(result: .badRequest)
            }
            return try BotRepository.update(with: payload.repository.repo_name, payload.push_data.tag, on: request)
        }
    }
}
