import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ServiceManagement

// Custom AppDelegate to handle the accessory app behavior and Status Bar
class AppDelegate: NSObject, NSApplicationDelegate {
    var ledgeWindowController: LedgeWindowController?
    var settingsWindowController: SettingsWindowController?
    var shakeDetector: ShakeDetector?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 1. Setup Status Bar Item (Menu Bar Icon)
        setupStatusItem()

        ledgeWindowController = LedgeWindowController()

        // 2. Setup ShakeDetector
        shakeDetector = ShakeDetector(onShake: { [weak self] location in
            self?.ledgeWindowController?.showShelf(at: location)
        })
        shakeDetector?.startMonitoring()

        // Apply initial appearance
        AppearanceManager.shared.updateSystemAppearance()

        print("Ledge Build (Stack Mode): \(Date()) - Successfully Started")
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "square.stack.3d.down.right.fill", accessibilityDescription: "Ledge")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Ledge", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// EXTENSION FOR HEX COLORS
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
    
    static func resolvedBackground(scheme: ColorScheme, mode: String) -> Color {
        let isDark = mode == "Dark" || (mode == "System" && scheme == .dark)
        return isDark ? Color(hex: "#312F2C") : Color(hex: "#F0EDE5")
    }
    
    static func resolvedText(scheme: ColorScheme, mode: String) -> Color {
        let isDark = mode == "Dark" || (mode == "System" && scheme == .dark)
        return isDark ? Color(hex: "#F0EDE5") : Color(hex: "#312F2C")
    }
}

// APPEARANCE & SETTINGS MANAGER
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    @AppStorage("appearanceMode") var appearanceMode: String = "System" {
        didSet { updateSystemAppearance() }
    }
    @AppStorage("moveFiles") var moveFiles: Bool = false
    
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login status: \(error)")
            }
        }
    }
    
    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
    
    func updateSystemAppearance() {
        DispatchQueue.main.async {
            switch self.appearanceMode {
            case "Light": NSApp.appearance = NSAppearance(named: .aqua)
            case "Dark": NSApp.appearance = NSAppearance(named: .darkAqua)
            default: NSApp.appearance = nil
            }
        }
    }
}

// SETTINGS WINDOW
class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Ledge Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView())
        self.init(window: window)
    }
}

struct SettingsView: View {
    @ObservedObject var appearance = AppearanceManager.shared
    @Environment(\.colorScheme) var systemScheme
    
    private var bgColor: Color { Color.resolvedBackground(scheme: systemScheme, mode: appearance.appearanceMode) }
    private var textColor: Color { Color.resolvedText(scheme: systemScheme, mode: appearance.appearanceMode) }
    
    var body: some View {
        ZStack {
            bgColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 12) {
                VStack {
                    Image(systemName: "square.stack.3d.down.right.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(textColor)
                }
                .padding(.top, 20)
                
                Text("Ledge")
                    .font(.system(size: 20, weight: .black))
                    .tracking(1)
                    .foregroundColor(textColor)
                
                VStack(alignment: .leading, spacing: 16) {
                    Divider().background(textColor.opacity(0.3))
                    
                    // Appearance Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Appearance")
                            .font(.caption)
                            .foregroundColor(textColor.opacity(0.6))
                        
                        Picker("", selection: $appearance.appearanceMode) {
                            Text("System").tag("System")
                            Text("Light").tag("Light")
                            Text("Dark").tag("Dark")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Toggles Section
                    VStack(alignment: .leading, spacing: 10) {
                        // Move Files Toggle
                        HStack(spacing: 0) {
                            HStack(spacing: 4) {
                                Text("Move files instead of copying")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textColor)
                                
                                InfoButton(text: "Only applies when moving between local storage. Drops to browsers will always copy.")
                            }
                            Spacer()
                            Toggle("", isOn: $appearance.moveFiles)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .scaleEffect(0.8)
                                .labelsHidden()
                                .offset(x: 4)
                        }
                        
                        // Launch at Login Toggle
                        HStack(spacing: 0) {
                            Text("Launch Ledge at login")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(textColor)
                            Spacer()
                            Toggle("", isOn: $appearance.launchAtLogin)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .scaleEffect(0.8)
                                .labelsHidden()
                                .offset(x: 4)
                        }
                    }
                }
                .padding(.horizontal, 35)
                
                Spacer()
                
                Text("Tip: Hold left-click and shake to summon.")
                    .font(.system(size: 11))
                    .foregroundColor(textColor.opacity(0.5))
                    .padding(.bottom, 20)
            }
        }
        .frame(width: 320, height: 340)
        .preferredColorScheme(appearance.colorScheme)
    }
}

struct CloseButton: View {
    @State private var isHovering = false
    @Environment(\.colorScheme) var systemScheme
    @ObservedObject var appearance = AppearanceManager.shared
    var action: () -> Void

