import SwiftUI
import UIKit

/// 模块 D:就诊报告预览页。
/// 上方为 `ReportPage` 的实时预览,底部大按钮生成 PDF 并弹出系统分享。
struct EpisodeReportView: View {
    let episode: Episode

    @AppStorage("tempUnit") private var tempUnitRaw = TempUnit.celsius.rawValue
    private var unit: TempUnit { TempUnit(rawValue: tempUnitRaw) ?? .celsius }

    @State private var sharedPDF: SharedPDFFile?
    @State private var showRenderFailedAlert = false

    init(episode: Episode) {
        self.episode = episode
    }

    var body: some View {
        ScrollView {
            ReportPage(episode: episode, unit: unit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                .padding(16)
        }
        .background(Brand.pageBackground)
        .navigationTitle("就诊报告")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button {
                    generateAndShare()
                } label: {
                    Label("生成 PDF 并分享", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(BigActionButtonStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.bar)
        }
        .sheet(item: $sharedPDF) { file in
            PDFShareSheet(url: file.url)
                .presentationDetents([.medium, .large])
        }
        .alert("PDF 生成失败", isPresented: $showRenderFailedAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text("请稍后重试。")
        }
    }

    @MainActor
    private func generateAndShare() {
        if let url = ReportRenderer.renderPDF(episode: episode, unit: unit) {
            sharedPDF = SharedPDFFile(url: url)
        } else {
            showRenderFailedAlert = true
        }
    }
}

/// 让生成的 PDF 文件可用于 `.sheet(item:)`。
private struct SharedPDFFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// UIActivityViewController 的 SwiftUI 包装,用于分享生成的 PDF。
private struct PDFShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
