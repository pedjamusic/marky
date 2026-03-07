import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
enum MarkdownTypographyMode: String, CaseIterable, Identifiable {
    case allSystem
    case serifHeadingsSystemBody
    case systemHeadingsSerifBody

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allSystem:
            return "All System"
        case .serifHeadingsSystemBody:
            return "Serif Headings + System Body"
        case .systemHeadingsSerifBody:
            return "System Headings + Serif Body"
        }
    }
}

private enum MarkdownTypographyFontFamily {
    case systemSans
    case literataSerif
}

private struct MarkdownTypographyProfile {
    let headingFamily: MarkdownTypographyFontFamily
    let bodyFamily: MarkdownTypographyFontFamily
    let bodyFontSize: CGFloat
    let bodyLineHeightMultiple: CGFloat
    let bodyParagraphSpacing: CGFloat
    let bodyTracking: CGFloat
    let paragraphBreakSpacingBefore: CGFloat
    let paragraphBlockSpacing: CGFloat

    let headingScales: [CGFloat]
    let headingLineHeights: [CGFloat]
    let headingSpacingBeforeMultipliers: [CGFloat]
    let headingSpacingAfterMultipliers: [CGFloat]
    let headingTracking: CGFloat

    let listIndent: CGFloat
    let listParagraphSpacing: CGFloat
    let listBlockSpacing: CGFloat
    let listItemSpacing: CGFloat
    let listMarkerGap: CGFloat
    let listMarkerColumnWidth: CGFloat
    let listMarkerScale: CGFloat
    let listBulletMarkerScale: CGFloat
    let nestedListSpacing: CGFloat
    let listLineHeightMultiple: CGFloat
    let quoteLineHeightMultiple: CGFloat
    let quoteObliqueness: CGFloat
    let quoteBlockSpacing: CGFloat
    let checkboxUncheckedSymbol: String
    let checkboxCheckedSymbol: String

    let codeFontScale: CGFloat
    let codeMinimumFontSize: CGFloat
    let codeBackgroundLightColor: NSColor
    let codeBackgroundDarkColor: NSColor
    let codeForegroundLightColor: NSColor
    let codeForegroundDarkColor: NSColor
    let codeBlockLineHeightMultiple: CGFloat
    let codeBlockParagraphSpacingBefore: CGFloat
    let codeBlockParagraphSpacingAfter: CGFloat
    let codeBlockHorizontalInset: CGFloat
    let codeBlockVerticalInset: CGFloat
    let codeBlockCornerRadius: CGFloat
    let linkColor: NSColor
    let linkUnderlineStyle: NSUnderlineStyle

    static func forMode(_ mode: MarkdownTypographyMode) -> Self {
        switch mode {
        case .allSystem:
            return baseProfile(
                headingFamily: .systemSans,
                bodyFamily: .systemSans
            )
        case .serifHeadingsSystemBody:
            return baseProfile(
                headingFamily: .literataSerif,
                bodyFamily: .systemSans
            )
        case .systemHeadingsSerifBody:
            return baseProfile(
                headingFamily: .systemSans,
                bodyFamily: .literataSerif,
                bodyFontSize: 17,
                bodyLineHeightMultiple: 1.42
            )
        }
    }