    private var textColor: Color { Color.resolvedText(scheme: systemScheme, mode: appearance.appearanceMode) }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(textColor.opacity(isHovering ? 0.12 : 0.001))
                    .frame(width: 22, height: 22)
                
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(textColor.opacity(isHovering ? 0.9 : 0.6))
            }
            .scaleEffect(isHovering ? 1.08 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovering)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in isHovering = hovering }
    }
}

struct ListCloseButton: View {
    @State private var isHovering = false
    @Environment(\.colorScheme) var systemScheme
    @ObservedObject var appearance = AppearanceManager.shared
    var action: () -> Void

    private var textColor: Color { Color.resolvedText(scheme: systemScheme, mode: appearance.appearanceMode) }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(textColor.opacity(isHovering ? 0.2 : 0.001))
                    .frame(width: 16, height: 16)
                
                Image(systemName: "xmark")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundColor(textColor.opacity(isHovering ? 1.0 : 0.4))
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovering)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in isHovering = hovering }
    }
}

struct InfoButton: View {
    @State private var isShowingPopover = false
    @Environment(\.colorScheme) var systemScheme
    @ObservedObject var appearance = AppearanceManager.shared
    var text: String

    private var textColor: Color { Color.resolvedText(scheme: systemScheme, mode: appearance.appearanceMode) }
    private var bgColor: Color { Color.resolvedBackground(scheme: systemScheme, mode: appearance.appearanceMode) }

    var body: some View {
        Button(action: { isShowingPopover.toggle() }) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundColor(textColor.opacity(0.5))
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $isShowingPopover, arrowEdge: .top) {
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(textColor)
                .padding(12)
                .frame(width: 200)
                .background(bgColor)
        }
    }
}

struct ExpandButton: View {
    @State private var isHovering = false
    @Environment(\.colorScheme) var systemScheme
    @ObservedObject var appearance = AppearanceManager.shared
    var isExpanded: Bool
    var action: () -> Void

    private var textColor: Color { Color.resolvedText(scheme: systemScheme, mode: appearance.appearanceMode) }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(textColor.opacity(isHovering ? 0.12 : 0.001))
                    .frame(width: 22, height: 22)
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(textColor.opacity(isHovering ? 0.9 : 0.6))
            }
            .scaleEffect(isHovering ? 1.08 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovering)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in isHovering = hovering }
    }
}

// 2. SHAKE DETECTION
class ShakeDetector {
    private var monitor: Any?
    private var lastLocation: NSPoint?
    private var lastDirection: Int = 0 
    private var directionChanges: Int = 0
    private var firstChangeTime: Date?
    private let requiredChanges = 4
    private let timeWindow: TimeInterval = 0.5
    private let onShake: (NSPoint) -> Void
    init(onShake: @escaping (NSPoint) -> Void) { self.onShake = onShake }
    func startMonitoring() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            self?.handleMouseDrag(event)
        }
    }
    private func handleMouseDrag(_ event: NSEvent) {
        let currentLocation = NSEvent.mouseLocation
        guard let lastLoc = lastLocation else { lastLocation = currentLocation; return }
        let deltaX = currentLocation.x - lastLoc.x
        if abs(deltaX) < 5.0 { lastLocation = currentLocation; return }
        let currentDirection = deltaX > 0 ? 1 : -1
        if currentDirection != lastDirection {
            let now = Date()
            if directionChanges == 0 || (firstChangeTime != nil && now.timeIntervalSince(firstChangeTime!) > timeWindow) {
                directionChanges = 1
                firstChangeTime = now
            } else { directionChanges += 1 }
            lastDirection = currentDirection
            if directionChanges >= requiredChanges {
                directionChanges = 0
                firstChangeTime = nil
                DispatchQueue.main.async { self.onShake(currentLocation) }
            }
        }
        lastLocation = currentLocation
    }
}

// 5. WINDOW MANAGEMENT
class LedgeWindowController: NSWindowController {
    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 160),
            styleMask: [.nonactivatingPanel, .fullSizeContentView], 
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.contentView = NSHostingView(rootView: LedgeView(panel: panel))
        self.init(window: panel)
    }
    func showShelf(at location: NSPoint) {
        guard let window = window, !window.isVisible else { return }
        
        let adjustedOrigin = NSPoint(x: location.x - 80, y: location.y - 80)
        window.setFrameOrigin(adjustedOrigin)
        
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().alphaValue = 1
        }
    }
}

struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { return DragNSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    class DragNSView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}

struct DroppedFile: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let image: NSImage
    let name: String
    
    init(id: UUID = UUID(), url: URL, image: NSImage, name: String) {
        self.id = id
        self.url = url
        self.image = image
        self.name = name
    }
    
    static func == (lhs: DroppedFile, rhs: DroppedFile) -> Bool {
        lhs.id == rhs.id
    }
}

