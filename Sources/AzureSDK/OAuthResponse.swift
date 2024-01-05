import Foundation

struct OAuthToken: Decodable {
    let tokenType: String
    let expiresIn: Date
    let accessToken: String

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            var unkeyedContainer = try decoder.singleValueContainer()
            let seconds = try unkeyedContainer.decode(TimeInterval.self)
            return Date(timeIntervalSinceNow: seconds)
        }
        return decoder
    }()
}
