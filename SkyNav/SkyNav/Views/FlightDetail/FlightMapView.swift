import SwiftUI
import MapKit
import CoreLocation

// MARK: - Great Circle Math

/// Returns `count` intermediate CLLocationCoordinate2D points along the great circle
/// between `from` and `to`, including both endpoints.
private func greatCircleCoordinates(
    from: CLLocationCoordinate2D,
    to: CLLocationCoordinate2D,
    count: Int = 20
) -> [CLLocationCoordinate2D] {
    guard count >= 2 else { return [from, to] }

    // Convert to radians
    let lat1 = from.latitude  * .pi / 180
    let lon1 = from.longitude * .pi / 180
    let lat2 = to.latitude    * .pi / 180
    let lon2 = to.longitude   * .pi / 180

    // Great circle angular distance (Haversine)
    let dLat = lat2 - lat1
    let dLon = lon2 - lon1
    let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    let angularDist = 2 * atan2(sqrt(a), sqrt(1 - a))

    guard angularDist > 0 else { return [from, to] }

    var coords: [CLLocationCoordinate2D] = []
    for i in 0 ..< count {
        let t = Double(i) / Double(count - 1)
        let sinD = sin(angularDist)
        guard sinD > 0 else { coords.append(from); continue }

        let A = sin((1 - t) * angularDist) / sinD
        let B = sin(t * angularDist) / sinD

        let x = A * cos(lat1) * cos(lon1) + B * cos(lat2) * cos(lon2)
        let y = A * cos(lat1) * sin(lon1) + B * cos(lat2) * sin(lon2)
        let z = A * sin(lat1) + B * sin(lat2)

        let lat = atan2(z, sqrt(x * x + y * y)) * 180 / .pi
        let lon = atan2(y, x) * 180 / .pi
        coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }
    return coords
}

/// Mid-point on the great circle at t = 0.5.
private func midpoint(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
    greatCircleCoordinates(from: a, to: b, count: 3)[1]
}

// MARK: - Route Polyline

/// `MapPolyline` wrapper representing the curved great-circle route.
private struct RoutePolyline: MapContent {
    let coordinates: [CLLocationCoordinate2D]

    var body: some MapContent {
        MapPolyline(coordinates: coordinates)
            .stroke(
                .linearGradient(
                    colors: [Color(hex: "#4A9EFF"), Color(hex: "#30D158")],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])
            )
    }
}

// MARK: - Airport Pin

private struct AirportPin: View {
    let iata: String

    var body: some View {
        VStack(spacing: 2) {
            Text(iata)
                .font(.skyNavCaption)
                .foregroundStyle(SkyNavColor.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(SkyNavColor.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(SkyNavColor.surfaceBorder, lineWidth: 0.5)
                )

            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(SkyNavColor.accent)
        }
    }
}

// MARK: - Airplane Annotation

private struct AirplaneAnnotation: View {
    let heading: Double

    var body: some View {
        Image(systemName: "airplane")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(SkyNavColor.accent)
            .rotationEffect(.degrees(heading - 90))
            .shadow(color: SkyNavColor.accent.opacity(0.8), radius: 6)
            .padding(6)
            .background(SkyNavColor.background.opacity(0.7))
            .clipShape(Circle())
    }
}

// MARK: - Live Overlay Card

private struct LiveInfoOverlay: View {
    let position: AircraftPosition

    private var altitudeFt: Int {
        Int(position.altitude * 3.28084)
    }

    private var speedMph: Int {
        Int(position.speed * 0.621371)
    }

