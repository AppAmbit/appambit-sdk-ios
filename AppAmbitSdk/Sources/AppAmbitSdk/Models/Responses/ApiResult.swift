struct ApiResult<T> {
    let data: T?
    let errorType: ApiErrorType
    let message: String?

    init(data: T?, errorType: ApiErrorType, message: String? = nil) {
        self.data = data
        self.errorType = errorType
        self.message = message
    }

    static func success(_ data: T) -> ApiResult<T> {
        return ApiResult(data: data, errorType: .none)
    }

    static func fail(_ error: ApiErrorType, message: String? = nil) -> ApiResult<T> {
        return ApiResult(data: nil, errorType: error, message: message)
    }
}
