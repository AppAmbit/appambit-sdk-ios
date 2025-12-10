struct BatchResponse: Decodable {
    let message: String
    
    private enum CodingKeys: String, CodingKey {
        case message
    }
}
