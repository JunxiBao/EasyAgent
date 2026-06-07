import SwiftUI
import MarkdownUI

public struct MainWindowView: View {
    @ObservedObject var connection: AgentConnection
    var onSettingsClicked: () -> Void
    var onHideClicked: () -> Void
    
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var isHistoryVisible: Bool = false
    @State private var hoveredMessageId: UUID? = nil
    
    @AppStorage("easyAgentIsExpanded") private var isExpanded: Bool = false
    var onResize: ((Bool) -> Void)?
    
    public init(connection: AgentConnection, onSettingsClicked: @escaping () -> Void, onHideClicked: @escaping () -> Void, onResize: ((Bool) -> Void)? = nil) {
        self.connection = connection
        self.onSettingsClicked = onSettingsClicked
        self.onHideClicked = onHideClicked
        self.onResize = onResize
    }
    
    public var body: some View {
        ZStack(alignment: .leading) {
            Color.clear
            
            VStack(spacing: 0) {
                if isExpanded {
                    // Header
                    headerView
                    
                    // Chat Messages Area
                    chatArea
                }
                
                // Input Panel
                inputPanel
            }
            .padding(isExpanded ? 20 : 16)
            
            if isHistoryVisible {
                HistorySidebarView(connection: connection, isPresented: $isHistoryVisible)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .frame(width: 700, height: isExpanded ? 450 : 70)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
        .onExitCommand { onHideClicked() }
        .onAppear {
            isInputFocused = true
            // Sync window size to persisted expand state
            onResize?(isExpanded)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("easyAgentDidShowWindow"))) { _ in
            // Just restore focus, don't change expand state
            isInputFocused = true
            // Sync window size to current state
            onResize?(isExpanded)
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.cyan, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Easy Agent")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            // Connection Status Dot
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.5), radius: 4)
                
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .glassEffect(.regular, in: Capsule())
            
            Spacer()
            
            // Clear History Button
            if !connection.messages.isEmpty {
                Button(action: { connection.clearHistory() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .glassEffect(.regular, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Clear History")
            }
            
            // History Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isHistoryVisible.toggle()
                }
            }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .glassEffect(.regular, in: Circle())
            }
            .buttonStyle(.plain)
            .help("View Chat History")
            
            // Settings Button
            Button(action: onSettingsClicked) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .glassEffect(.regular, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Configure Agents (Cmd+,)")
            .keyboardShortcut(",", modifiers: .command)
            
            // Dismiss Button
            Button(action: onHideClicked) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .glassEffect(.regular, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Hide (Esc)")
        }
        .padding(.bottom, 12)
    }
    
    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    if connection.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(connection.messages) { message in
                            messageBubble(for: message)
                                .id(message.id)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
                .padding(.vertical, 8)
                .animation(.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0), value: connection.messages)
            }
            .onChange(of: connection.messages) { oldValue, newValue in
                if let lastMessage = newValue.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 4)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.bottom, 14)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundColor(.primary.opacity(0.3))
            
            Text("Ready to run local AI Agents")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary.opacity(0.8))
            
            Text("Summon at any time with your custom hotkey shortcut.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
    }
    
    private func messageBubble(for message: Message) -> some View {
        HStack {
            if message.sender == .user {
                Spacer(minLength: 50)
                HStack(alignment: .bottom, spacing: 8) {
                    copyButton(for: message)
                        .opacity(hoveredMessageId == message.id ? 1 : 0)
                    Text(message.text)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                }
                .contentShape(Rectangle())
                .onHover { isHovered in
                    if isHovered {
                        hoveredMessageId = message.id
                    } else if hoveredMessageId == message.id {
                        hoveredMessageId = nil
                    }
                }
            } else if message.sender == .agent {
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Markdown(message.text.isEmpty && message.isStreaming ? "Thinking..." : message.text)
                            .markdownTheme(.docC)
                            .markdownCodeSyntaxHighlighter(.highlightr)
                            .markdownBlockStyle(\.codeBlock) { configuration in
                                ScrollView(.horizontal) {
                                    configuration.label
                                        .padding(12)
                                        .markdownTextStyle {
                                            FontFamilyVariant(.monospaced)
                                        }
                                }
                                .background(Color(red: 40/255, green: 44/255, blue: 52/255))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                                .markdownMargin(top: 8, bottom: 8)
                            }
                            .markdownBlockStyle(\.blockquote) { configuration in
                                HStack(spacing: 0) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.blue.opacity(0.6))
                                        .frame(width: 4)
                                    configuration.label
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 10)
                                        .padding(.vertical, 4)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                .markdownMargin(top: 8, bottom: 8)
                            }
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                        
                        if message.isStreaming {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.5)
                                .frame(width: 16, height: 16)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                    
                    copyButton(for: message)
                        .opacity(hoveredMessageId == message.id && !message.isStreaming ? 1 : 0)
                }
                .contentShape(Rectangle())
                .onHover { isHovered in
                    if isHovered {
                        hoveredMessageId = message.id
                    } else if hoveredMessageId == message.id {
                        hoveredMessageId = nil
                    }
                }
                Spacer(minLength: 50)
            } else if message.sender == .system {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundColor(.orange)
                        Text("Agent Action Requires Approval")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    Text(message.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let options = message.approvalOptions {
                        if let choice = message.approvalChoice {
                            Text("Selected: \(options.first(where: { $0.optionId == choice })?.name ?? choice)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        } else if let reqId = message.approvalRequestId {
                            HStack(spacing: 8) {
                                ForEach(options, id: \.optionId) { opt in
                                    Button(action: {
                                        connection.sendApprovalDecision(messageId: message.id, requestId: reqId, optionId: opt.optionId)
                                    }) {
                                        Text(opt.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .foregroundColor(.primary)
                                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 6)
                        }
                    }
                }
                .padding(14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                Spacer(minLength: 50)
            } else {
                // System notification (e.g. error message)
                Text(message.text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)
                Spacer()
            }
        }
    }
    
    private func copyButton(for message: Message) -> some View {
        CopyButtonView(message: message)
    }    
    private var inputPanel: some View {
        HStack(spacing: 10) {
            // Text Input Field
            TextField(isExpanded ? "Ask local agent..." : "Ask local agent... (Press Enter to send and expand)", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .placeholder(when: inputText.isEmpty) {
                    Text("Ask local agent...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                .focused($isInputFocused)
                .onSubmit {
                    submitPrompt()
                }
            
            // Expand Toggle Button (always visible)
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                    onResize?(isExpanded)
                }
            }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse" : "Expand")
            
            if connection.isResponding {
                // Cancel Button — cancels the current request, does NOT kill the agent
                Button(action: { connection.cancelCurrentRequest() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else {
                // Send Button
                Button(action: submitPrompt) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private func submitPrompt() {
        guard !connection.isResponding else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        
        // If the user submits a prompt, hide history panel if open
        if isHistoryVisible {
            withAnimation {
                isHistoryVisible = false
            }
        }
        
        if !isExpanded {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded = true
                onResize?(true)
            }
        }
        
        connection.sendPrompt(text)
    }
    
    private var statusColor: Color {
        switch connection.status {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch connection.status {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Ready"
        case .error: return "Error"
        }
    }
}

struct CopyButtonView: View {
    let message: Message
    @State private var isCopied: Bool = false
    
    var body: some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.text, forType: .string)
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isCopied = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isCopied = false
                }
            }
        }) {
            ZStack {
                if isCopied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11))
                        .foregroundColor(message.sender == .user ? .white.opacity(0.9) : .secondary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(4)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// Helpers for rounded corner customization and placeholders
extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
            ZStack(alignment: alignment) {
                placeholder().opacity(shouldShow ? 1 : 0)
                self
            }
        }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = NSBezierPath()
        
        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0
        
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        
        path.line(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.appendArc(withCenter: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight), radius: topRight, startAngle: 270, endAngle: 360)
        }
        
        path.line(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.appendArc(withCenter: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight), radius: bottomRight, startAngle: 0, endAngle: 90)
        }
        
        path.line(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.appendArc(withCenter: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft), radius: bottomLeft, startAngle: 90, endAngle: 180)
        }
        
        path.line(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.appendArc(withCenter: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft), radius: topLeft, startAngle: 180, endAngle: 270)
        }
        
        path.close()
        
        var pathRef = Path()
        // Convert NSBezierPath to SwiftUI Path
        let cgPath = path.cgPath
        pathRef.addPath(Path(cgPath))
        return pathRef
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 2 << 0)
    static let bottomRight = RectCorner(rawValue: 2 << 1)
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        return path
    }
}
