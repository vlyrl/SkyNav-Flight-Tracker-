import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    private init() {
        let schema = Schema([Flight.self, Trip.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var context: ModelContext { container.mainContext }

    // MARK: - Flight CRUD

    func insert(_ flight: Flight) {
        context.insert(flight)
        try? context.save()
    }

    func delete(_ flight: Flight) {
        context.delete(flight)
        try? context.save()
    }

    func fetchAllFlights() throws -> [Flight] {
        let descriptor = FetchDescriptor<Flight>(sortBy: [SortDescriptor(\.scheduledDeparture)])
        return try context.fetch(descriptor)
    }

    func fetchUpcomingFlights() throws -> [Flight] {
        let now = Date()
        let descriptor = FetchDescriptor<Flight>(
            predicate: #Predicate { $0.scheduledDeparture >= now },
            sortBy: [SortDescriptor(\.scheduledDeparture)]
        )
        return try context.fetch(descriptor)
    }

    func flight(withId id: UUID) throws -> Flight? {
        let descriptor = FetchDescriptor<Flight>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    func save() {
        try? context.save()
    }

    // MARK: - Trip CRUD

    func insert(_ trip: Trip) {
        context.insert(trip)
        try? context.save()
    }

    func delete(_ trip: Trip) {
        context.delete(trip)
        try? context.save()
    }

    func fetchAllTrips() throws -> [Trip] {
        let descriptor = FetchDescriptor<Trip>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor)
    }
}
