import SwiftUI
import Foundation

struct LiveSessionView: View {
    @StateObject private var viewModel = LiveSessionViewModel()
    
    var body: some View {
        Group {
            if viewModel.snapshot.screens.isEmpty {
                DiagnosticEmptyStateView(
                    title: "No captured traffic yet",
                    systemImage: "bolt.horizontal.circle",
                    message: "Start using the app to see screens and network calls appear here."
                )
            } else {
                List {
                    TraceSessionHeaderSection(
                        sessionTitle: "Live session",
                        sessionId: viewModel.snapshot.sessionId,
                        startedAt: viewModel.snapshot.startedAt,
                        metadata: viewModel.snapshot.metadata
                    )
                    
                    TraceSessionFilterBarSection(
                        statusFilter: $viewModel.statusFilter,
                        methodFilter: $viewModel.methodFilter
                    )
                    
                    ForEach(viewModel.filteredScreens) { screen in
                        Section(header: TraceScreenSectionHeader(screen: screen)) {
                            ForEach(screen.interactions.reversed()) { interaction in
                                NavigationLink {
                                    NetworkInteractionDetailView(interactionId: interaction.id)
                                } label: {
                                    TraceNetworkInteractionRow(interaction: interaction)
                                }
                                .id(interaction.id)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
            }
        }
    }
}
