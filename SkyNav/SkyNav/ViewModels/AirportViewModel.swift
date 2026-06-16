import Foundation
import Observation

@Observable
@MainActor
final class AirportViewModel {
    var iataCode: String
    var board: AirportBoard?
    var isLoading = false
    var errorMessage: String?

    private let provider: FlightDataProvider

    init(iataCode: String, provider: FlightDataProvider) {
        self.iataCode = iataCode
        self.provider = provider
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            board = try await provider.fetchAirportBoard(iataCode: iataCode)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        guard !isLoading else { return }
        await load()
    }
}
