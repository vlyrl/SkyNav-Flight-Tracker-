import SwiftUI

// MARK: - FlightSearchView

struct FlightSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddFlightViewModel

    @State private var activeTab: SearchTab = .flightNumber
    @State private var airportQuery: String = ""
    @State private var showConfirmation: Bool = false
    @State private var showAirportNav: Bool = false
    @State private var confirmationResult: FlightSearchResult?
    @State private var appearAnimated: Bool = false

    enum SearchTab: String, CaseIterable {
        case flightNumber = "Flight Number"
        case airport = "Browse Airport"
    }

    init(viewModel: AddFlightViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    // Wire viewModel.dismiss to SwiftUI's dismiss on appear
    private func wireViewModelDismiss() {
        viewModel.dismiss = { dismiss() }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SkyNavColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    tabPicker
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    if activeTab == .flightNumber {
                        flightSearchContent
                    } else {
                        airportBrowseContent
                    }
                }
            }
            .navigationTitle("Add Flight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        SkyNavHaptic.light()
                        dismiss()
                    }
                    .foregroundStyle(SkyNavColor.accent)
                }
            }
            .sheet(isPresented: $showConfirmation) {
                if let result = confirmationResult {
                    // viewModel.addFlight calls viewModel.dismiss() which is wired to our dismiss()
                    FlightConfirmationSheet(result: result, onAdd: {
                        viewModel.addFlight(result)
                    })
                }
            }
            .navigationDestination(isPresented: $showAirportNav) {
                AirportView(iataCode: airportQuery.uppercased())
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { wireViewModelDismiss() }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(SearchTab.allCases, id: \.self) { tab in
                Button {
                    SkyNavHaptic.select()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        activeTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.skyNavCaption)
                        .fontWeight(activeTab == tab ? .semibold : .regular)
                        .foregroundStyle(activeTab == tab ? SkyNavColor.textPrimary : SkyNavColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(activeTab == tab ? SkyNavColor.surfaceRaised : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(SkyNavColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SkyNavColor.surfaceBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Flight Search Content

    private var flightSearchContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                searchInputCard
                searchButton

                if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else if viewModel.isSearching {
                    shimmerCards
                } else if !viewModel.searchResults.isEmpty {
                    resultsSection
                } else if !viewModel.searchQuery.isEmpty {
                    emptyResultsView
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Search Input Card

    private var searchInputCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(SkyNavColor.textSecondary)

                TextField("Flight number (e.g. AA100)", text: $viewModel.searchQuery)
                    .font(.skyNavBody)
                    .foregroundStyle(SkyNavColor.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.search() }
                    }

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(SkyNavColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .background(SkyNavColor.surfaceBorder)

            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(SkyNavColor.textSecondary)

                DatePicker(
                    "Departure date",
                    selection: $viewModel.searchDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .labelsHidden()
                .tint(SkyNavColor.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .skyNavCard()
    }

    // MARK: - Search Button

    private var searchButton: some View {
        Button {
            SkyNavHaptic.medium()
            Task { await viewModel.search() }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSearching {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(viewModel.isSearching ? "Searching…" : "Search")
                    .font(.skyNavHeadline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                viewModel.searchQuery.isEmpty
                    ? SkyNavColor.surfaceRaised
                    : LinearGradient(
                        colors: [SkyNavColor.accent, SkyNavColor.accentDim],
                        startPoint: .leading, endPoint: .trailing
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .animation(.easeInOut(duration: 0.2), value: viewModel.searchQuery.isEmpty)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.searchQuery.isEmpty || viewModel.isSearching)
    }

    // MARK: - Shimmer Loading Cards

    private var shimmerCards: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                ShimmerCard()
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(viewModel.searchResults.count) result\(viewModel.searchResults.count == 1 ? "" : "s")")
                .font(.skyNavCaption)
                .foregroundStyle(SkyNavColor.textSecondary)

            ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, result in
                FlightResultCard(result: result)
                    .onTapGesture {
                        SkyNavHaptic.light()
                        confirmationResult = result
                        showConfirmation = true
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.75)
                            .delay(Double(index) * 0.07),
                        value: viewModel.searchResults.count
                    )
            }
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(SkyNavColor.statusDelayed)

            VStack(spacing: 6) {
                Text("Search Failed")
                    .font(.skyNavHeadline)
                    .foregroundStyle(SkyNavColor.textPrimary)

                Text(message)
                    .font(.skyNavBody)
                    .foregroundStyle(SkyNavColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                SkyNavHaptic.medium()
                Task { await viewModel.search() }
            } label: {
                Text("Try Again")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(SkyNavColor.accent.opacity(0.12))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .skyNavCard()
    }

    // MARK: - Empty Results View

    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 40))
                .foregroundStyle(SkyNavColor.textTertiary)

            Text("No flights found")
                .font(.skyNavHeadline)
                .foregroundStyle(SkyNavColor.textSecondary)

            Text("Try a different flight number or date.")
                .font(.skyNavBody)
                .foregroundStyle(SkyNavColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .skyNavCard()
    }

    // MARK: - Airport Browse Content

    private var airportBrowseContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(SkyNavColor.textSecondary)

                    TextField("Airport code (e.g. LAX)", text: $airportQuery)
                        .font(.skyNavBody)
                        .foregroundStyle(SkyNavColor.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .submitLabel(.go)
                        .onSubmit {
                            if airportQuery.count >= 3 {
                                showAirportNav = true
                            }
                        }

                    if !airportQuery.isEmpty {
                        Button {
                            airportQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(SkyNavColor.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .skyNavCard()

            Button {
                SkyNavHaptic.medium()
                showAirportNav = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Browse Airport")
                        .font(.skyNavHeadline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    airportQuery.count < 3
                        ? SkyNavColor.surfaceRaised
                        : LinearGradient(
                            colors: [SkyNavColor.accent, SkyNavColor.accentDim],
                            startPoint: .leading, endPoint: .trailing
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .animation(.easeInOut(duration: 0.2), value: airportQuery.count >= 3)
            }
            .buttonStyle(.plain)
            .disabled(airportQuery.count < 3)

            VStack(alignment: .leading, spacing: 8) {
                Text("QUICK ACCESS")
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textTertiary)
                    .padding(.leading, 4)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(["JFK", "LAX", "ORD", "DFW", "ATL", "LHR", "CDG", "DXB", "HND"], id: \.self) { code in
                        Button {
                            SkyNavHaptic.light()
                            airportQuery = code
                            showAirportNav = true
                        } label: {
                            Text(code)
                                .font(.skyNavMono)
                                .foregroundStyle(SkyNavColor.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(SkyNavColor.accentGlow)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(SkyNavColor.accent.opacity(0.25), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}

// MARK: - FlightResultCard

struct FlightResultCard: View {
    let result: FlightSearchResult

    private var duration: String {
        let interval = result.scheduledArrival.timeIntervalSince(result.scheduledDeparture)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 8) {
                Text(result.flightNumber)
                    .font(.skyNavMono)
                    .foregroundStyle(SkyNavColor.textPrimary)

                Text("·")
                    .foregroundStyle(SkyNavColor.textTertiary)

                Text(result.airline.name)
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.textSecondary)
                    .lineLimit(1)

                Spacer()

                StatusPill(status: result.status)
            }

            Divider()
                .background(SkyNavColor.surfaceBorder)
                .padding(.vertical, 10)

            // Route row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.origin.iataCode)
                        .font(.skyNavTime)
                        .foregroundStyle(SkyNavColor.textPrimary)
                    Text(result.origin.city)
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textSecondary)
                        .lineLimit(1)
                    Text(result.scheduledDeparture, style: .time)
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textTertiary)
                }

                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.system(size: 14))
                        .foregroundStyle(SkyNavColor.accent)
                    Text(duration)
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(result.destination.iataCode)
                        .font(.skyNavTime)
                        .foregroundStyle(SkyNavColor.textPrimary)
                    Text(result.destination.city)
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textSecondary)
                        .lineLimit(1)
                    Text(result.scheduledArrival, style: .time)
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textTertiary)
                }
            }

            // Gate row (if available)
            if let gate = result.departureGate {
                Divider()
                    .background(SkyNavColor.surfaceBorder)
                    .padding(.vertical, 10)

                HStack {
                    Label("Gate \(gate)", systemImage: "door.left.hand.open")
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textSecondary)
                    Spacer()
                    Text(result.scheduledDeparture, format: .dateTime.month(.abbreviated).day())
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.textTertiary)
                }
            }
        }
        .padding(16)
        .skyNavCard()
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - FlightConfirmationSheet

struct FlightConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let result: FlightSearchResult
    let onAdd: () -> Void

    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                SkyNavColor.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Confirm Flight")
                            .font(.skyNavTitle)
                            .foregroundStyle(SkyNavColor.textPrimary)
                        Text("Add this flight to SkyNav?")
                            .font(.skyNavBody)
                            .foregroundStyle(SkyNavColor.textSecondary)
                    }
                    .padding(.top, 8)

                    FlightResultCard(result: result)
                        .scaleEffect(appeared ? 1 : 0.95)
                        .opacity(appeared ? 1 : 0)

                    VStack(spacing: 12) {
                        // Add button
                        Button {
                            // onAdd() calls viewModel.addFlight(), which calls viewModel.dismiss()
                            // to dismiss the entire FlightSearchView. We dismiss the sheet first.
                            dismiss()
                            onAdd()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Add to SkyNav")
                                    .font(.skyNavHeadline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [SkyNavColor.accent, SkyNavColor.accentDim],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: SkyNavColor.accent.opacity(0.4), radius: 12, y: 6)
                        }
                        .buttonStyle(.plain)

                        Button("Not This Flight") {
                            SkyNavHaptic.light()
                            dismiss()
                        }
                        .font(.skyNavBody)
                        .foregroundStyle(SkyNavColor.textSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(SkyNavColor.textSecondary)
                            .padding(6)
                            .background(SkyNavColor.surfaceRaised)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - ShimmerCard

struct ShimmerCard: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ShimmerRect(width: 80, height: 14)
                Spacer()
                ShimmerRect(width: 60, height: 20, cornerRadius: 10)
            }

            Divider()
                .background(SkyNavColor.surfaceBorder)
                .padding(.vertical, 10)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    ShimmerRect(width: 48, height: 28)
                    ShimmerRect(width: 80, height: 12)
                    ShimmerRect(width: 56, height: 12)
                }

                Spacer()

                VStack(spacing: 6) {
                    ShimmerRect(width: 20, height: 20)
                    ShimmerRect(width: 40, height: 12)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    ShimmerRect(width: 48, height: 28)
                    ShimmerRect(width: 80, height: 12)
                    ShimmerRect(width: 56, height: 12)
                }
            }
        }
        .padding(16)
        .skyNavCard()
    }
}

struct ShimmerRect: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 6
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: SkyNavColor.surfaceRaised, location: shimmerPhase - 0.3),
                        .init(color: SkyNavColor.surfaceBorder.opacity(0.8), location: shimmerPhase),
                        .init(color: SkyNavColor.surfaceRaised, location: shimmerPhase + 0.3),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4)
                        .repeatForever(autoreverses: false)
                ) {
                    shimmerPhase = 1.3
                }
            }
    }
}
