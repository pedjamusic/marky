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
    @StateObject private var viewModel = ContentViewModel()
    @Environment(\.colorScheme) private var colorScheme

    private func presentFilePanel() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = ContentViewModel.markdownFileTypes
        if panel.runModal() == .OK, let fileURL = panel.url {
            viewModel.handlePickedURL(fileURL, mode: .file)
        }
        #else
        viewModel.requestFileImport()
        #endif
    }

    private func presentFolderPanel() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let folderURL = panel.url {
            viewModel.handlePickedURL(folderURL, mode: .folder)
        }
        #else
        viewModel.requestFolderImport()
        #endif
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
        if viewModel.selectedURL == node.url {
            Text(node.name)
                .bold()
                .foregroundStyle(MarkyTheme.blue)
        } else {
            Text(node.name)
                .foregroundStyle(.primary)
        }
    }

    private var isErrorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private var isFileImporterPresented: Binding<Bool> {
        Binding(
            get: { viewModel.importMode != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.importMode = nil
                }
            }
        )
    }

    private var fileImporterContentTypes: [UTType] {
        viewModel.importMode == .folder ? [.folder] : ContentViewModel.markdownFileTypes
    }

    var body: some View {
        Group {
            if viewModel.root == nil {
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
                        Image("MarkyMascot")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: MarkyTheme.wordmarkMascotMaxWidth)
                            .shadow(
                                color: colorScheme == .dark ? MarkyTheme.launchMascotGlowColorDark : MarkyTheme.launchMascotGlowColorLight,
                                radius: colorScheme == .dark ? MarkyTheme.launchMascotGlowRadiusDark : MarkyTheme.launchMascotGlowRadiusLight
                            )
                            .accessibilityHidden(true)

                        VStack(spacing: 20) {
                            Text("Marky")
                                .font(.custom(MarkyTheme.wordmarkFontName, size: MarkyTheme.wordmarkSize))
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
                        .padding(.top, -64)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                NavigationSplitView(columnVisibility: $viewModel.splitViewVisibility) {
                    VStack(spacing: MarkyTheme.sidebarControlRowSpacing) {
                        HStack(spacing: MarkyTheme.sidebarControlRowSpacing) {
                            HStack(spacing: MarkyTheme.sidebarSearchFieldSpacing) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(MarkyTheme.sidebarControlsIconColor)
                                TextField("Search files", text: $viewModel.sidebarSearchText)
                                    .textFieldStyle(.plain)
                                    .accessibilityIdentifier("sidebar-search-field")
                            }
                            .padding(.horizontal, MarkyTheme.sidebarSearchHorizontalPadding)
                            .padding(.vertical, MarkyTheme.sidebarSearchVerticalPadding)
                            .background(
                                MarkyTheme.sidebarSearchBackgroundMaterial,
                                in: RoundedRectangle(cornerRadius: MarkyTheme.sidebarSearchCornerRadius, style: .continuous)
                            )

                            Button {
                                viewModel.collapseAllSidebarFolders()
                            } label: {
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(MarkyTheme.sidebarControlsIconColor)
                            }
                            .buttonStyle(.borderless)
                            .tint(MarkyTheme.sidebarControlsTint)
                            .help("Collapse Folders")
                            .accessibilityIdentifier("collapse-folders-button")
                            .accessibilityValue(viewModel.sidebarListRefreshID.uuidString)
                        }
                        .padding(.horizontal, MarkyTheme.sidebarControlsHorizontalPadding)
                        .padding(.top, MarkyTheme.sidebarControlsTopPadding)

                        List {
                            ForEach(viewModel.displayedNodes) { node in
                                SidebarNodeRow(
                                    node: node,
                                    expansionBinding: viewModel.folderExpansionBinding(for:),
                                    onToggleFolder: viewModel.toggleFolderExpansion(for:),
                                    title: sidebarNodeTitle(for:),
                                    onSelectNode: viewModel.selectNode
                                )
                            }
                        }
                        .id(viewModel.sidebarListRefreshID)
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
                                viewModel.closeProject()
                            } label: {
                                Label("Close", systemImage: "xmark.circle")
                            }
                            .keyboardShortcut("w", modifiers: [.command, .shift])
                        }
                    }
                } detail: {
                    ZStack(alignment: .top) {
                        if let selectedURL = viewModel.selectedURL {
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
                    .navigationTitle(viewModel.selectedURL?.lastPathComponent ?? "Marky")
                }
            }
        }
        #if os(macOS)
        .toolbarBackground(.hidden, for: .windowToolbar)
        #endif
        .tint(MarkyTheme.blue)
        .alert("Error", isPresented: isErrorPresented) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            viewModel.restoreBookmarkIfNeeded()
        }
        .fileImporter(
            isPresented: isFileImporterPresented,
            allowedContentTypes: fileImporterContentTypes,
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleFileImporterResult(result)
        }
    }
}

private struct SidebarNodeRow<Title: View>: View {
    let node: FileNode
    let expansionBinding: (FileNode) -> Binding<Bool>
    let onToggleFolder: (FileNode) -> Void
    let title: (FileNode) -> Title
    let onSelectNode: (FileNode) -> Void

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: expansionBinding(node)) {
                ForEach(node.children ?? []) { child in
                    SidebarNodeRow(
                        node: child,
                        expansionBinding: expansionBinding,
                        onToggleFolder: onToggleFolder,
                        title: title,
                        onSelectNode: onSelectNode
                    )
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                    title(node)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onToggleFolder(node)
                }
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                title(node)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelectNode(node)
            }
        }
    }
}

#Preview {
    ContentView()
}
