enum SQLiteError: Error {
    case openDatabase(message: String)
    case execute(message: String)
    case prepare(message: String)
    case step(message: String)
}
