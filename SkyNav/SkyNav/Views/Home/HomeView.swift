import SwiftUI
import Foundation

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                SkyNavColor.background
                    .ignoresSafeArea()

                if viewModel.filteredFlights.isEmpty && viewModel.activeFlight == nil {
                    EmptyStateView {
                        SkyNavHaptic.medium()
                        viewModel.showAddFlight = true
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    flightList
                }
            }
            .navigationTitle("SkyNav")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    EmptyView()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    addButton
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    filterPicker
                }
            }
            .sheet(isPresented: $viewModel.showAddFlight) {
                FlightSearchView(viewModel: viewModel.makeAddFlightViewModel())
            }
            .navigationDestination(item: $viewModel.selectedFlight) { flight in
                FlightDetailView(viewModel: viewModel.makeDetailViewModel(for: flight))
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Flight List

    private var flightList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let active = viewModel.activeFlight {
                    activeFlightBanner(active)
                        .padding(.top, 4)
                }

                ForEach(viewModel.filteredFlights) { flight in
                    if flight.id != viewModel.activeFlight?.id {
                        FlightCard(flight: flight, onTap: {
                            SkyNavHaptic.select()
                            viewModel.selectedFlight = flight
                        }, onDelete: {
                            viewModel.deleteFlight(flight)
                        })
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                    }
                }

                if viewModel.filteredFlights.isEmpty && viewModel.activeFlight != nil {
                    Text("No other flights")
                        .font(.skyNavBody)
                        .foregroundStyle(SkyNavColor.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.filteredFlights.map { $0.id })
    }

    // MARK: - Active Flight Banner

    private func activeFlightBanner(_ flight: Flight) -> some View {
        Button {
            SkyNavHaptic.medium()
            viewModel.selectedFlight = flight
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "airplane")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(SkyNavColor.accent)

                    Text("NOW FLYING")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(SkyNavColor.accent)
                        .tracking(1.2)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SkyNavColor.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)

                FlightCard(flight: flight, onTap: {
                    SkyNavHaptic.medium()
                    viewModel.selectedFlight = flight
                }, onDelete: {
                    viewModel.deleteFlight(flight)
                })
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(SkyNavColor.accent.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(SkyNavColor.accent.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toolbar Items

    private var addButton: some View {
        Button {
            SkyNavHaptic.light()
            viewModel.showAddFlight = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(SkyNavColor.accent)
                .symbolRenderingMode(.hierarchical)
        }
    }

    private var filterPicker: some View {
        Menu {
            ForEach(FlightFilterMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        viewModel.filterMode = mode
                    }
                    SkyNavHaptic.select()
                } label: {
                    if viewModel.filterMode == mode {
                        Label(mode.rawValue, systemImage: "checkmark")
                    } else {
                        Text(mode.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.filterMode.rawValue)
                    .font(.skyNavCaption)
                    .foregroundStyle(SkyNavColor.accent)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SkyNavColor.accent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(SkyNavColor.accent.opacity(0.12))
            .clipShape(Capsule())
        }
    }
}

