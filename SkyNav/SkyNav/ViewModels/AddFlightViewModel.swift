import Foundation
import Observation

@Observable
@MainActor
final class AddFlightViewModel {
    var searchQuery = ""
    var searchDate = Date()
    var searchResults: [FlightSearchResult] = []
    var isSearching = false
    var selectedResult: FlightSearchResult?
    var errorMessage: String?
    var dismiss: (() -> Void) = {}
    var onFlightAdded: ((Flight) -> Void) = { _ in }

    private let provider: FlightDataProvider

    init(provider: FlightDataProvider) {
        self.provider = provider
    }

    func search() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        errorMessage = nil
        searchResults = []
        do {
            searchResults = try await provider.searchFlight(number: searchQuery, date: searchDate)
            if searchResults.isEmpty { errorMessage = "No flights found for \"\(searchQuery)\" on this date." }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    func addFlight(_ result: FlightSearchResult) {
        let flight = result.toFlight()
        onFlightAdded(flight)
        SkyNavHaptic.success()
        dismiss()
    }

    func selectAndConfirm(_ result: FlightSearchResult) {
        selectedResult = result
        SkyNavHaptic.light()
    }
}
