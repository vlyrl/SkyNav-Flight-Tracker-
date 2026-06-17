import SwiftUI
import SwiftData
import UserNotifications

@main
struct SkyNavApp: App {
    @State private var homeViewModel: HomeViewModel = {
        let provider: any FlightDataProvider
        if let live = try? AeroAPIService() {
            provider = live
        } else {
            provider = MockFlightDataService()
        }
        return HomeViewModel(provider: provider)
    }()
    @State private var subscriptionViewModel = SubscriptionViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(homeViewModel)
                .environment(subscriptionViewModel)
                .modelContainer(PersistenceController.shared.container)
                .preferredColorScheme(.dark)
                .task {
                    await NotificationService.shared.requestAuthorization()
                    await subscriptionViewModel.loadProducts()
                }
        }
    }
}

// MARK: - Root Tab View

struct ContentView: View {
    @Environment(HomeViewModel.self) private var homeVM
    @Environment(SubscriptionViewModel.self) private var subVM

    // Default order: Explore(0) → Flights(1) → Trips(2) → Settings(3)
    // When an active flight is detected, auto-switch to Flights (tag 1).
    @State private var selectedTab = 0

    private var hasActiveFlight: Bool {
        homeVM.activeFlight != nil
    }

    var body: some View {
        tabContent
            .tint(SkyNavColor.accent)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                if #available(iOS 26, *) {
                    // iOS 26: system provides glass tab bar automatically
                } else {
                    configureTabBarAppearance()
                }
                if hasActiveFlight {
                    selectedTab = 1
                }
            }
            .onChange(of: hasActiveFlight) { _, isActive in
                if isActive {
                    withAnimation {
                        selectedTab = 1
                    }
                }
            }
    }

    @ViewBuilder
    private var tabContent: some View {
        if #available(iOS 26, *) {
            TabView(selection: $selectedTab) {
                ExploreView()
                    .tabItem { Label("Explore", systemImage: "building.2") }
                    .tag(0)
                HomeView(viewModel: homeVM)
                    .tabItem { Label("Flights", systemImage: "airplane") }
                    .tag(1)
                TripRootView()
                    .tabItem { Label("Trips", systemImage: "suitcase") }
                    .tag(2)
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
                    .tag(3)
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .toolbarBackground(.hidden, for: .tabBar)
        } else {
            TabView(selection: $selectedTab) {
                ExploreView()
                    .tabItem { Label("Explore", systemImage: "building.2") }
                    .tag(0)
                HomeView(viewModel: homeVM)
                    .tabItem { Label("Flights", systemImage: "airplane") }
                    .tag(1)
                TripRootView()
                    .tabItem { Label("Trips", systemImage: "suitcase") }
                    .tag(2)
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
                    .tag(3)
            }
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(SkyNavColor.surface)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Tab Placeholder Views

struct TripRootView: View {
    @State private var viewModel = TripViewModel()
    var body: some View {
        TripView(viewModel: viewModel)
    }
}

struct ExploreView: View {
    @State private var airportCode = ""
    @State private var destination: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Airport Explorer")
                        .font(.skyNavTitle)
                        .foregroundStyle(SkyNavColor.textPrimary)
                    Text("Look up live departure & arrival boards for any airport.")
                        .font(.skyNavBody)
                        .foregroundStyle(SkyNavColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(SkyNavColor.textSecondary)
                    TextField("Airport code (e.g. JFK)", text: $airportCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.skyNavBody)
                        .foregroundStyle(SkyNavColor.textPrimary)
                        .submitLabel(.search)
                        .onSubmit { lookupAirport() }
                }
                .padding(14)
                .skyNavCard()
                .padding(.horizontal)

                let popular = ["JFK", "LAX", "ORD", "ATL", "SFO", "LHR", "CDG", "DXB"]
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(popular, id: \.self) { code in
                        Button(code) {
                            airportCode = code
                            lookupAirport()
                        }
                        .font(.skyNavCaption)
                        .foregroundStyle(SkyNavColor.accent)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .skyNavCard()
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .background(SkyNavColor.background.ignoresSafeArea())
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $destination) { code in
                AirportView(iataCode: code, provider: (try? AeroAPIService()) ?? MockFlightDataService())
            }
        }
    }

    private func lookupAirport() {
        guard airportCode.count >= 3 else { return }
        SkyNavHaptic.light()
        destination = airportCode.uppercased()
    }
}

struct SettingsView: View {
    @Environment(SubscriptionViewModel.self) private var subVM
    @State private var showPaywall = false
    @State private var timeToLeaveMinutes = 120
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("syncToCalendar") private var syncToCalendar = false

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if subVM.isPremium {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(SkyNavColor.gold)
                            Text("SkyNav Premium")
                                .font(.skyNavHeadline)
                            Spacer()
                            Text("Active")
                                .font(.skyNavCaption)
                                .foregroundStyle(SkyNavColor.statusOnTime)
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(SkyNavColor.gold)
                                Text("Upgrade to Premium")
                                    .font(.skyNavHeadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(SkyNavColor.textSecondary)
                            }
                        }
                        .tint(SkyNavColor.textPrimary)
                    }
                }

                Section("Notifications") {
                    Toggle("Push Notifications", isOn: $notificationsEnabled)
                    Toggle(isOn: $syncToCalendar) {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundStyle(SkyNavColor.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sync to Calendar")
                                    .font(.skyNavBody)
                                Text("Add flights to a \"SkyNav Flights\" calendar")
                                    .font(.skyNavCaption)
                                    .foregroundStyle(SkyNavColor.textSecondary)
                            }
                        }
                    }
                    .onChange(of: syncToCalendar) { _, enabled in
                        if enabled {
                            Task { await CalendarSyncService.shared.requestAccess() }
                        }
                    }
                    HStack {
                        Text("Time to Leave Reminder")
                        Spacer()
                        Picker("", selection: $timeToLeaveMinutes) {
                            Text("1 hour").tag(60)
                            Text("1.5 hours").tag(90)
                            Text("2 hours").tag(120)
                            Text("3 hours").tag(180)
                        }
                        .pickerStyle(.menu)
                        .accentColor(SkyNavColor.accent)
                    }
                }

                Section("Data") {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(SkyNavColor.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Data Source")
                                .font(.skyNavBody)
                            Text(AeroAPIService.isConfigured ? "FlightAware AeroAPI (live)" : "Mock data — add Config.plist key to go live")
                                .font(.skyNavCaption)
                                .foregroundStyle(SkyNavColor.textSecondary)
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(SkyNavColor.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SkyNavColor.background.ignoresSafeArea())
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(viewModel: subVM)
        }
    }
}