    var body: some View {
        HStack(spacing: 20) {
            LiveStat(label: "ALT", value: "\(altitudeFt.formatted()) ft")
            Divider()
                .frame(height: 28)
                .background(SkyNavColor.surfaceBorder)
            LiveStat(label: "SPEED", value: "\(speedMph) mph")
            Divider()
                .frame(height: 28)
                .background(SkyNavColor.surfaceBorder)
            LiveStat(label: "HDG", value: "\(Int(position.heading))°")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassCard()
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

private struct LiveStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.skyNavCaption)
                .foregroundStyle(SkyNavColor.textTertiary)
                .tracking(0.8)
            Text(value)
                .font(.skyNavMono)
                .foregroundStyle(SkyNavColor.textPrimary)
        }
    }
}

// MARK: - Flight Map View

struct FlightMapView: View {
    let flight: Flight

    @State private var cameraPosition: MapCameraPosition = .automatic

    private var originCoord: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: flight.originLatitude,
            longitude: flight.originLongitude
        )
    }

    private var destinationCoord: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: flight.destinationLatitude,
            longitude: flight.destinationLongitude
        )
    }

    private var routeCoords: [CLLocationCoordinate2D] {
        greatCircleCoordinates(from: originCoord, to: destinationCoord, count: 20)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                // Great circle route polyline
                MapPolyline(coordinates: routeCoords)
                    .stroke(
                        .linearGradient(
                            colors: [Color(hex: "#4A9EFF"), Color(hex: "#30D158")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])
                    )

                // Origin airport pin
                Annotation(flight.originIata, coordinate: originCoord, anchor: .bottom) {
                    AirportPin(iata: flight.originIata)
                }

                // Destination airport pin
                Annotation(flight.destinationIata, coordinate: destinationCoord, anchor: .bottom) {
                    AirportPin(iata: flight.destinationIata)
                }

                // Live aircraft position (if available)
                if let pos = flight.livePosition {
                    Annotation("Aircraft", coordinate: pos.coordinate, anchor: .center) {
                        AirplaneAnnotation(heading: pos.heading)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .preferredColorScheme(.dark)

            // Live info overlay at the bottom
            if let pos = flight.livePosition {
                LiveInfoOverlay(position: pos)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            setInitialCamera()
        }
        .onChange(of: flight.livePosition?.coordinate.latitude) { _, _ in
            // Keep camera centered on the live position when it updates,
            // but only if we haven't manually panned (automatic handles the initial fit).
        }
    }

    private func setInitialCamera() {
        // Build a region that fits both airports with comfortable padding.
        let mid = midpoint(originCoord, destinationCoord)
        let latDelta = abs(originCoord.latitude - destinationCoord.latitude) * 1.4 + 5
        let lonDelta = abs(originCoord.longitude - destinationCoord.longitude) * 1.4 + 5
        let region = MKCoordinateRegion(
            center: mid,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
        cameraPosition = .region(region)
    }
}

// MARK: - Preview

#Preview {
    let mockFlight: Flight = {
        let airline = Airline(iataCode: "AA", icaoCode: "AAL", name: "American Airlines", callsign: "AMERICAN")
        let origin = Airport(iataCode: "LAX", icaoCode: "KLAX", name: "Los Angeles International",
                             city: "Los Angeles", country: "US",
                             latitude: 33.9425, longitude: -118.4081,
                             timezoneIdentifier: "America/Los_Angeles")
        let destination = Airport(iataCode: "JFK", icaoCode: "KJFK", name: "John F. Kennedy International",
                                  city: "New York", country: "US",
                                  latitude: 40.6413, longitude: -73.7781,
                                  timezoneIdentifier: "America/New_York")
        let f = Flight(flightNumber: "AA100",
                       airline: airline,
                       origin: origin,
                       destination: destination,
                       scheduledDeparture: Date(),
                       scheduledArrival: Date().addingTimeInterval(18000),
                       status: .inFlight)
        f.updateLivePosition(AircraftPosition(
            latitude: 38.5, longitude: -98.0,
            altitude: 11277, speed: 900, heading: 82,
            timestamp: Date()
        ))
        return f
    }()

    FlightMapView(flight: mockFlight)
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(16)
        .background(SkyNavColor.background)
        .preferredColorScheme(.dark)
}
