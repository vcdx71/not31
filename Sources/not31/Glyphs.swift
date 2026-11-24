import AppKit
import CoreImage
import Foundation

enum CalendarIconRenderer {
    // Vector glyph outlines extracted from Google Sans Flex (SIL Open Font License 1.1)
    // at 544pt (wght=500, ROND=50, opsz=144) in 1024x1024 canvas space.
    private static let digitPaths: [Character: String] = [
        "0": "M168.81,-5.17 Q101.46,-5.17,58.82,50.59 Q16.18,106.35,16.18,194.75 L16.18,194.75 Q16.18,283.42,58.86,339.05 Q101.55,394.67,168.81,394.67 Q236.1,394.67,278.82,338.87 Q321.55,283.06,321.55,194.75 L321.55,194.75 Q321.55,106.71,278.87,50.77 Q236.19,-5.17,168.81,-5.17 Z M168.86,47.69 Q211.71,47.69,237.91,87.45 Q264.11,127.21,264.11,194.64 L264.11,194.64 Q264.11,262.39,237.77,302.1 Q211.43,341.81,168.77,341.81 Q126.3,341.81,99.96,301.92 Q73.62,262.03,73.62,194.73 L73.62,194.73 Q73.62,127.84,99.87,87.77 Q126.12,47.69,168.86,47.69 Z",
        "1": "M125.12,-1.56 Q119.41,-1.56,115.33,2.58 Q111.25,6.73,111.25,12.49 L111.25,317.04 L38.22,264.61 Q34.09,261.5,29.05,262.47 Q24,263.43,21.19,267.83 L7.98,288.25 Q5.39,292.26,6.36,297.13 Q7.32,301.99,11.11,304.78 L127.52,388.78 Q129.06,389.89,131.17,390.73 Q133.28,391.57,135.91,391.57 L154.39,391.57 Q159.8,391.57,163.27,387.84 Q166.74,384.11,166.74,378.26 L166.74,12.49 Q166.74,6.73,162.66,2.58 Q158.58,-1.56,152.86,-1.56 Z",
        "2": "M32.28,0 Q25.82,0,21.38,4.39 Q16.93,8.77,16.93,15.07 L16.93,37.58 Q16.93,41.17,18.28,43.74 Q19.63,46.31,21.42,48.19 L146.51,177.98 Q185.78,218.69,198.79,238.91 Q211.79,259.13,211.79,282.65 L211.79,282.65 Q211.79,310.04,194.48,326.36 Q177.16,342.67,145.07,342.67 Q126.53,342.67,112.72,337.57 Q98.92,332.47,88.3,321.5 Q77.68,310.53,69.61,297.92 Q61.54,285.3,57.05,284.2 Q52.56,283.11,48.28,285.62 L26.34,297.93 Q21.94,300.45,20.74,305.63 Q19.54,310.81,27.81,326.06 Q36.09,341.31,53.4,358.59 Q70.72,375.86,94.2,385.26 Q117.69,394.67,148.69,394.67 Q204.68,394.67,236.44,364.75 Q268.19,334.82,268.19,287.78 L268.19,287.78 Q268.19,254.55,251.42,227.26 Q234.65,199.97,191.17,155.22 L89.99,51.05 L89.99,51.05 L268.24,51.05 Q273.56,51.05,277.36,47.26 Q281.16,43.48,281.16,38.28 L281.16,12.76 Q281.16,7.57,277.36,3.78 Q273.56,0,268.24,0 Z",
        "3": "M150.7,-5.17 Q114.97,-5.17,89.73,5.74 Q64.49,16.64,47.66,35.22 Q30.83,53.81,24.37,70.29 Q17.91,86.77,19.64,91.82 Q21.37,96.88,25.7,98.87 L49.25,107.96 Q53.58,109.96,57.9,108.7 Q62.22,107.44,67.91,96.03 Q73.6,84.62,83.65,71.81 Q93.7,59,108.66,51.69 Q123.62,44.38,147.29,44.38 Q184.51,44.38,204.61,62.18 Q224.71,79.97,224.71,112.7 L224.71,112.7 Q224.71,144.75,204.79,161.91 Q184.87,179.07,144.7,179.07 L113.08,179.07 Q108.26,179.07,104.89,182.52 Q101.52,185.98,101.52,190.81 L101.52,214.29 Q101.52,219.12,104.91,222.57 Q108.3,226.03,113.17,226.03 L141.03,226.03 Q175.07,226.03,194.16,242.78 Q213.25,259.53,213.25,284.87 L213.25,284.87 Q213.25,312.75,196.41,329.21 Q179.58,345.67,147.72,345.67 Q129.68,345.67,116.56,340.08 Q103.45,334.49,93.94,324.44 Q84.43,314.39,77.09,302.86 Q69.75,291.33,65.55,290.09 Q61.36,288.84,57.23,290.84 L35.43,300.2 Q31.19,302.19,29.76,306.71 Q28.33,311.24,35.79,326.41 Q43.25,341.59,59.86,358.9 Q76.48,376.22,98.9,385.45 Q121.31,394.67,151.32,394.67 Q203.94,394.67,234.57,367.7 Q265.2,340.73,265.2,296.39 L265.2,296.39 Q265.2,265.65,248.58,241.65 Q231.97,217.65,202.33,208.74 L202.33,208.76 Q237.46,202.28,259.12,175.34 Q280.79,148.4,280.79,111.59 L280.79,111.59 Q280.79,59.02,245.57,26.93 Q210.35,-5.17,150.7,-5.17 Z",
        "4": "M215.15,-1.45 Q209.8,-1.45,205.99,2.43 Q202.19,6.3,202.19,11.67 L202.19,106.53 L202.19,113.79 L202.19,334.74 L226.26,316.43 L200.92,316.43 L69.32,131.2 L224.26,131.2 L235.6,131.2 L292.45,131.2 Q297.5,131.2,301.06,127.59 Q304.62,123.99,304.62,119.07 L304.62,94.93 Q304.62,90.01,301.06,86.46 Q297.5,82.91,292.45,82.91 L24.91,82.91 Q18.7,82.91,14.6,86.76 Q10.49,90.6,10.49,96.27 L10.49,116.1 Q10.49,118.5,11.2,120.69 Q11.9,122.88,13.46,125.19 L193.37,383.04 Q195.61,386.33,199.6,388.82 Q203.59,391.32,208.24,391.32 L236.25,391.32 Q243.78,391.32,248.8,386 Q253.82,380.69,253.82,373.16 L253.82,11.67 Q253.82,6.3,250.01,2.43 Q246.21,-1.45,240.97,-1.45 Z",
        "5": "M159.53,-5.17 Q125.07,-5.17,98.79,5.94 Q72.51,17.05,54.56,36.83 Q36.61,56.62,29.24,76.32 Q21.87,96.02,23.64,101.21 Q25.41,106.4,30.08,108.23 L53.81,117.57 Q58.48,119.41,62.62,117.71 Q66.75,116.01,72.36,101.91 Q77.97,87.81,89.59,74.01 Q101.21,60.21,118.19,52.36 Q135.18,44.52,158.33,44.52 Q194.16,44.52,217.89,67.48 Q241.63,90.44,241.63,125.14 L241.63,125.14 Q241.63,160.07,217.96,183.24 Q194.3,206.4,158.39,206.4 Q138.27,206.4,123.34,200.25 Q108.41,194.09,89.13,175.51 Q85.86,172.65,81.05,172.03 Q76.23,171.41,71.49,173.54 L47.99,183.55 Q42.95,185.78,40.27,190.76 Q37.58,195.75,38.4,201.71 L61.46,373.14 Q62.28,379.78,67.7,384.64 Q73.12,389.5,79.89,389.5 L258.92,389.5 Q264.27,389.5,268.07,385.72 Q271.86,381.93,271.86,376.72 L271.86,351.15 Q271.86,345.94,268.07,342.15 Q264.27,338.37,258.92,338.37 L101.64,338.37 L85.73,222.09 L85.73,222.09 Q98.74,235.51,119.52,244.41 Q140.31,253.32,167.69,253.32 Q222.5,253.32,259.46,217.64 Q296.43,181.97,296.43,126.71 L296.43,126.71 Q296.43,69.04,257.52,31.94 Q218.6,-5.17,159.53,-5.17 Z",
        "6": "M159.62,-5.17 Q97.74,-5.17,58.48,31.46 Q19.22,68.09,19.22,124.98 L19.22,124.98 Q19.22,167.28,36.11,200.94 Q52.99,234.6,87.08,276.03 L177.66,386.63 Q180.99,390.82,186.15,391.49 Q191.31,392.16,195.45,389.07 L217.19,373.12 Q221.93,369.67,222.71,364.18 Q223.49,358.7,219.44,354.23 L121.32,237.32 Q110.78,224.9,84.1,201.05 Q57.42,177.21,50.84,126.91 L33.52,126.48 Q44.4,193.75,85.88,223.13 Q127.36,252.51,173.22,252.51 Q226.39,252.51,262.86,217.44 Q299.34,182.38,299.34,125.89 L299.34,125.89 Q299.34,68.59,260.2,31.71 Q221.06,-5.17,159.62,-5.17 Z M158.53,44.25 Q196.97,44.25,221.75,66.94 Q246.52,89.62,246.52,124.98 L246.52,124.98 Q246.52,160.57,221.92,183.49 Q197.32,206.4,159.44,206.4 Q121.54,206.4,96.9,183.49 Q72.26,160.57,72.26,124.98 L72.26,124.98 Q72.26,89.63,96.59,66.94 Q120.92,44.25,158.53,44.25 Z",
        "7": "M37.63,7.98 Q32.66,10.43,30.91,15.78 Q29.15,21.13,31.8,26.32 L199.74,337.96 L199.74,337.96 L19.33,337.96 Q13.94,337.96,10.11,341.78 Q6.28,345.6,6.28,350.85 L6.28,376.63 Q6.28,381.87,10.11,385.69 Q13.94,389.5,19.33,389.5 L245.75,389.5 Q252.87,389.5,257.71,384.94 Q262.55,380.37,262.55,373.64 Q262.55,349.66,262.08,348.14 Q261.62,346.62,259.71,342.67 L79.93,2.27 Q77.45,-2.81,72.16,-4.61 Q66.87,-6.41,61.88,-3.97 Z",
        "8": "M156.13,-5.17 Q97.01,-5.17,59.25,26.2 Q21.49,57.57,21.49,107.03 L21.49,107.03 Q21.49,144.07,43.5,172.13 Q65.51,200.19,95.88,208.53 L95.88,208.53 Q70.31,218.33,54.47,239.7 Q38.62,261.07,38.62,292.99 L38.62,292.99 Q38.62,338.59,71.19,366.63 Q103.75,394.67,156.13,394.67 Q208.49,394.67,241.06,366.9 Q273.63,339.14,273.63,293.81 L273.63,293.81 Q273.63,261.07,257.79,239.7 Q241.94,218.33,216.38,208.53 L216.38,208.53 Q246.75,200.19,268.76,172.13 Q290.77,144.07,290.77,107.03 L290.77,107.03 Q290.77,57.97,253,26.4 Q215.24,-5.17,156.13,-5.17 Z M156.13,42.8 Q192.44,42.8,215.04,62.15 Q237.63,81.51,237.63,112.56 L237.63,112.56 Q237.63,143.89,215.04,163.7 Q192.44,183.51,156.13,183.51 Q119.82,183.51,97.22,163.7 Q74.62,143.89,74.62,112.56 L74.62,112.56 Q74.62,81.5,97.22,62.15 Q119.82,42.8,156.13,42.8 Z M156.12,229.3 Q187.63,229.3,205.29,246.02 Q222.95,262.75,222.95,288.55 L222.95,288.55 Q222.95,314.76,204.61,331 Q186.28,347.25,156.13,347.25 Q125.98,347.25,107.65,331 Q89.31,314.76,89.31,288.55 L89.31,288.55 Q89.31,262.75,106.96,246.02 Q124.61,229.3,156.12,229.3 Z",
        "9": "M157.49,394.67 Q219.37,394.67,258.63,358.04 Q297.89,321.41,297.89,264.52 L297.89,264.52 Q297.89,222.22,281,188.56 Q264.11,154.9,230.02,113.47 L139.45,2.88 Q136.11,-1.31,130.96,-1.98 Q125.8,-2.65,121.65,0.43 L99.91,16.39 Q95.17,19.83,94.39,25.32 Q93.61,30.8,97.67,35.27 L195.79,152.18 Q206.33,164.61,233.01,188.45 Q259.69,212.3,266.26,262.59 L283.58,263.02 Q272.7,195.75,231.22,166.37 Q189.74,137,143.89,137 Q90.71,137,54.24,172.06 Q17.77,207.13,17.77,263.61 L17.77,263.61 Q17.77,320.91,56.91,357.79 Q96.05,394.67,157.49,394.67 Z M158.58,345.26 Q120.13,345.26,95.36,322.57 Q70.58,299.88,70.58,264.52 L70.58,264.52 Q70.58,228.93,95.18,206.02 Q119.78,183.1,157.67,183.1 Q195.57,183.1,220.21,206.02 Q244.84,228.93,244.84,264.52 L244.84,264.52 Q244.84,299.87,220.51,322.56 Q196.18,345.26,158.58,345.26 Z",
    ]

