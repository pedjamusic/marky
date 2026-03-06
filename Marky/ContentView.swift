//
//  ContentView.swift
//  Marky
//
//  Created by Predrag Drljaca on 3/5/26.
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    private enum ImportMode {
        case file
        case folder
    }

    @State private var root: FileNode?
    @State private var selectedURL: URL?
    @State private var importMode: ImportMode?
    @State private var sidebarSearchText = ""
    @State private var sidebarListRefreshID = UUID()
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .automatic
    @State private var errorMessage: String?
    @State private var securityScopedURL: URL?

    private static let markdownFileTypes: [UTType] = {
        var types = ["md", "markdown", "mdown", "mkd"].compactMap { UTType(filenameExtension: $0) }
        types.append(.plainText)
        return types
    }()

    private static let lastProjectBookmarkKey = "LastProjectBookmarkKey"

    private func saveBookmark(for url: URL) {
        // Persist bookmark opportunistically: security-scoped when available, plain bookmark as fallback.
        if let securityScopedData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(securityScopedData, forKey: Self.lastProjectBookmarkKey)
            return
        }
        if let plainData = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(plainData, forKey: Self.lastProjectBookmarkKey)
            return
        }
        UserDefaults.standard.removeObject(forKey: Self.lastProjectBookmarkKey)
    }

    private func restoreBookmarkIfNeeded() {
        guard root == nil, let data = UserDefaults.standard.data(forKey: Self.lastProjectBookmarkKey) else { return }
        do {
            var stale = false
            let restoredURL = try {
                do {
                    return try URL(
                        resolvingBookmarkData: data,
                        options: [.withSecurityScope],
                        relativeTo: nil,
                        bookmarkDataIsStale: &stale
                    )
                } catch {
                    return try URL(
                        resolvingBookmarkData: data,
                        options: [],
                        relativeTo: nil,
                        bookmarkDataIsStale: &stale
                    )
                }
            }()
            guard FileManager.default.fileExists(atPath: restoredURL.path) else {
                UserDefaults.standard.removeObject(forKey: Self.lastProjectBookmarkKey)
                return
            }
            if let current = securityScopedURL { current.stopAccessingSecurityScopedResource(); securityScopedURL = nil }
            if restoredURL.startAccessingSecurityScopedResource() {
                securityScopedURL = restoredURL
                let values = try? restoredURL.resourceValues(forKeys: [.isDirectoryKey])
                if values?.isDirectory == true {
                    root = FileNode.buildProjectTree(at: restoredURL)
                } else {
                    let parent = restoredURL.deletingLastPathComponent()
                    root = FileNode(url: parent, name: parent.lastPathComponent, isDirectory: true, children: [
                        FileNode(url: restoredURL, name: restoredURL.lastPathComponent, isDirectory: false, children: nil)
                    ])
                    selectedURL = restoredURL
                }
                splitViewVisibility = .all
                if stale { saveBookmark(for: restoredURL) }
            } else {
                UserDefaults.standard.removeObject(forKey: Self.lastProjectBookmarkKey)
            }
        } catch {
            // Ignore stale/invalid bookmark data during auto-restore.
            UserDefaults.standard.removeObject(forKey: Self.lastProjectBookmarkKey)
        }
    }

    private func closeProject() {
        // Stop any security-scoped access
        if let current = securityScopedURL {
            current.stopAccessingSecurityScopedResource()
            securityScopedURL = nil
        }
        // Remove persisted bookmark
        UserDefaults.standard.removeObject(forKey: Self.lastProjectBookmarkKey)
        // Clear UI state
        selectedURL = nil
        root = nil
    }

    private func presentFilePanel() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = ContentView.markdownFileTypes
        if panel.runModal() == .OK, let fileURL = panel.url {
            // Manage security-scoped access for the parent folder
            if let current = securityScopedURL { current.stopAccessingSecurityScopedResource(); securityScopedURL = nil }
            let folderURL = fileURL.deletingLastPathComponent()
            let folderAccess = folderURL.startAccessingSecurityScopedResource()
            if folderAccess {
                securityScopedURL = folderURL
                saveBookmark(for: folderURL)
                root = FileNode.buildProjectTree(at: folderURL)
                selectedURL = fileURL
                splitViewVisibility = .all
            } else {
                let fileAccess = fileURL.startAccessingSecurityScopedResource()
                if fileAccess { securityScopedURL = fileURL }
                saveBookmark(for: fileURL)
                let parent = folderURL
                root = FileNode(url: parent, name: parent.lastPathComponent, isDirectory: true, children: [
                    FileNode(url: fileURL, name: fileURL.lastPathComponent, isDirectory: false, children: nil)
                ])
                selectedURL = fileURL
                splitViewVisibility = .all
            }
        }
        #else
        importMode = .file
        #endif
    }

    private func presentFolderPanel() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let folderURL = panel.url {
            if let current = securityScopedURL { current.stopAccessingSecurityScopedResource(); securityScopedURL = nil }
            let needsAccess = folderURL.startAccessingSecurityScopedResource()
            if needsAccess { securityScopedURL = folderURL }
            saveBookmark(for: folderURL)
            root = FileNode.buildProjectTree(at: folderURL)
            selectedURL = nil
            splitViewVisibility = .all
        }
        #else
        importMode = .folder
        #endif
    }

    private var displayedNodes: [FileNode] {
        guard let root else { return [] }
        let nodes = root.children ?? []
        let query = sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nodes }
        return filterNodes(nodes, query: query)
    }

    private func filterNodes(_ nodes: [FileNode], query: String) -> [FileNode] {
        let q = query.lowercased()
        return nodes.compactMap { node in
            if node.isDirectory {
                let filteredChildren = filterNodes(node.children ?? [], query: query)
                if node.name.lowercased().contains(q) || !filteredChildren.isEmpty {
                    return FileNode(url: node.url, name: node.name, isDirectory: true, children: filteredChildren)
                }
                return nil
            } else {
                return node.name.lowercased().contains(q) ? node : nil
            }
        }
    }

    private func collapseAllSidebarFolders() {
        // Recreate the outline list to reset expansion state.
        sidebarListRefreshID = UUID()
    }

    private struct SidebarGradientOverlay: View {
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            LinearGradient(
                colors: colorScheme == .dark ? MarkyTheme.sidebarDarkOverlayGradientColors : MarkyTheme.sidebarLightOverlayGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(colorScheme == .dark ? MarkyTheme.sidebarDarkOverlayOpacity : MarkyTheme.sidebarLightOverlayOpacity)
        }
    }

    @ViewBuilder
    private func sidebarNodeTitle(for node: FileNode) -> some View {
        if selectedURL == node.url {
            Text(node.name)
                .bold()
                .foregroundStyle(MarkyTheme.blue)
        } else {
            Text(node.name)
                .foregroundStyle(.primary)
        }
    }

    var body: some View {
        Group {
            if root == nil {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(nsColor: .windowBackgroundColor),
                            Color(nsColor: .textBackgroundColor).opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 20) {
                        Text("Marky")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [MarkyTheme.red, MarkyTheme.yellow, MarkyTheme.green, MarkyTheme.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        HStack(spacing: 12) {
                            Button {
                                presentFilePanel()
                            } label: {
                                Label("Open File", systemImage: "doc")
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                presentFolderPanel()
                            } label: {
                                Label("Open Folder", systemImage: "folder")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                NavigationSplitView(columnVisibility: $splitViewVisibility) {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Search files", text: $sidebarSearchText)
                                    .textFieldStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                            Button {
                                collapseAllSidebarFolders()
                            } label: {
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .tint(.primary)
                            .help("Collapse Folders")
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 6)

                        List {
                            OutlineGroup(displayedNodes, children: \.children) { node in
                                HStack(spacing: 8) {
                                    Image(systemName: node.isDirectory ? "folder" : "doc.text")
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(.secondary)
                                    sidebarNodeTitle(for: node)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !node.isDirectory {
                                        selectedURL = node.url
                                    }
                                }
                            }
                        }
                        .id(sidebarListRefreshID)
                        .listStyle(.sidebar)
                    }
                    .overlay {
                        SidebarGradientOverlay()
                            .allowsHitTesting(false)
                            .ignoresSafeArea()
                    }
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 420)
                    .navigationTitle("")
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button {
                                presentFilePanel()
                            } label: {
                                Label("File", systemImage: "doc")
                            }
                            .keyboardShortcut("o", modifiers: .command)

                            Button {
                                presentFolderPanel()
                            } label: {
                                Label("Folder", systemImage: "folder")
                            }
                            .keyboardShortcut("o", modifiers: [.command, .shift])

                            Button {
                                closeProject()
                            } label: {
                                Label("Close", systemImage: "xmark.circle")
                            }
                            .keyboardShortcut("w", modifiers: [.command, .shift])
                        }
                    }
                } detail: {
                    ZStack(alignment: .top) {
                        if let selectedURL {
                            MarkdownViewer(url: selectedURL)
                        } else {
                            ZStack {
                                LinearGradient(
                                    colors: [
                                        Color(nsColor: .windowBackgroundColor),
                                        Color(nsColor: .textBackgroundColor).opacity(0.92)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .ignoresSafeArea()

                                Text("Select a Markdown file")
                                    .foregroundStyle(MarkyTheme.blue.opacity(0.8))
                            }
                        }
                    }
                    .navigationTitle(selectedURL?.lastPathComponent ?? "Marky")
                }
            }
        }
        #if os(macOS)
        .toolbarBackground(.hidden, for: .windowToolbar)
        #endif
        .tint(MarkyTheme.blue)
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            restoreBookmarkIfNeeded()
        }
        .fileImporter(
            isPresented: Binding(
                get: { importMode != nil },
                set: { isPresented in
                    if !isPresented { importMode = nil }
                }
            ),
            allowedContentTypes: importMode == .folder ? [.folder] : ContentView.markdownFileTypes,
            allowsMultipleSelection: false
        ) { result in
            guard let mode = importMode else { return }
            switch result {
            case .success(let urls):
                guard let pickedURL = urls.first else {
                    importMode = nil
                    return
                }

                if mode == .file {
                    let fileURL = pickedURL
                    if let current = securityScopedURL { current.stopAccessingSecurityScopedResource(); securityScopedURL = nil }
                    let folderURL = fileURL.deletingLastPathComponent()
                    let folderAccess = folderURL.startAccessingSecurityScopedResource()
                    if folderAccess {
                        securityScopedURL = folderURL
                        saveBookmark(for: folderURL)
                        root = FileNode.buildProjectTree(at: folderURL)
                        selectedURL = fileURL
                        splitViewVisibility = .all
                    } else {
                        let fileAccess = fileURL.startAccessingSecurityScopedResource()
                        if fileAccess { securityScopedURL = fileURL }
                        saveBookmark(for: fileURL)
                        let parent = folderURL
                        root = FileNode(url: parent, name: parent.lastPathComponent, isDirectory: true, children: [
                            FileNode(url: fileURL, name: fileURL.lastPathComponent, isDirectory: false, children: nil)
                        ])
                        selectedURL = fileURL
                        splitViewVisibility = .all
                    }
                } else {
                    let folderURL = pickedURL
                    if let current = securityScopedURL { current.stopAccessingSecurityScopedResource(); securityScopedURL = nil }
                    let needsAccess = folderURL.startAccessingSecurityScopedResource()
                    if needsAccess { securityScopedURL = folderURL }
                    saveBookmark(for: folderURL)
                    root = FileNode.buildProjectTree(at: folderURL)
                    selectedURL = nil
                    splitViewVisibility = .all
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
            importMode = nil
        }
    }
}

#Preview {
    ContentView()
}
