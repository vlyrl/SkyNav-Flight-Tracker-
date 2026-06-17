import SwiftUI

// MARK: - TripItImportView
// Lets the user paste a TripIt confirmation email and adds parsed flights.

struct TripItImportView: View {
    @Environment(\.dismiss) private var dismiss

    /// Called once per flight the user taps "Add" on. Does NOT auto-dismiss.
    let onAdd: (Flight) -> Void

    @State private var emailText  = ""
    @State private var parsed: [TripItParsedFlight] = []
    @State private var added: Set<UUID> = []
    @State private var hasParsed  = false

    var body: some View {
        NavigationStack {
            ZStack {
                SkyNavColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Instructions ──────────────────────────────────────
                    Text("Paste your TripIt confirmation email. SkyNav will extract flight details automatically.")
                        .font(.skyNavBody)
                        .foregroundStyle(SkyNavColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)

                    // ── Text editor ───────────────────────────────────────
                    TextEditor(text: $emailText)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(SkyNavColor.textPrimary)
                        .scrollContentBackground(.hidden)
                        .background(SkyNavColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(SkyNavColor.surfaceBorder, lineWidth: 0.5)
                        )
                        .frame(minHeight: 150, maxHeight: 210)
                        .padding(.horizontal, 20)

                    // ── Parse button ──────────────────────────────────────
                    Button {
                        SkyNavHaptic.medium()
                        parsed    = TripItParser.parse(emailText)
                        added     = []
                        hasParsed = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Parse Flights")
                                .font(.skyNavHeadline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? SkyNavColor.surfaceRaised
                                : LinearGradient(
                                    colors: [SkyNavColor.accent, SkyNavColor.accentDim],
                                    startPoint: .leading, endPoint: .trailing
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .animation(.easeInOut(duration: 0.15), value: emailText.isEmpty)
                    }
                    .buttonStyle(.plain)
                    .disabled(emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // ── Results ───────────────────────────────────────────
                    if hasParsed {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                if parsed.isEmpty {
                                    emptyParseView
                                } else {
                                    HStack {
                                        Text("\(parsed.count) flight\(parsed.count == 1 ? "" : "s") found")
                                            .font(.skyNavCaption)
                                            .foregroundStyle(SkyNavColor.textSecondary)
                                        Spacer()
                                    }
                                    ForEach(parsed) { f in
                                        TripItFlightCard(
                                            flight:  f,
                                            isAdded: added.contains(f.id)
                                        ) {
                                            added.insert(f.id)
                                            onAdd(f.toFlight())
                                            SkyNavHaptic.success()
                                        }
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: parsed.count)
                        }
                    } else {
                        Spacer()
                    }
                }
            }
            .navigationTitle("Import from TripIt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        SkyNavHaptic.light()
                        dismiss()
                    }
                    .foregroundStyle(SkyNavColor.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyParseView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(SkyNavColor.textTertiary)
            Text("No flights found")
                .font(.skyNavHeadline)
                .foregroundStyle(SkyNavColor.textSecondary)
            Text("Paste the full email including flight number and departure / arrival lines.")
                .font(.skyNavBody)
                .foregroundStyle(SkyNavColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .skyNavCard()
    }
}

// MARK: - TripItFlightCard

private struct TripItFlightCard: View {
    let flight:  TripItParsedFlight
    let isAdded: Bool
    let onAdd:   () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text(flight.flightNumber)
                    .font(.skyNavMono)
                    .foregroundStyle(SkyNavColor.textPrimary)
                Text("·")
                    .foregroundStyle(SkyNavColor.textTertiary)
                Text(flight.airlineName)
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textSecondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.bottom, 10)

            Divider().background(SkyNavColor.surfaceBorder)

            // Route
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(flight.origin)
                        .font(.skyNavTime)
                        .foregroundStyle(SkyNavColor.textPrimary)
                    if let dep = flight.departure {
                        Text(dep, style: .time)
                            .font(.skyNavCaption)
                            .foregroundStyle(SkyNavColor.textSecondary)
                        Text(dep, format: .dateTime.month(.abbreviated).day())
                            .font(.skyNavCaption)
                            .foregroundStyle(SkyNavColor.textTertiary)
                    } else {
                        Text("Time unknown")
                            .font(.skyNavCaption)
                            .foregroundStyle(SkyNavColor.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "airplane")
                    .font(.system(size: 14))
                    .foregroundStyle(SkyNavColor.accent)
                    .frame(width: 24)

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(flight.destination)
                        .font(.skyNavTime)
                        .foregroundStyle(SkyNavColor.textPrimary)
                    if let arr = flight.arrival {
                        Text(arr, style: .time)
                            .font(.skyNavCaption)
                            .foregroundStyle(SkyNavColor.textSecondary)
                    } else {
                        Text("Time unknown")
                            .font(.skyNavCaption)
                            .foregroundStyle(SkyNavColor.textTertiary)
                    }
                }
            }
            .padding(.vertical, 10)

            Divider().background(SkyNavColor.surfaceBorder)

            // Add button
            Button {
                if !isAdded { onAdd() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(isAdded ? "Added to SkyNav" : "Add to SkyNav")
                        .font(.skyNavCaption)
                }
                .foregroundStyle(isAdded ? SkyNavColor.statusOnTime : SkyNavColor.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background((isAdded ? SkyNavColor.statusOnTime : SkyNavColor.accent).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isAdded)
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
            .padding(.top, 10)
        }
        .padding(16)
        .skyNavCard()
    }
}

// MARK: - TripItParsedFlight

struct TripItParsedFlight: Identifiable {
    let id          = UUID()
    let flightNumber: String
    let origin:       String   // IATA
    let destination:  String   // IATA
    let departure:    Date?
    let arrival:      Date?

    var airlineName: String {
        TripItParser.airlineName(for: String(flightNumber.prefix(2)))
    }

    func toFlight() -> Flight {
        let code = String(flightNumber.prefix(2))
        let airline = Airline(iataCode: code, icaoCode: code, name: airlineName, callsign: nil)
        func stub(_ iata: String) -> Airport {
            Airport(iataCode: iata, icaoCode: iata, name: iata, city: iata,
                    country: "", latitude: 0, longitude: 0, timezoneIdentifier: "UTC")
        }
        return Flight(
            flightNumber: flightNumber,
            airline:      airline,
            origin:       stub(origin),
            destination:  stub(destination),
            scheduledDeparture: departure ?? Date(),
            scheduledArrival:   arrival   ?? Date().addingTimeInterval(7200),
            status: .scheduled
        )
    }
}

// MARK: - TripItParser

enum TripItParser {

    // MARK: Airline name lookup

    static func airlineName(for iata: String) -> String {
        let map: [String: String] = [
            "AA": "American Airlines",    "UA": "United Airlines",
            "DL": "Delta Air Lines",      "WN": "Southwest Airlines",
            "B6": "JetBlue Airways",      "AS": "Alaska Airlines",
            "F9": "Frontier Airlines",    "NK": "Spirit Airlines",
            "HA": "Hawaiian Airlines",    "BA": "British Airways",
            "LH": "Lufthansa",            "AF": "Air France",
            "KL": "KLM",                  "EK": "Emirates",
            "QR": "Qatar Airways",        "SQ": "Singapore Airlines",
            "CX": "Cathay Pacific",       "JL": "Japan Airlines",
            "NH": "All Nippon Airways",   "QF": "Qantas",
            "AC": "Air Canada",           "VS": "Virgin Atlantic",
            "IB": "Iberia",               "LX": "Swiss",
            "OS": "Austrian Airlines",    "TK": "Turkish Airlines",
        ]
        return map[iata] ?? "\(iata) Airlines"
    }

    // MARK: Main parse entry point

    static func parse(_ text: String) -> [TripItParsedFlight] {
        let lines = text.components(separatedBy: .newlines)
        var results: [TripItParsedFlight] = []

        for (idx, line) in lines.enumerated() {
            guard let flightNum = firstFlightNumber(in: line) else { continue }

            // Grab a context window around the flight-number line
            let lo  = max(0, idx - 2)
            let hi  = min(lines.count - 1, idx + 14)
            let win = Array(lines[lo...hi])

            guard
                let origin = iataCode(inLines: win, near: ["Depart", "From", "Origin", "Leaves"]),
                let dest   = iataCode(inLines: win, near: ["Arriv", "To", "Destination"]),
                origin != dest
            else { continue }

            let dep = dateTime(inLines: win, near: ["Depart", "From", "Leaves"])
            let arr = dateTime(inLines: win, near: ["Arriv",  "To",    "Destination"])

            // Deduplicate
            guard !results.contains(where: { $0.flightNumber == flightNum && $0.origin == origin }) else { continue }

            results.append(TripItParsedFlight(
                flightNumber: flightNum,
                origin:       origin,
                destination:  dest,
                departure:    dep,
                arrival:      arr
            ))
        }
        return results
    }

    // MARK: Helpers

    /// Returns the first `AA100`-style token from a single line, or nil.
    private static func firstFlightNumber(in line: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\b([A-Z]{2})\s*(\d{3,4})\b"#),
              let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              m.numberOfRanges >= 3 else { return nil }
        let ns = line as NSString
        return ns.substring(with: m.range(at: 1)) + ns.substring(with: m.range(at: 2))
    }

    /// Finds the first plausible IATA code on any line that contains one of `keywords`.
    private static func iataCode(inLines lines: [String], near keywords: [String]) -> String? {
        guard let iataRx = try? NSRegularExpression(pattern: #"\b([A-Z]{3})\b"#) else { return nil }
        for line in lines {
            let up = line.uppercased()
            guard keywords.contains(where: { up.contains($0.uppercased()) }) else { continue }
            let ns = line as NSString
            let matches = iataRx.matches(in: line, range: NSRange(location: 0, length: ns.length))
            for m in matches {
                let code = ns.substring(with: m.range(at: 1))
                if plausibleIATA(code) { return code }
            }
        }
        // Fallback: parenthetical codes like "(JFK)" anywhere in the window
        let combined = lines.joined(separator: " ")
        if let rx  = try? NSRegularExpression(pattern: #"\(([A-Z]{3})\)"#) {
            let ns = combined as NSString
            for m in rx.matches(in: combined, range: NSRange(location: 0, length: ns.length)) {
                let code = ns.substring(with: m.range(at: 1))
                if plausibleIATA(code) { return code }
            }
        }
        return nil
    }

    /// Builds a Date from a time (12h) and date found in lines near `keywords`.
    private static func dateTime(inLines lines: [String], near keywords: [String]) -> Date? {
        // Gather relevant lines + ±1 neighbours
        var relevant: [String] = []
        for (i, line) in lines.enumerated() {
            let up = line.uppercased()
            if keywords.contains(where: { up.contains($0.uppercased()) }) {
                if i > 0 { relevant.append(lines[i-1]) }
                relevant.append(line)
                if i < lines.count - 1 { relevant.append(lines[i+1]) }
            }
        }
        if relevant.isEmpty { relevant = lines }
        let blob = relevant.joined(separator: " ")

        // Extract time (H:MM AM/PM)
        guard let timeRx = try? NSRegularExpression(pattern: #"(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)"#),
              let tm = timeRx.firstMatch(in: blob, range: NSRange(blob.startIndex..., in: blob)),
              tm.numberOfRanges >= 4 else { return nil }

        let ns   = blob as NSString
        var hr   = Int(ns.substring(with: tm.range(at: 1))) ?? 0
        let min  = Int(ns.substring(with: tm.range(at: 2))) ?? 0
        let ampm = ns.substring(with: tm.range(at: 3)).uppercased()
        if ampm == "PM", hr < 12 { hr += 12 }
        if ampm == "AM", hr == 12 { hr  = 0 }

        // Extract date
        let base = extractDate(from: blob) ?? Date()
        var c    = Calendar.current.dateComponents([.year, .month, .day], from: base)
        c.hour   = hr;  c.minute = min;  c.second = 0
        return Calendar.current.date(from: c)
    }

    private static func extractDate(from text: String) -> Date? {
        // "June 15, 2025" / "Jun 15, 2025" / etc.
        let months = "Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?"
        let longPat = "(\(months))[,\\s]+(\\d{1,2})[,\\s]+(\\d{4})"
        if let rx = try? NSRegularExpression(pattern: longPat, options: .caseInsensitive),
           let m = rx.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           m.numberOfRanges >= 4,
           let rMon = Range(m.range(at: 1), in: text),
           let rDay = Range(m.range(at: 2), in: text),
           let rYr  = Range(m.range(at: 3), in: text) {
            let monStr = String(text[rMon].prefix(3)).lowercased()
            let monthMap = ["jan":1,"feb":2,"mar":3,"apr":4,"may":5,"jun":6,
                            "jul":7,"aug":8,"sep":9,"oct":10,"nov":11,"dec":12]
            if let mon = monthMap[monStr],
               let day = Int(text[rDay]),
               let yr  = Int(text[rYr]) {
                var c = DateComponents(); c.year = yr; c.month = mon; c.day = day
                return Calendar.current.date(from: c)
            }
        }
        // "MM/DD/YYYY"
        if let rx = try? NSRegularExpression(pattern: #"(\d{1,2})/(\d{1,2})/(\d{4})"#),
           let m = rx.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           m.numberOfRanges >= 4 {
            let ns = text as NSString
            let mon = Int(ns.substring(with: m.range(at: 1))) ?? 1
            let day = Int(ns.substring(with: m.range(at: 2))) ?? 1
            let yr  = Int(ns.substring(with: m.range(at: 3))) ?? Calendar.current.component(.year, from: Date())
            var c = DateComponents(); c.year = yr; c.month = mon; c.day = day
            return Calendar.current.date(from: c)
        }
        return nil
    }

    /// Common English words and abbreviations that look like IATA codes but aren't.
    private static let noise: Set<String> = [
        "THE","AND","FOR","ARE","YOU","NOT","BUT","CAN","ALL","ANY","NEW","OLD",
        "AIR","FLY","JET","SET","GET","PUT","LET","ACT","ADD","AGO","AID","AIM",
        "APT","ASK","BAD","BAG","BAN","BAR","BIG","BIT","BOX","BUY","CAR","DAY",
        "END","ETA","ETD","FAR","FEW","FIT","FIX","FLT","FRI","FWD","GEN","HAS",
        "HIM","HIT","HOW","HRS","INC","ITS","JAN","JUN","JUL","KIT","LAT","LAY",
        "LEG","LOC","LON","LOT","LOW","MAP","MAR","MAY","MID","MIN","MON","NET",
        "NON","NOR","NOW","NUM","OFF","OUR","OUT","OWN","PAX","PAY","PDF","PER",
        "PLN","POS","PRE","REF","RES","RUN","SAT","SAY","SCH","SEC","SKY","STA",
        "STD","STO","SUN","TAX","THU","TIM","TKT","TUE","TWO","USE","VAT","VIA",
        "VOL","WAS","WED","WHY","WIN","YET","ZIP","ZON","EST","PST","CST","MST",
        "UTC","GMT","PDT","CDT","MDT","EDT","HST","AST",
    ]

    private static func plausibleIATA(_ code: String) -> Bool {
        guard code.count == 3 else { return false }
        return !noise.contains(code)
    }
}
