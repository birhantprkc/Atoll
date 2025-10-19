import Foundation
import Defaults

@MainActor
final class LockScreenWeatherManager: ObservableObject {
    static let shared = LockScreenWeatherManager()

    @Published private(set) var snapshot: LockScreenWeatherSnapshot?

    private let provider = LockScreenWeatherProvider()
    private var lastFetchDate: Date?

    private init() {}

    func showWeatherWidget() {
        guard Defaults[.enableLockScreenWeatherWidget] else {
            LockScreenWeatherPanelManager.shared.hide()
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refresh(force: self.snapshot == nil)
            if let snapshot = self.snapshot {
                LockScreenWeatherPanelManager.shared.show(with: snapshot)
            } else {
                LockScreenWeatherPanelManager.shared.hide()
            }
        }
    }

    func hideWeatherWidget() {
        LockScreenWeatherPanelManager.shared.hide()
    }

    func refresh(force: Bool = false) async {
        let interval = Defaults[.lockScreenWeatherRefreshInterval]
        if !force, let lastFetchDate, Date().timeIntervalSince(lastFetchDate) < interval {
            if let snapshot = snapshot {
                LockScreenWeatherPanelManager.shared.update(with: snapshot)
            }
            return
        }

        do {
            let snapshot = try await provider.fetchSnapshot()
            self.snapshot = snapshot
            lastFetchDate = Date()
            LockScreenWeatherPanelManager.shared.update(with: snapshot)
        } catch {
            NSLog("LockScreenWeatherManager: failed to fetch weather - \(error.localizedDescription)")
        }
    }
}

struct LockScreenWeatherSnapshot: Equatable {
    let temperatureText: String
    let symbolName: String
    let description: String
}

private actor LockScreenWeatherProvider {
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        session = URLSession(configuration: configuration)
        decoder = JSONDecoder()
    }

    func fetchSnapshot() async throws -> LockScreenWeatherSnapshot {
        guard let url = URL(string: "https://wttr.in/?format=j1") else {
            throw WeatherProviderError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw WeatherProviderError.invalidResponse
        }

        let payload = try decoder.decode(WTTRResponse.self, from: data)
        guard let condition = payload.currentCondition.first else {
            throw WeatherProviderError.noData
        }

        let usesMetric = Locale.current.usesMetricSystem
        let temperature = usesMetric ? condition.tempC : condition.tempF
        let temperatureText = "\(temperature)°"

        let code = Int(condition.weatherCode) ?? 113
        let symbol = WeatherSymbolMapper.symbol(for: code)
        let description = condition.localizedDescription

        return LockScreenWeatherSnapshot(
            temperatureText: temperatureText,
            symbolName: symbol,
            description: description
        )
    }
}

enum WeatherProviderError: Error {
    case invalidURL
    case invalidResponse
    case noData
}

private struct WTTRResponse: Decodable {
    let current_condition: [WTTRCurrentCondition]

    var currentCondition: [WTTRCurrentCondition] { current_condition }
}

private struct WTTRCurrentCondition: Decodable {
    private enum CodingKeys: String, CodingKey {
        case tempC = "temp_C"
        case tempF = "temp_F"
        case weatherCode
        case weatherDesc
        case langEn = "lang_en"
    }

    let tempC: String
    let tempF: String
    let weatherCode: String
    let weatherDesc: [WTTRTextValue]?
    let langEn: [WTTRTextValue]?

    var localizedDescription: String {
        if let english = langEn?.first?.value, !english.isEmpty {
            return english
        }
        if let desc = weatherDesc?.first?.value, !desc.isEmpty {
            return desc
        }
        return ""
    }
}

private struct WTTRTextValue: Decodable {
    let value: String
}

private enum WeatherSymbolMapper {
    static func symbol(for code: Int) -> String {
        switch code {
        case 113:
            return "sun.max.fill"
        case 116:
            return "cloud.sun.fill"
        case 119, 122:
            return "cloud.fill"
        case 143, 248, 260:
            return "cloud.fog.fill"
        case 176, 263, 266, 293, 296, 299, 302, 353, 356, 359:
            return "cloud.rain.fill"
        case 179, 182, 185, 311, 314, 317, 320, 362, 365:
            return "cloud.sleet.fill"
        case 227, 230, 281, 284, 317, 320, 323, 326, 329, 332, 335, 338, 368, 371, 374, 377:
            return "cloud.snow.fill"
        case 200, 386, 389, 392, 395:
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.sun.fill"
        }
    }
}
