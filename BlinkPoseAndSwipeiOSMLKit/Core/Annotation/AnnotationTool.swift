import Foundation

enum AnnotationTool: CaseIterable {
    case pen
    case highlighter
    case text
    case eraser

    var systemImageName: String {
        switch self {
        case .pen: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .text: return "textformat"
        case .eraser: return "eraser"
        }
    }
}