    private static let dayPlacements: [Int: [(Character, CGFloat, CGFloat)]] = [
        1: [("1", 426.05, 320.98)],
        2: [("2", 362.94, 318.66)],
        3: [("3", 362.67, 321.25)],
        4: [("4", 354.51, 321.11)],
        5: [("5", 352.88, 323.83)],
        6: [("6", 352.74, 322.47)],
        7: [("7", 377.5, 324.51)],
        8: [("8", 355.87, 321.25)],
        9: [("9", 354.1, 320.02)],
        10: [("1", 234.78, 321.25), ("0", 446.28, 321.25)],
        11: [("1", 320.3, 320.98), ("1", 531.8, 320.98)],
        12: [("1", 255.04, 319.48), ("2", 466.54, 319.48)],
        13: [("1", 255.18, 321.25), ("3", 466.68, 321.25)],
        14: [("1", 243.34, 320.98), ("4", 454.85, 320.98)],
        15: [("1", 247.42, 322.74), ("5", 458.93, 322.74)],
        16: [("1", 245.93, 322.47), ("6", 457.43, 322.47)],
        17: [("1", 264.29, 323.42), ("7", 475.79, 323.42)],
        18: [("1", 250.28, 321.25), ("8", 461.78, 321.25)],
        19: [("1", 246.61, 320.02), ("9", 458.11, 320.02)],
        20: [("2", 196.72, 321.25), ("0", 488.64, 321.25)],
        21: [("2", 269.99, 319.48), ("1", 550.41, 319.48)],
        22: [("2", 216.98, 318.66), ("2", 508.91, 318.66)],
        23: [("2", 217.12, 321.25), ("3", 509.04, 321.25)],
        24: [("2", 209.46, 319.48), ("4", 493.04, 319.48)],
        25: [("2", 212.2, 321.25), ("5", 498.46, 321.25)],
        26: [("2", 207.87, 321.25), ("6", 499.79, 321.25)],
        27: [("2", 229.95, 321.93), ("7", 514.44, 321.93)],
        28: [("2", 212.22, 321.25), ("8", 504.15, 321.25)],
        29: [("2", 211.27, 320.02), ("9", 497.75, 320.02)],
        30: [("3", 192.12, 321.25), ("0", 492.43, 321.25)],
        31: [("3", 260, 321.25), ("1", 559.59, 321.25)],
    ]

