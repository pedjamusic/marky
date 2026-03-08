import SwiftUI

#if os(macOS)
import AppKit

enum MarkyWindowChromeRole {
    case app
    case settings
}

struct MarkyWindowChromeStyle {
    let backgroundColor: NSColor
    let toolbarBackgroundVisibility: Visibility
    let titlebarAppearsTransparent: Bool
    let showsToolbarBaselineSeparator: Bool
}

struct MarkyWindowChromeModifier: ViewModifier {
    let style: MarkyWindowChromeStyle

    func body(content: Content) -> some View {
        content
            .background(MarkyWindowChromeConfigurator(style: style))
            .toolbarBackground(style.toolbarBackgroundVisibility, for: .windowToolbar)
    }
}

extension View {
    func markyWindowChrome(_ role: MarkyWindowChromeRole, colorScheme: ColorScheme) -> some View {
        modifier(
            MarkyWindowChromeModifier(
                style: MarkyTheme.windowChromeStyle(for: role, colorScheme: colorScheme)
            )
        )
    }
}

private struct MarkyWindowChromeConfigurator: NSViewRepresentable {
    let style: MarkyWindowChromeStyle

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view, style: style)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.attach(to: view, style: style)
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        private weak var view: NSView?
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        private var style = MarkyWindowChromeStyle(
            backgroundColor: .windowBackgroundColor,
            toolbarBackgroundVisibility: .automatic,
            titlebarAppearsTransparent: false,
            showsToolbarBaselineSeparator: true
        )

        func attach(to view: NSView, style: MarkyWindowChromeStyle) {
            self.view = view
            self.style = style

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.bindWindowIfNeeded()
                self.apply()
            }
        }

        func detach() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            window = nil
            view = nil
        }

        private func bindWindowIfNeeded() {
            guard let view, let resolvedWindow = view.window else { return }
            guard window !== resolvedWindow else { return }

            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            window = resolvedWindow

            let notifications: [Notification.Name] = [
                NSWindow.didBecomeKeyNotification,
                NSWindow.didResignKeyNotification,
                NSWindow.didBecomeMainNotification,
                NSWindow.didResignMainNotification,
                NSWindow.didUpdateNotification
            ]

            observers = notifications.map { name in
                NotificationCenter.default.addObserver(
                    forName: name,
                    object: resolvedWindow,
                    queue: .main
                ) { [weak self] _ in
                    self?.apply()
                }
            }
        }

        private func apply() {
            guard let window else { return }

            if window.backgroundColor != style.backgroundColor {
                window.backgroundColor = style.backgroundColor
            }

            if window.titlebarAppearsTransparent != style.titlebarAppearsTransparent {
                window.titlebarAppearsTransparent = style.titlebarAppearsTransparent
            }

            if let toolbar = window.toolbar,
               toolbar.showsBaselineSeparator != style.showsToolbarBaselineSeparator {
                toolbar.showsBaselineSeparator = style.showsToolbarBaselineSeparator
            }
        }
    }
}
#endif
