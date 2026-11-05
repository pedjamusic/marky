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

    private var favoritesSidebarSection: ContentViewModel.SidebarSection {
        viewModel.displayedSections.first(where: { $0.kind == .favorites })
            ?? ContentViewModel.SidebarSection(kind: .favorites, title: "Favorites", nodes: [])
    }

    private var filesSidebarSection: ContentViewModel.SidebarSection {
        viewModel.displayedSections.first(where: { $0.kind == .files })
            ?? ContentViewModel.SidebarSection(kind: .files, title: "Files", nodes: [])
    }

    private var isSidebarSearchActive: Bool {
        !viewModel.sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var macSidebarSections: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarSectionHeader(
                section: favoritesSidebarSection,
                isCollapsed: viewModel.isSidebarSectionCollapsed(.favorites),
                sidebarListRefreshID: viewModel.sidebarListRefreshID,
                onToggleSection: viewModel.toggleSidebarSection,
                onCollapseFolders: viewModel.collapseAllSidebarFolders
            )
            .padding(.horizontal, MarkyTheme.sidebarControlsHorizontalPadding)

            if !viewModel.isSidebarSectionCollapsed(.favorites) {
                if favoritesSidebarSection.nodes.isEmpty {
                    Text("Star files to keep them close at hand.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, MarkyTheme.sidebarControlsHorizontalPadding)
                        .padding(.vertical, MarkyTheme.sidebarListItemVerticalPadding)
                } else {
                    VStack(spacing: 0) {
                        ForEach(favoritesSidebarSection.nodes) { node in
                            SidebarNodeRow(
                                node: node,
                                expansionBinding: viewModel.folderExpansionBinding(for:),
                                onToggleFolder: viewModel.toggleFolderExpansion(for:),
                                title: sidebarNodeTitle(for:),
                                onSelectNode: viewModel.selectNode,
                                isFavorite: viewModel.isFavorite,
                                onToggleFavorite: viewModel.toggleFavorite(for:)
                            )
                            .padding(.horizontal, MarkyTheme.sidebarControlsHorizontalPadding)
                        }
                    }
                }
            }

            SidebarSectionHeader(
                section: filesSidebarSection,
                isCollapsed: viewModel.isSidebarSectionCollapsed(.files),
                sidebarListRefreshID: viewModel.sidebarListRefreshID,
                onToggleSection: viewModel.toggleSidebarSection,
                onCollapseFolders: viewModel.collapseAllSidebarFolders
            )
            .padding(.top, MarkyTheme.sidebarControlRowSpacing)
            .padding(.horizontal, MarkyTheme.sidebarControlsHorizontalPadding)

            if viewModel.isSidebarSectionCollapsed(.files) {
                Spacer(minLength: 0)
            } else {
                FilesOutlineView(
                    nodes: filesSidebarSection.nodes,
                    selectedURL: viewModel.selectedURL,
                    expandedFolderURLs: viewModel.expandedFolderURLs,
                    favoriteFileURLs: viewModel.favoriteFileURLs,
                    expandAllFolders: isSidebarSearchActive,
                    onSelectNode: viewModel.selectNode,
                    onSetFolderExpanded: viewModel.setFolderExpansion(for:isExpanded:),
                    onToggleFavorite: viewModel.toggleFavorite(for:)
                )
                .padding(.horizontal, MarkyTheme.sidebarControlsHorizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var body: some View {
        Group {
            if viewModel.root == nil {
                ZStack {
                    LinearGradient(
                        colors: MarkyTheme.backgroundGradientColors(for: colorScheme),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: MarkyTheme.launchContentSpacing) {
                        Image("MarkyMascot")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: MarkyTheme.wordmarkMascotMaxWidth)
                            .shadow(
                                color: colorScheme == .dark ? MarkyTheme.launchMascotGlowColorDark : MarkyTheme.launchMascotGlowColorLight,
                                radius: colorScheme == .dark ? MarkyTheme.launchMascotGlowRadiusDark : MarkyTheme.launchMascotGlowRadiusLight
                            )
                            .accessibilityHidden(true)

                        VStack(spacing: MarkyTheme.launchContentSpacing) {
                            Text("Marky")
                                .font(.custom(MarkyTheme.wordmarkFontName, size: MarkyTheme.wordmarkSize))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [MarkyTheme.red, MarkyTheme.yellow, MarkyTheme.green, MarkyTheme.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            HStack(spacing: MarkyTheme.launchActionSpacing) {
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
                        .padding(.top, MarkyTheme.launchWordmarkTopInset)
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
                        }
                        .padding(.horizontal, MarkyTheme.sidebarControlsHorizontalPadding)
                        .padding(.top, MarkyTheme.sidebarControlsTopPadding)

                        #if os(macOS)
                        macSidebarSections
                        #else
                        List {
                            ForEach(viewModel.displayedSections) { section in
                                Section {
                                    if viewModel.isSidebarSectionCollapsed(section.kind) {
                                        EmptyView()
                                    } else if section.kind == .favorites && section.nodes.isEmpty {
                                        Text("Star files to keep them close at hand.")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        ForEach(section.nodes) { node in
                                            SidebarNodeRow(
                                                node: node,
                                                expansionBinding: viewModel.folderExpansionBinding(for:),
                                                onToggleFolder: viewModel.toggleFolderExpansion(for:),
                                                title: sidebarNodeTitle(for:),
                                                onSelectNode: viewModel.selectNode,
                                                isFavorite: viewModel.isFavorite,
                                                onToggleFavorite: viewModel.toggleFavorite(for:)
                                            )
                                        }
                                    }
                                } header: {
                                    SidebarSectionHeader(
                                        section: section,
                                        isCollapsed: viewModel.isSidebarSectionCollapsed(section.kind),
                                        sidebarListRefreshID: viewModel.sidebarListRefreshID,
                                        onToggleSection: viewModel.toggleSidebarSection,
                                        onCollapseFolders: viewModel.collapseAllSidebarFolders
                                    )
                                }
                            }
                        }
                        .id(viewModel.sidebarListRefreshID)
                        .listStyle(.sidebar)
                        #endif
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
                                    colors: MarkyTheme.backgroundGradientColors(for: colorScheme),
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
        .markyWindowChrome(.app, colorScheme: colorScheme)
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
    let isFavorite: (FileNode) -> Bool
    let onToggleFavorite: (FileNode) -> Void

    @State private var isHovered = false

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: expansionBinding(node)) {
                ForEach(node.children ?? []) { child in
                    SidebarNodeRow(
                        node: child,
                        expansionBinding: expansionBinding,
                        onToggleFolder: onToggleFolder,
                        title: title,
                        onSelectNode: onSelectNode,
                        isFavorite: isFavorite,
                        onToggleFavorite: onToggleFavorite
                    )
                }
            } label: {
                HStack(spacing: MarkyTheme.sidebarRowSpacing) {
                    Image(systemName: "folder")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                    title(node)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, MarkyTheme.sidebarListItemVerticalPadding)
                .contentShape(Rectangle())
                .onTapGesture {
                    onToggleFolder(node)
                }
            }
        } else {
            HStack(spacing: MarkyTheme.sidebarRowSpacing) {
                Image(systemName: "doc.text")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                title(node)
                Spacer(minLength: 0)
                Button {
                    onToggleFavorite(node)
                } label: {
                    FavoriteStarIcon(isFilled: isFavorite(node))
                        .foregroundStyle(.secondary)
                }
                .opacity(isHovered || isFavorite(node) ? 1 : 0)
                .buttonStyle(.plain)
                .help(isFavorite(node) ? "Remove from Favorites" : "Add to Favorites")
                .accessibilityLabel(isFavorite(node) ? "Remove from Favorites" : "Add to Favorites")
            }
            .padding(.vertical, MarkyTheme.sidebarListItemVerticalPadding)
            .onHover { hovered in
                isHovered = hovered
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSelectNode(node)
            }
        }
    }
}

private struct FavoriteStarIcon: View {
    let isFilled: Bool

    var body: some View {
        Group {
            if isFilled {
                Image("FavoriteStar")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .scaleEffect(MarkyTheme.favoriteFilledStarContentScale)
                    .clipped()
            } else {
                Image(systemName: "star")
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .frame(width: MarkyTheme.favoriteStarIconSize, height: MarkyTheme.favoriteStarIconSize)
    }
}

private struct SidebarSectionHeader: View {
    let section: ContentViewModel.SidebarSection
    let isCollapsed: Bool
    let sidebarListRefreshID: UUID
    let onToggleSection: (ContentViewModel.SidebarSection.Kind) -> Void
    let onCollapseFolders: () -> Void

    var body: some View {
        HStack(spacing: MarkyTheme.sidebarSectionSpacing) {
            Button {
                onToggleSection(section.kind)
            } label: {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: MarkyTheme.sidebarDisclosureFontSize, weight: .semibold))
                    .foregroundStyle(MarkyTheme.sidebarControlsIconColor)
                    .frame(width: MarkyTheme.sidebarDisclosureSize, height: MarkyTheme.sidebarDisclosureSize)
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "Expand \(section.title)" : "Collapse \(section.title)")
            .accessibilityIdentifier("\(section.kind.rawValue)-section-toggle")

            Text(section.title)
                .font(.system(size: MarkyTheme.sidebarSectionFontSize, weight: .semibold))
                .foregroundStyle(.secondary)

            if section.kind == .files {
                Spacer(minLength: 0)
                Button {
                    onCollapseFolders()
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(MarkyTheme.sidebarControlsIconColor)
                }
                .buttonStyle(.plain)
                .help("Collapse Folders")
                .accessibilityIdentifier("collapse-folders-button")
                .accessibilityValue(sidebarListRefreshID.uuidString)
                .frame(width: MarkyTheme.favoriteStarIconSize, alignment: .center)
                .padding(.trailing, MarkyTheme.sidebarSectionAccessoryTrailingInset)
            }
        }
    }
}

#Preview {
    ContentView()
}
