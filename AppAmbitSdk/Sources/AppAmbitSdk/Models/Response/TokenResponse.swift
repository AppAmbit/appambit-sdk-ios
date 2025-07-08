struct TokenResponse: Decodable {
    let consumerId: Int
    let token: String

    private enum CodingKeys: String, CodingKey {
        case consumerId = "id"
        case token
    }
}
