import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum MarkyTheme {
    // Terminal-inspired accent palette, authored in OKLCH.
    static let red = color(oklchL: 0.66, c: 0.16, h: 22)
    static let green = color(oklchL: 0.78, c: 0.14, h: 144)
    static let blue = color(oklchL: 0.70, c: 0.11, h: 246)
    static let yellow = color(oklchL: 0.85, c: 0.13, h: 95)

    // Semantic tokens for a subtle sidebar gradient overlay.
    #if os(macOS)
    static let sidebarLightOverlayGradientColors: [Color] = [
        Color(nsColor: nsRed).opacity(0.33),
        Color(nsColor: nsGreen).opacity(0.33),
        Color(nsColor: nsBlue).opacity(0.33),
        Color(nsColor: nsYellow).opacity(0.33)
    ]
    #else
    static let sidebarLightOverlayGradientColors: [Color] = [
        blue.opacity(0.34),
        green.opacity(0.24),
        yellow.opacity(0.18)
    ]
    #endif

    static let sidebarDarkOverlayGradientColors: [Color] = [
        red.opacity(0.28),
        blue.opacity(0.38),
        green.opacity(0.22),
        yellow.opacity(0.18)
    ]

    static let sidebarLightOverlayOpacity: Double = 0.24
    static let sidebarDarkOverlayOpacity: Double = 0.32

    // Sidebar control tokens
    static let sidebarControlRowSpacing: CGFloat = 8
    static let sidebarSearchFieldSpacing: CGFloat = 6
    static let sidebarSearchHorizontalPadding: CGFloat = 10
    static let sidebarSearchVerticalPadding: CGFloat = 7
    static let sidebarControlsHorizontalPadding: CGFloat = 8
    static let sidebarControlsTopPadding: CGFloat = 6
    static let sidebarSearchCornerRadius: CGFloat = 9
    static let sidebarControlsIconColor: Color = .secondary
    static let sidebarControlsTint: Color = .primary
    static let sidebarSearchBackgroundMaterial: Material = .regularMaterial

    #if os(macOS)
    static let nsRed = nsColor(oklchL: 0.66, c: 0.16, h: 22)
    static let nsYellow = nsColor(oklchL: 0.85, c: 0.13, h: 95)
    static let nsGreen = nsColor(oklchL: 0.78, c: 0.14, h: 144)
    static let nsBlue = nsColor(oklchL: 0.70, c: 0.11, h: 246)
    #endif

    private struct SRGBColor {
        let red: Double
        let green: Double
        let blue: Double
    }

    private static func color(oklchL l: Double, c: Double, h: Double) -> Color {
        let rgb = oklchToSRGB(l: l, c: c, h: h)
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    #if os(macOS)
    private static func nsColor(oklchL l: Double, c: Double, h: Double) -> NSColor {
        let rgb = oklchToSRGB(l: l, c: c, h: h)
        return NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1.0)
    }

    #endif

    private static func oklchToSRGB(l: Double, c: Double, h: Double) -> SRGBColor {
        let radians = h * .pi / 180
        let labA = c * cos(radians)
        let labB = c * sin(radians)

        let lPrime = l + 0.3963377774 * labA + 0.2158037573 * labB
        let mPrime = l - 0.1055613458 * labA - 0.0638541728 * labB
        let sPrime = l - 0.0894841775 * labA - 1.2914855480 * labB

        let lCube = lPrime * lPrime * lPrime
        let mCube = mPrime * mPrime * mPrime
        let sCube = sPrime * sPrime * sPrime

        let linearRed = 4.0767416621 * lCube - 3.3077115913 * mCube + 0.2309699292 * sCube
        let linearGreen = -1.2684380046 * lCube + 2.6097574011 * mCube - 0.3413193965 * sCube
        let linearBlue = -0.0041960863 * lCube - 0.7034186147 * mCube + 1.7076147010 * sCube

        return SRGBColor(
            red: gammaEncodeAndClamp(linearRed),
            green: gammaEncodeAndClamp(linearGreen),
            blue: gammaEncodeAndClamp(linearBlue)
        )
    }

    private static func gammaEncodeAndClamp(_ linear: Double) -> Double {
        let clampedLinear = min(max(linear, 0), 1)
        if clampedLinear <= 0.0031308 {
            return 12.92 * clampedLinear
        }
        return 1.055 * pow(clampedLinear, 1 / 2.4) - 0.055
    }
}
