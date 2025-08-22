actor ConcurrencyApp {
    static let shared = ConcurrencyApp()
    private var running = false

    func tryEnter() -> Bool {
        if running { return false }
        running = true
        return true
    }

    func leave() {
        running = false
    }
}
