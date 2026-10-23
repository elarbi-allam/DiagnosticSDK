import Foundation

struct TaskMetricsSnapshot {
    struct Transaction {
        let isNetworkLoad: Bool
        let isServedFromCache: Bool
        let fetchStartDate: Date?
        let domainLookupStartDate: Date?
        let domainLookupEndDate: Date?
        let connectStartDate: Date?
        let connectEndDate: Date?
        let secureConnectionStartDate: Date?
        let secureConnectionEndDate: Date?
        let requestStartDate: Date?
        let requestEndDate: Date?
        let responseStartDate: Date?
        let responseEndDate: Date?
        let networkProtocolName: String?
        let isReusedConnection: Bool
        let responseBodyBytesReceived: Int64

        init(metrics: URLSessionTaskTransactionMetrics) {
            isNetworkLoad = metrics.resourceFetchType == .networkLoad
            isServedFromCache = metrics.resourceFetchType == .localCache
            fetchStartDate = metrics.fetchStartDate
            domainLookupStartDate = metrics.domainLookupStartDate
            domainLookupEndDate = metrics.domainLookupEndDate
            connectStartDate = metrics.connectStartDate
            connectEndDate = metrics.connectEndDate
            secureConnectionStartDate = metrics.secureConnectionStartDate
            secureConnectionEndDate = metrics.secureConnectionEndDate
            requestStartDate = metrics.requestStartDate
            requestEndDate = metrics.requestEndDate
            responseStartDate = metrics.responseStartDate
            responseEndDate = metrics.responseEndDate
            networkProtocolName = metrics.networkProtocolName
            isReusedConnection = metrics.isReusedConnection
            responseBodyBytesReceived = metrics.countOfResponseBodyBytesReceived
        }
    }

    let transactions: [Transaction]
    let redirectCount: Int

    init(metrics: URLSessionTaskMetrics) {
        transactions = metrics.transactionMetrics.map(Transaction.init)
        redirectCount = metrics.redirectCount
    }
}
