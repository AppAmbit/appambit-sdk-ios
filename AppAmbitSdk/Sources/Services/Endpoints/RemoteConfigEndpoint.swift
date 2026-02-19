class RemoteConfigEndpoint: BaseEndpoint {
    
    init(appVersion: String) {
        super.init()
        url = "/sdk/config?app_version="+appVersion
        method = .get
    }
}
