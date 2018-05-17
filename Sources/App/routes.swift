import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    let webhookController = WebhookController()
    router.post("docker-image-pushed", use: webhookController.dockerImagePushed)
}