    private static func srgb(_ hex: UInt32, alpha: CGFloat = 1.0) -> CGColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        return CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
    }

    private static func decodePath(_ spec: String, dx: CGFloat, dy: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for token in spec.split(separator: " ") {
            guard let cmd = token.first else { continue }
            let nums = token.dropFirst().split(separator: ",").compactMap { Double($0).map { CGFloat($0) } }
            switch cmd {
            case "M" where nums.count == 2:
                path.move(to: CGPoint(x: nums[0] + dx, y: nums[1] + dy))
            case "L" where nums.count == 2:
                path.addLine(to: CGPoint(x: nums[0] + dx, y: nums[1] + dy))
            case "Q" where nums.count == 4:
                path.addQuadCurve(
                    to: CGPoint(x: nums[2] + dx, y: nums[3] + dy),
                    control: CGPoint(x: nums[0] + dx, y: nums[1] + dy)
                )
            case "C" where nums.count == 6:
                path.addCurve(
                    to: CGPoint(x: nums[4] + dx, y: nums[5] + dy),
                    control1: CGPoint(x: nums[0] + dx, y: nums[1] + dy),
                    control2: CGPoint(x: nums[2] + dx, y: nums[3] + dy)
                )
            case "Z":
                path.closeSubpath()
            default:
                break
            }
        }
        return path
    }

    /// Renders the 1024x1024 transparent Google Calendar 2026 glyph for `day` (1...31)
    /// purely via CoreGraphics + CoreImage (zero external PNGs or font files required).
    static func renderGlyph(day: Int) throws -> NSImage {
        guard let placements = dayPlacements[day] else {
            throw NSError(domain: "Not31", code: 10, userInfo: [
                NSLocalizedDescriptionKey: "Invalid calendar day \(day) (expected 1...31)"
            ])
        }

        let S: CGFloat = 1024.0 / 192.0
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(
            data: nil,
            width: 1024,
            height: 1024,
            bitsPerComponent: 8,
            bytesPerRow: 1024 * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "Not31", code: 11, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create 1024x1024 CGContext"
            ])
        }

        ctx.saveGState()
        ctx.translateBy(x: 0, y: 1024)
        ctx.scaleBy(x: S, y: -S)

        // 1. Top light-blue back tab (#bbe2ff)
        let backTab = CGPath(
            roundedRect: CGRect(x: 32, y: 8, width: 128, height: 88),
            cornerWidth: 28.8,
            cornerHeight: 28.8,
            transform: nil
        )
        ctx.addPath(backTab)
        ctx.setFillColor(srgb(0xbbe2ff))
        ctx.fillPath()

        // 2. Folded hourglass card body (#3c90ff)
        let card = CGMutablePath()
        card.move(to: CGPoint(x: 19.867, y: 49.392))
        card.addCurve(to: CGPoint(x: 45.645, y: 20), control1: CGPoint(x: 17.818, y: 33.82), control2: CGPoint(x: 29.94, y: 20))
        card.addLine(to: CGPoint(x: 146.355, y: 20))
        card.addCurve(to: CGPoint(x: 172.133, y: 49.392), control1: CGPoint(x: 162.061, y: 20), control2: CGPoint(x: 174.182, y: 33.82))
        card.addLine(to: CGPoint(x: 166, y: 96))
        card.addLine(to: CGPoint(x: 172.133, y: 142.608))
        card.addCurve(to: CGPoint(x: 146.355, y: 172), control1: CGPoint(x: 174.182, y: 158.18), control2: CGPoint(x: 162.061, y: 172))
        card.addLine(to: CGPoint(x: 45.645, y: 172))
        card.addCurve(to: CGPoint(x: 19.867, y: 142.608), control1: CGPoint(x: 29.94, y: 172), control2: CGPoint(x: 17.818, y: 158.18))
        card.addLine(to: CGPoint(x: 26, y: 96))
        card.closeSubpath()

        ctx.addPath(card)
        ctx.setFillColor(srgb(0x3c90ff))
        ctx.fillPath()

        // 3. Bottom crease gradient (#4fa0ff -> #3186ff)
        ctx.saveGState()
        ctx.addPath(card)
        ctx.clip()
        ctx.clip(to: CGRect(x: 13, y: 96, width: 166, height: 76))
        let gradB = CGGradient(
            colorsSpace: cs,
            colors: [srgb(0x4fa0ff), srgb(0x3186ff)] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawLinearGradient(
            gradB,
            start: CGPoint(x: 96, y: 96),
            end: CGPoint(x: 96, y: 172),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        ctx.restoreGState()
        ctx.restoreGState()

        // 4. Top lavender-blue glow (#a9a8ff -> #3c90ff) with Gaussian blur clipped to card
        if let glowCtx = CGContext(
            data: nil,
            width: 1024,
            height: 1024,
            bitsPerComponent: 8,
            bytesPerRow: 1024 * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) {
            glowCtx.translateBy(x: 0, y: 1024)
            glowCtx.scaleBy(x: S, y: -S)
            let glowShape = CGMutablePath()
            glowShape.move(to: CGPoint(x: 32, y: 96))
            glowShape.addLine(to: CGPoint(x: 32, y: 27.2))
            glowShape.addCurve(to: CGPoint(x: 51.2, y: 8), control1: CGPoint(x: 32, y: 16.596), control2: CGPoint(x: 40.596, y: 8))
            glowShape.addLine(to: CGPoint(x: 140.8, y: 8))
            glowShape.addCurve(to: CGPoint(x: 160, y: 27.2), control1: CGPoint(x: 151.404, y: 8), control2: CGPoint(x: 160, y: 16.596))
            glowShape.addLine(to: CGPoint(x: 160, y: 96))
            glowShape.closeSubpath()
            glowCtx.addPath(glowShape)
            glowCtx.clip()

            let gradD = CGGradient(
                colorsSpace: cs,
                colors: [srgb(0xa9a8ff), srgb(0x3c90ff)] as CFArray,
                locations: [0.0, 0.8]
            )!
            glowCtx.drawLinearGradient(
                gradD,
                start: CGPoint(x: 89.06, y: 21.75),
                end: CGPoint(x: 89.06, y: 96.39),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )

            if let glowImg = glowCtx.makeImage(),
               let filter = CIFilter(name: "CIGaussianBlur") {
                let ciInput = CIImage(cgImage: glowImg)
                filter.setValue(ciInput, forKey: kCIInputImageKey)
                filter.setValue(6.0 * S, forKey: kCIInputRadiusKey)
                let ciCtx = CIContext(options: [.workingColorSpace: cs, .outputColorSpace: cs])
                if let output = filter.outputImage,
                   let blurredCG = ciCtx.createCGImage(output, from: CGRect(x: 0, y: 0, width: 1024, height: 1024)) {
                    ctx.saveGState()
                    var flipTransform = CGAffineTransform(translationX: 0, y: 1024).scaledBy(x: S, y: -S)
                    if let scaledCard = card.copy(using: &flipTransform) {
                        ctx.addPath(scaledCard)
                        ctx.clip()
                        ctx.draw(blurredCG, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
                    }
                    ctx.restoreGState()
                }
            }
        }

        // 5. Crisp white day numerals
        let digitsPath = CGMutablePath()
        for (ch, dx, dy) in placements {
            if let spec = digitPaths[ch] {
                digitsPath.addPath(decodePath(spec, dx: dx, dy: dy))
            }
        }
        ctx.addPath(digitsPath)
        ctx.setFillColor(srgb(0xffffff))
        ctx.fillPath(using: .winding)

        guard let finalCG = ctx.makeImage() else {
            throw NSError(domain: "Not31", code: 12, userInfo: [
                NSLocalizedDescriptionKey: "Failed to extract rendered CGImage"
            ])
        }

        let nsImg = NSImage(size: NSSize(width: 1024, height: 1024))
        nsImg.addRepresentation(NSBitmapImageRep(cgImage: finalCG))
        return nsImg
    }
}