    private static func baseProfile(
        headingFamily: MarkdownTypographyFontFamily,
        bodyFamily: MarkdownTypographyFontFamily,
        bodyFontSize: CGFloat = 16,
        bodyLineHeightMultiple: CGFloat = 1.47
    ) -> Self {
        Self(
            headingFamily: headingFamily,
            bodyFamily: bodyFamily,
            bodyFontSize: bodyFontSize,
            bodyLineHeightMultiple: bodyLineHeightMultiple,
            bodyParagraphSpacing: bodyFontSize * 0.85,
            bodyTracking: 0.12,
            paragraphBreakSpacingBefore: bodyFontSize * 0.90,
            paragraphBlockSpacing: bodyFontSize * 0.92,
            headingScales: [1.90, 1.50, 1.25, 1.10, 1.00, 0.95],
            headingLineHeights: [1.12, 1.16, 1.20, 1.24, 1.26, 1.28],
            headingSpacingBeforeMultipliers: [2.20, 2.00, 1.70, 1.50, 1.35, 1.20],
            headingSpacingAfterMultipliers: [0.60, 0.50, 0.48, 0.42, 0.38, 0.36],
            headingTracking: -0.16,
            listIndent: 0,
            listParagraphSpacing: bodyFontSize * 0.30,
            listBlockSpacing: bodyFontSize * 0.80,
            listItemSpacing: bodyFontSize * 0.34,
            listMarkerGap: bodyFontSize * -0.04,
            listMarkerColumnWidth: bodyFontSize * 1.55,
            listMarkerScale: 1.0,
            listBulletMarkerScale: 1.12,
            nestedListSpacing: bodyFontSize * 0.20,
            listLineHeightMultiple: bodyLineHeightMultiple,
            quoteLineHeightMultiple: bodyLineHeightMultiple,
            quoteObliqueness: 0.06,
            quoteBlockSpacing: bodyFontSize * 1.10,
            checkboxUncheckedSymbol: "☐",
            checkboxCheckedSymbol: "☑",
            codeFontScale: 0.9,
            codeMinimumFontSize: 13,
            codeBackgroundLightColor: NSColor(srgbRed: 0.90, green: 0.90, blue: 0.93, alpha: 1.0),
            codeBackgroundDarkColor: NSColor(srgbRed: 0.20, green: 0.22, blue: 0.26, alpha: 1.0),
            codeForegroundLightColor: NSColor.labelColor,
            codeForegroundDarkColor: NSColor.labelColor,
            codeBlockLineHeightMultiple: 1.5,
            codeBlockParagraphSpacingBefore: bodyFontSize * 1.1,
            codeBlockParagraphSpacingAfter: bodyFontSize * 1.1,
            codeBlockHorizontalInset: 14,
            codeBlockVerticalInset: 14,
            codeBlockCornerRadius: 8,
            linkColor: NSColor.labelColor.withAlphaComponent(0.86),
            linkUnderlineStyle: .single
        )
    }
}

struct MarkdownTypography {
    private let profile: MarkdownTypographyProfile

    var bodyFontSize: CGFloat { profile.bodyFontSize }
    var bodyLineHeightMultiple: CGFloat { profile.bodyLineHeightMultiple }
    var bodyLineSpacing: CGFloat { bodyFontSize * max(0, bodyLineHeightMultiple - 1.0) }
    var bodyParagraphSpacing: CGFloat { profile.bodyParagraphSpacing }
    var bodyTracking: CGFloat { profile.bodyTracking }
    var paragraphBreakSpacingBefore: CGFloat { profile.paragraphBreakSpacingBefore }
    var paragraphBlockSpacing: CGFloat { profile.paragraphBlockSpacing }

    var headingScales: [CGFloat] { profile.headingScales }
    var headingLineHeights: [CGFloat] { profile.headingLineHeights }
    var headingTracking: CGFloat { profile.headingTracking }

    var listIndent: CGFloat { profile.listIndent }
    var listParagraphSpacing: CGFloat { profile.listParagraphSpacing }
    var listBlockSpacing: CGFloat { profile.listBlockSpacing }
    var listItemSpacing: CGFloat { profile.listItemSpacing }
    var listMarkerGap: CGFloat { profile.listMarkerGap }
    var listMarkerColumnWidth: CGFloat { profile.listMarkerColumnWidth }
    var listMarkerScale: CGFloat { profile.listMarkerScale }
    var listBulletMarkerScale: CGFloat { profile.listBulletMarkerScale }
    var nestedListSpacing: CGFloat { profile.nestedListSpacing }
    var listLineHeightMultiple: CGFloat { profile.listLineHeightMultiple }
    var quoteLineHeightMultiple: CGFloat { profile.quoteLineHeightMultiple }
    var quoteObliqueness: CGFloat { profile.quoteObliqueness }
    var quoteBlockSpacing: CGFloat { profile.quoteBlockSpacing }
    var checkboxUncheckedSymbol: String { profile.checkboxUncheckedSymbol }
    var checkboxCheckedSymbol: String { profile.checkboxCheckedSymbol }

