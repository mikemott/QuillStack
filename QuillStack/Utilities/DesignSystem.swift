import SwiftUI

// ============================================================
// MARK: - THE LUMINESCENT NOIR DIRECTIVE
// ============================================================

// MARK: - Surface Architecture (Tonal Stepping)
// No borders. Structure is defined through tonal shifts.
// Each level "closer to the light" = lighter surface.

enum QSSurface {
    // Base Layer — the deepest, furthest from light
    static let lowest = Color(hex: "#0e0e0e")
    static let base = Color(hex: "#0e0e0e")

    // Secondary Content Areas
    static let containerLow = Color(hex: "#131313")
    static let container = Color(hex: "#1a1919")

    // Interactive Cards / Modals — closest to the "light"
    static let containerHigh = Color(hex: "#222222")
    static let containerHighest = Color(hex: "#262626")

    // Bright — for hover states, elevated surfaces
    static let bright = Color(hex: "#393939")
}

// MARK: - Color Palette

enum QSColor {
    // Primary — soft white, the lighthouse
    static let primary = Color(hex: "#E0E0E0")
    static let primaryDim = Color(hex: "#E0E0E0").opacity(0.30)
    static let primaryContainer = Color(hex: "#E0E0E0")
    static let onPrimaryDark = Color(hex: "#0e0e0e")

    // Secondary — steel, for supporting UI elements
    static let secondary = Color(hex: "#6F778B")
    static let secondaryDim = Color(hex: "#6F778B").opacity(0.30)
    static let secondaryContainer = Color(hex: "#474646")

    // Tertiary — cool blue, the light that cuts through the dark
    static let tertiary = Color(hex: "#5574C4")
    static let tertiaryDim = Color(hex: "#5574C4").opacity(0.25)

    // Neutral
    static let neutral = Color(hex: "#79776C")

    // On-Surface Text Hierarchy
    // RULE: Never use #FFFFFF for body text. It causes haloing on OLED.
    static let onSurface = Color(hex: "#E5E2E1")         // Headlines, primary text
    static let onSurfaceVariant = Color(hex: "#ADAAAA")   // Body text, secondary
    static let onSurfaceMuted = Color(hex: "#737070")     // Tertiary, timestamps
    static let onPrimary = Color(hex: "#1A1900")          // Text on primary bg

    // Ghost Border — "felt, not seen"
    static let ghostBorder = Color(hex: "#494847").opacity(0.15)

    // Outline variant for rare structural needs
    static let outlineVariant = Color(hex: "#494847")
}

// MARK: - Elevation & Depth
// Depth through Tonal Stack, not drop shadows.
// Ambient shadows: 40-60px blur, 10% max, tinted black.

struct QSAmbientShadow: ViewModifier {
    var radius: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content.shadow(
            color: Color.black.opacity(opacity),
            radius: radius,
            x: 0,
            y: radius * 0.25
        )
    }
}

extension View {
    func qsAmbientShadow(radius: CGFloat = 50, opacity: Double = 0.10) -> some View {
        modifier(QSAmbientShadow(radius: radius, opacity: opacity))
    }
}

// MARK: - The Glass & Gradient Recipe
// 3-layer construction:
//   1. Bottom: Radial gradient of primaryDim at 30%, off-center
//   2. Middle: surface at 60% opacity + backdrop-blur 20px
//   3. Top: Content

struct QSGlassModifier: ViewModifier {
    var glowColor: Color = QSColor.primaryDim
    var glowCenter: UnitPoint = .topLeading
    var glowIntensity: Double = 0.30
    var surfaceOpacity: Double = 0.60

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Layer 1: Radial glow
                    RadialGradient(
                        colors: [
                            glowColor.opacity(glowIntensity),
                            Color.clear,
                        ],
                        center: glowCenter,
                        startRadius: 0,
                        endRadius: 300
                    )
                    // Layer 2: Surface + blur
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    QSSurface.base.opacity(surfaceOpacity)
                }
            }
    }
}

extension View {
    func qsGlass(
        glow: Color = QSColor.primaryDim,
        center: UnitPoint = .topLeading,
        intensity: Double = 0.30,
        surfaceOpacity: Double = 0.60
    ) -> some View {
        modifier(QSGlassModifier(
            glowColor: glow,
            glowCenter: center,
            glowIntensity: intensity,
            surfaceOpacity: surfaceOpacity
        ))
    }
}

// MARK: - Ghost Border
// Only when accessibility demands a container boundary.
// 1px, outlineVariant at 15%. "Felt, not seen."

extension View {
    func qsGhostBorder(cornerRadius: CGFloat = 0) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(QSColor.ghostBorder, lineWidth: 1)
        )
    }
}
