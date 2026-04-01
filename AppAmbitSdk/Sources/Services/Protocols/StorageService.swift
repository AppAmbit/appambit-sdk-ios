protocol StorageService {
    func putDeviceId(_ deviceId: String) throws
    func getDeviceId() throws -> String?
    
    func putAppId(_ appId: String) throws
    func getAppId() throws -> String?

    func putUserId(_ userId: String) throws
    func getUserId() throws -> String?

    func putUserEmail(_ email: String) throws
    func getUserEmail() throws -> String?

    func putSessionId(_ sessionId: String) throws
    func getSessionId() throws -> String?
    
    func putConsumerId(_ consumerId: String) throws
    func getConsumerId() throws -> String?
    
    func putDeviceToken(_ deviceToken: String) throws
    func getDeviceToken() throws -> String?
    
    func putPushEnabled(_ pushEnabled: Bool) throws
    func getPushEnabled() throws -> Bool

    func putLogEvent(_ log: LogEntity) throws
    func putLogAnalyticsEvent(_ event: EventEntity) throws
    
    func deleteLogList(_ logs: [LogEntity]) throws
    func getOldest100Logs() throws -> [LogEntity]

    func getOldest100Events() throws -> [EventEntity]
    func deleteEventList(_ events: [EventEntity]) throws
    
    func updateSessionIdsForAllTrackingData(_ sessions: [SessionBatch]) throws

    func getUnpairedSessionStart() throws -> SessionData?
    func getUnpairedSessionEnd() throws -> SessionData?
    func deleteSessionById(_ idValue: String) throws
    func deleteSessionList(_ sessions: [SessionBatch]) throws
    func putSessionData(_ session: SessionData) throws -> Void
    func getOldest100Sessions() throws -> [SessionBatch]
    
    func putBreadcrumb(_ breadcrumb: BreadcrumbEntity) throws -> Void
    func getOldest100Breadcrumbs() throws -> [BreadcrumbEntity]
    func deleteBreadcrumbList(_ breadcrumbs: [BreadcrumbEntity]) throws
    
    func putConfigs(_ configs: [RemoteConfigEntity]) throws
    func getConfig(key: String) throws -> RemoteConfigEntity?

    func putCmsData(_ contentType: String, _ json: String) throws
    func getCmsData(_ contentType: String) throws -> String?
    func queryCmsData(contentType: String, whereClause: String?, args: [String]?, orderBy: String?, limit: Int, offset: Int) throws -> [String]
    func deleteCmsData(_ contentType: String) throws
    func deleteAllCmsData() throws
}