    var codeFontScale: CGFloat { profile.codeFontScale }
    var codeMinimumFontSize: CGFloat { profile.codeMinimumFontSize }
    var codeBlockLineHeightMultiple: CGFloat { profile.codeBlockLineHeightMultiple }
    var codeBlockParagraphSpacingBefore: CGFloat { profile.codeBlockParagraphSpacingBefore }
    var codeBlockParagraphSpacingAfter: CGFloat { profile.codeBlockParagraphSpacingAfter }
    var codeBlockHorizontalInset: CGFloat { profile.codeBlockHorizontalInset }
    var codeBlockVerticalInset: CGFloat { profile.codeBlockVerticalInset }
    var codeBlockCornerRadius: CGFloat { profile.codeBlockCornerRadius }
    var linkColor: NSColor { profile.linkColor }
    var linkUnderlineStyle: NSUnderlineStyle { profile.linkUnderlineStyle }

    init(mode: MarkdownTypographyMode) {
        self.profile = MarkdownTypographyProfile.forMode(mode)
    }

    func codeBackgroundColor(isDarkMode: Bool) -> NSColor {
        isDarkMode ? profile.codeBackgroundDarkColor : profile.codeBackgroundLightColor
    }

    func codeForegroundColor(isDarkMode: Bool) -> NSColor {
        isDarkMode ? profile.codeForegroundDarkColor : profile.codeForegroundLightColor
    }

    func headingFont(for level: Int) -> NSFont {
        let clamped = min(max(level, 1), 6)
        let scale = headingScales[clamped - 1]
        let size = bodyFontSize * scale
        let weight: NSFont.Weight = clamped <= 2 ? .semibold : .medium
        return makeFont(family: profile.headingFamily, size: size, weight: weight)
    }

    func headingLineHeight(for level: Int) -> CGFloat {
        let clamped = min(max(level, 1), 6)
        return headingLineHeights[clamped - 1]
    }

    func headingSpacingBefore(for level: Int) -> CGFloat {
        let clamped = min(max(level, 1), 6)
        return bodyFontSize * profile.headingSpacingBeforeMultipliers[clamped - 1]
    }

    func headingSpacingAfter(for level: Int) -> CGFloat {
        let clamped = min(max(level, 1), 6)
        return bodyFontSize * profile.headingSpacingAfterMultipliers[clamped - 1]
    }

    func bodyFont() -> NSFont {
        makeFont(family: profile.bodyFamily, size: bodyFontSize, weight: .regular)
    }

    func listMarkerFont(for marker: String) -> NSFont {
        let scale = marker == "•" ? listBulletMarkerScale : listMarkerScale
        return makeFont(
            family: profile.bodyFamily,
            size: bodyFontSize * scale,
            weight: .regular
        )
    }

    private func makeFont(
        family: MarkdownTypographyFontFamily,
        size: CGFloat,
        weight: NSFont.Weight
    ) -> NSFont {
        switch family {
        case .systemSans:
            return NSFont.systemFont(ofSize: size, weight: weight)
        case .literataSerif:
            return literataFont(size: size, weight: weight)
        }
    }

    private func literataFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let preferredPostScriptNames: [String]
        if weight >= .semibold {
            preferredPostScriptNames = ["Literata-SemiBold", "Literata-Bold", "Literata"]
        } else {
            preferredPostScriptNames = ["Literata-Regular", "Literata"]
        }

        for name in preferredPostScriptNames {
            if let font = NSFont(name: name, size: size) {
                return font
            }
        }

        let base = NSFont.systemFont(ofSize: size, weight: weight)
        if
            let descriptor = base.fontDescriptor.withDesign(.serif),
            let serifFont = NSFont(descriptor: descriptor, size: size)
        {
            return serifFont
        }
        return base
    }
}
#endif
