import SwiftUI

public struct HistorySidebarView: View {
    @ObservedObject var historyManager = HistoryManager.shared
    @ObservedObject var connection: AgentConnection
    @Binding var isPresented: Bool
    
    public init(connection: AgentConnection, isPresented: Binding<Bool>) {
        self.connection = connection
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chat History")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider().background(Color.primary.opacity(0.1))
            
            // History List
            List {
                ForEach(historyManager.sessions) { session in
                    Button(action: {
                        connection.loadSession(session)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            
                            Text(session.updatedAt, style: .date)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            connection.activeSessionId == session.id 
                            ? Color.primary.opacity(0.1) 
                            : Color.clear
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let session = historyManager.sessions[index]
                        historyManager.deleteSession(id: session.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            
            Divider().background(Color.primary.opacity(0.1))
            
            // New Chat Button
            Button(action: {
                connection.startNewSession()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isPresented = false
                }
            }) {
                HStack {
                    Image(systemName: "plus.message.fill")
                    Text("New Chat")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .foregroundColor(.primary)
        }
        .frame(width: 250)
        .glassEffect(.regular, in: UnevenRoundedRectangle(topLeadingRadius: 24, bottomLeadingRadius: 24, bottomTrailingRadius: 0, topTrailingRadius: 0))
    }
}
