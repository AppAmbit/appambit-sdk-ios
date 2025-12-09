import Foundation

class MultipartFormDataBuilder {
    let boundary: String
    private var body = Data()
    
    init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
    }
    
    func append(object: MultipartValue, withKey key: String = "", useBrackets: Bool = false) {
        switch object {
        case .string(let value):
            appendField(name: key, value: value)
        case .file(let file):
            appendFile(name: key, file: file)
        case .dictionary(let dict):
            for (k, v) in dict {
                let newKey = MultipartValue.key(with: key, key: k, useBrackets: useBrackets)
                append(object: v, withKey: newKey, useBrackets: true)
            }
        case .array(let array):
            for (index, v) in array.enumerated() {
                let newKey = "\(key)[\(index)]"
                append(object: v, withKey: newKey, useBrackets: true)
            }
        }
    }
    
    private func appendField(name: String, value: String) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.append("\(value)\r\n")
    }
    
    private func appendFile(name: String, file: MultipartFile) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(file.fileName)\"\r\n")
        body.append("Content-Type: \(file.mimeType)\r\n\r\n")
        body.append(file.data)
        body.append("\r\n")
    }
    
    func finalize() -> Data {
        var final = body
        final.append("--\(boundary)--\r\n")
        return final
    }
    
    func contentType() -> String {
        "multipart/form-data; boundary=\(boundary)"
    }
}

fileprivate extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) {
            append(d)
        }
    }
}
