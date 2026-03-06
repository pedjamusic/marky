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

    private func presentFilePanel() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = ContentViewModel.markdownFileTypes
        if panel.runModal() == .OK, let fileURL = panel.url {
            viewModel.openPickedFile(fileURL)
        }
        #else
        viewModel.importMode = .file
        #endif
    }

    private func presentFolderPanel() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let folderURL = panel.url {
            viewModel.openPickedFolder(folderURL)
        }
        #else
        viewModel.importMode = .folder
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
                NavigationSplitView(columnVisibility: $viewModel.splitViewVisibility) {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Search files", text: $viewModel.sidebarSearchText)
                                    .textFieldStyle(.plain)
                                    .accessibilityIdentifier("sidebar-search-field")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                            Button {
                                viewModel.collapseAllSidebarFolders()
                            } label: {
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .tint(.primary)
                            .help("Collapse Folders")
                            .accessibilityIdentifier("collapse-folders-button")
                            .accessibilityValue(viewModel.sidebarListRefreshID.uuidString)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 6)

                        List {
                            OutlineGroup(viewModel.displayedNodes, children: \.children) { node in
                                HStack(spacing: 8) {
                                    Image(systemName: node.isDirectory ? "folder" : "doc.text")
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(.secondary)
                                    sidebarNodeTitle(for: node)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectNode(node)
                                }
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
            guard let mode = viewModel.importMode else { return }
            switch result {
            case .success(let urls):
                guard let pickedURL = urls.first else {
                    viewModel.importMode = nil
                    return
                }

                if mode == .file {
                    viewModel.openPickedFile(pickedURL)
                } else {
                    viewModel.openPickedFolder(pickedURL)
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
            viewModel.importMode = nil
        }
    }
}

#Preview {
    ContentView()
}
