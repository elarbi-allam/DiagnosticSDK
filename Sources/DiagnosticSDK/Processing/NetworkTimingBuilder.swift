import Foundation

enum NetworkTimingBuilder {
    static func makeTiming(
        startUptime: TimeInterval,
        transferEndUptime: TimeInterval,
        metrics: TaskMetricsSnapshot?
    ) -> NetworkTiming {
        let appPerceivedDurationMs = milliseconds(transferEndUptime - startUptime)
        guard let metrics, let finalTransaction = metrics.transactions.last else {
            return makeClockTiming(appPerceivedDurationMs: appPerceivedDurationMs)
        }
        if finalTransaction.isServedFromCache {
            return makeCacheTiming(appPerceivedDurationMs: appPerceivedDurationMs, redirectCount: metrics.redirectCount)
        }

        let networkTransactions = metrics.transactions.filter(\.isNetworkLoad)
        guard
            let finalNetworkTransaction = networkTransactions.last,
            let networkDurationMs = milliseconds(
                from: networkTransactions.first?.fetchStartDate,
                to: finalNetworkTransaction.responseEndDate
            )
        else {
            return makeClockTiming(appPerceivedDurationMs: appPerceivedDurationMs)
        }

        return NetworkTiming(
            source: .systemMetrics,
            networkDurationMs: networkDurationMs,
            appPerceivedDurationMs: appPerceivedDurationMs,
            phases: makePhases(of: finalNetworkTransaction),
            redirectCount: metrics.redirectCount,
            isServedFromCache: false,
            networkProtocol: finalNetworkTransaction.networkProtocolName,
            isConnectionReused: finalNetworkTransaction.isReusedConnection,
            responseBytesReceived: finalNetworkTransaction.responseBodyBytesReceived
        )
    }

    private static func makePhases(of transaction: TaskMetricsSnapshot.Transaction) -> NetworkTiming.Phases {
        NetworkTiming.Phases(
            domainLookupMs: milliseconds(from: transaction.domainLookupStartDate, to: transaction.domainLookupEndDate),
            connectionMs: milliseconds(
                from: transaction.connectStartDate,
                to: transaction.secureConnectionStartDate ?? transaction.connectEndDate
            ),
            secureConnectionMs: milliseconds(from: transaction.secureConnectionStartDate, to: transaction.secureConnectionEndDate),
            requestSendMs: milliseconds(from: transaction.requestStartDate, to: transaction.requestEndDate),
            serverWaitMs: milliseconds(from: transaction.requestEndDate, to: transaction.responseStartDate),
            downloadMs: milliseconds(from: transaction.responseStartDate, to: transaction.responseEndDate)
        )
    }

    private static func makeClockTiming(appPerceivedDurationMs: Int) -> NetworkTiming {
        NetworkTiming(
            source: .clock,
            networkDurationMs: nil,
            appPerceivedDurationMs: appPerceivedDurationMs,
            phases: nil,
            redirectCount: 0,
            isServedFromCache: false,
            networkProtocol: nil,
            isConnectionReused: nil,
            responseBytesReceived: nil
        )
    }

    private static func makeCacheTiming(appPerceivedDurationMs: Int, redirectCount: Int) -> NetworkTiming {
        NetworkTiming(
            source: .systemMetrics,
            networkDurationMs: nil,
            appPerceivedDurationMs: appPerceivedDurationMs,
            phases: nil,
            redirectCount: redirectCount,
            isServedFromCache: true,
            networkProtocol: nil,
            isConnectionReused: nil,
            responseBytesReceived: nil
        )
    }

    private static func milliseconds(from startDate: Date?, to endDate: Date?) -> Int? {
        guard let startDate, let endDate else { return nil }
        return milliseconds(endDate.timeIntervalSince(startDate))
    }

    private static func milliseconds(_ seconds: TimeInterval) -> Int {
        Int((max(0, seconds) * 1000).rounded())
    }
}