// 3. THE SHELF UI
struct LedgeView: View {
    weak var panel: NSPanel?
    @ObservedObject var appearance = AppearanceManager.shared
    @Environment(\.colorScheme) var systemScheme
    @State private var droppedFiles: [DroppedFile] = []
    @State private var isTargeted = false
    @State private var isFadingOut = false
    @State private var isExpanded = false
    
    private var bgColor: Color { Color.resolvedBackground(scheme: systemScheme, mode: appearance.appearanceMode) }
    private var textColor: Color { Color.resolvedText(scheme: systemScheme, mode: appearance.appearanceMode) }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(bgColor.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(isTargeted ? Color.blue : textColor.opacity(0.1), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
            
            VStack(spacing: 0) {
                // Top area containing handle and close button
                ZStack {
                    WindowDragHandle().frame(height: 35)
                    
                    // Static Drag Handle
                    Capsule()
                        .fill(textColor.opacity(0.2))
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                    
                    if droppedFiles.count > 1 {
                        HStack {
                            ExpandButton(isExpanded: isExpanded) {
                                withAnimation(.spring()) { isExpanded.toggle() }
                            }
                            .padding(.leading, 10)
                            .padding(.top, 4)
                            Spacer()
                        }
                    }
                    
                    HStack {
                        Spacer()
                        CloseButton {
                            dismissLedge()
                        }
                        .padding(.trailing, 10)
                        .padding(.top, 4)
                    }
                }
                .frame(height: 35)
                
                if isExpanded && droppedFiles.count > 1 {
                    expandedListView
                } else {
                    mainContentView
                }
            }
        }
        .frame(width: 160, height: 160)
        .opacity(isFadingOut ? 0 : 1)
        .preferredColorScheme(appearance.colorScheme)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private var mainContentView: some View {
        VStack {
            Spacer()
            if let firstFile = droppedFiles.first {
                VStack(spacing: 8) {
                    ZStack {
                        if droppedFiles.count > 1 {
                            // Stack visual effect
                            ForEach(1..<min(droppedFiles.count, 3), id: \.self) { index in
                                Image(nsImage: droppedFiles[index].image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .offset(x: CGFloat(index) * 4, y: CGFloat(index) * 4)
                                    .opacity(0.3)
                            }
                        }
                        
                        Image(nsImage: firstFile.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 68, height: 68)
                    }
                    
                    Text(droppedFiles.count > 1 ? "\(droppedFiles.count) Files" : firstFile.name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(textColor)
                        .padding(.horizontal, 14)
                }
                .onDrag {
                    startDrag(files: droppedFiles)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.down.right")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundColor(textColor.opacity(0.8))
                    Text("Drop Files")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(textColor.opacity(0.6))
                }
                .opacity(isTargeted ? 1.0 : 0.5)
            }
            Spacer()
        }
        .padding(.bottom, 10)
    }
    
    private var expandedListView: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(droppedFiles) { file in
                    HStack {
                        Image(nsImage: file.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                        Text(file.name)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .foregroundColor(textColor)
                        Spacer()
                        ListCloseButton {
                            removeFile(file)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onDrag {
                        startDrag(files: [file])
                    }
                }
            }
            .padding(.top, 5)
        }
        .frame(maxHeight: 115)
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                var finalURL: URL?
                if let url = item as? URL { finalURL = url }
                else if let data = item as? Data { finalURL = URL(dataRepresentation: data, relativeTo: nil) }
                
                guard let url = finalURL else { return }
                
                DispatchQueue.global(qos: .userInitiated).async {
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    let name = url.lastPathComponent
                    
                    DispatchQueue.main.async {
                        withAnimation(.spring()) {
                            let newFile = DroppedFile(url: url, image: icon, name: name)
                            if !droppedFiles.contains(where: { $0.url == url }) {
                                self.droppedFiles.append(newFile)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func startDrag(files: [DroppedFile]) -> NSItemProvider {
        guard let first = files.first else { return NSItemProvider() }
        
        let provider = NSItemProvider(item: first.url as NSSecureCoding, typeIdentifier: UTType.fileURL.identifier)
        
        let moveFiles = appearance.moveFiles
        let urlsToDelete = files.map { $0.url }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.isFadingOut = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if moveFiles {
                    for url in urlsToDelete {
                        try? FileManager.default.removeItem(at: url)
                    }
                }
                
                self.droppedFiles.removeAll { files.contains($0) }
                if self.droppedFiles.isEmpty {
                    self.panel?.orderOut(nil)
                }
                self.isFadingOut = false
                self.isExpanded = false
            }
        }
        return provider
    }
    
    private func removeFile(_ file: DroppedFile) {
        withAnimation {
            droppedFiles.removeAll { $0.id == file.id }
            if droppedFiles.isEmpty {
                dismissLedge()
            }
        }
    }
    
    private func dismissLedge() {
        withAnimation {
            self.droppedFiles = []
            self.panel?.orderOut(nil)
            self.isExpanded = false
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()