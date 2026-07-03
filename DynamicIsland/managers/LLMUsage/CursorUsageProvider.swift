import Foundation

struct CursorUsageProvider: UsageProvider {
    let id: ProviderID = .cursor
    let session: URLSession
    let quotaClient: CursorQuotaClient

    init(session: URLSession = URLSession(configuration: .ephemeral), quotaClient: CursorQuotaClient? = nil) {
        self.session = session
        self.quotaClient = quotaClient ?? CursorQuotaClient(session: session)
    }

    func fetchSnapshot(now: Date) async throws -> UsageSnapshot {
        let quota = await quotaClient.fetchLimits()
        guard let cookie = CursorTokenStore.sessionCookie() else {
            guard quota.session != nil || quota.week != nil else {
                throw UsageError.notConfigured("Cursor not signed in")
            }
            var snapshot = UsageSnapshot()
            snapshot.sessionLimit = quota.session
            snapshot.weekLimit = quota.week
            snapshot.lastUpdated = now
            return snapshot
        }
        var components = URLComponents(string: "https://cursor.com/api/usage")!
        components.queryItems = [URLQueryItem(name: "user", value: cookie.userId)]
        var request = URLRequest(url: components.url!)
        request.setValue("WorkosCursorSessionToken=\(cookie.cookieToken)", forHTTPHeaderField: "Cookie")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw UsageError.notConfigured("Cursor usage request failed")
        }
        var snapshot = try decode(data, now: now)
        snapshot.sessionLimit = snapshot.sessionLimit ?? quota.session
        snapshot.weekLimit = snapshot.weekLimit ?? quota.week
        return snapshot
    }

    private func decode(_ data: Data, now: Date) throws -> UsageSnapshot {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageError.notConfigured("Cursor usage response malformed")
        }
        var snapshot = UsageSnapshot()
        snapshot.lastUpdated = now
        var week = UsageTotals()
        var models: [ModelUsage] = []
        for (model, value) in root {
            guard model != "startOfMonth", let entry = value as? [String: Any] else { continue }
            let tokens = entry["numTokens"] as? Int ?? 0
            let requests = entry["numRequests"] as? Int ?? 0
            guard tokens > 0 || requests > 0 else { continue }
            models.append(ModelUsage(model: model, totals: UsageTotals(inputTokens: tokens)))
            week.inputTokens += tokens
        }
        snapshot.models = models.sorted { $0.model < $1.model }
        snapshot.week = week
        return snapshot
    }
}
