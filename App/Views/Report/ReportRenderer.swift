import SwiftUI

// MARK: - PDF 渲染

/// 把 `ReportPage` 渲染成 A4 比例(595×842pt)的 PDF,内容超过一页时自动分页。
@MainActor
enum ReportRenderer {
    static func renderPDF(episode: Episode, unit: TempUnit) -> URL? {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842

        let renderer = ImageRenderer(
            content: ReportPage(episode: episode, unit: unit)
                .frame(width: pageWidth)
        )
        renderer.proposedSize = ProposedViewSize(width: pageWidth, height: nil)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(pdfFileName(for: episode))

        var succeeded = false
        renderer.render { size, renderContent in
            var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                return
            }

            let contentHeight = max(size.height, 1)
            let pageCount = max(1, Int(ceil(contentHeight / pageHeight)))

            for pageIndex in 0..<pageCount {
                pdfContext.beginPDFPage(nil)
                pdfContext.setFillColor(gray: 1, alpha: 1)
                pdfContext.fill(mediaBox)
                pdfContext.saveGState()
                pdfContext.clip(to: mediaBox)
                // PDF 坐标系原点在左下角:整体平移后,第 pageIndex 页
                // 恰好露出内容自顶向下第 pageIndex 屏的部分。
                let offsetY = CGFloat(pageIndex + 1) * pageHeight - contentHeight
                pdfContext.translateBy(x: 0, y: offsetY)
                renderContent(pdfContext)
                pdfContext.restoreGState()
                pdfContext.endPDFPage()
            }
            pdfContext.closePDF()
            succeeded = true
        }

        return succeeded ? url : nil
    }

    private static func pdfFileName(for episode: Episode) -> String {
        var name = "发烧病程记录"
        if let childName = episode.child?.name, !childName.isEmpty {
            name += "-\(childName)"
        }
        name += "-\(Fmt.monthDay.string(from: episode.startedAt))"
        name = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return name + ".pdf"
    }
}

// MARK: - 报告版式

/// 就诊报告的单页版式,预览与 PDF 共用。
/// 固定浅色配色(打印友好),温度按传入的 unit 显示;只陈述事实,不含任何建议。
struct ReportPage: View {
    let episode: Episode
    let unit: TempUnit

    init(episode: Episode, unit: TempUnit) {
        self.episode = episode
        self.unit = unit
    }

    // 固定配色,不随深色模式变化
    private let inkPrimary = Color.black
    private let inkSecondary = Color(white: 0.4)
    private let hairline = Color.black.opacity(0.15)
    private let boxFill = Color(white: 0.95)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            infoSection
            statsSection
            if !medicationStats.isEmpty {
                medicationSection
            }
            chartSection
            eventTableSection
            footer
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    // MARK: 标题

    private var header: some View {
        VStack(spacing: 12) {
            Text("发烧病程记录")
                .font(.title2.weight(.bold))
                .foregroundStyle(inkPrimary)
                .frame(maxWidth: .infinity)
            Rectangle()
                .fill(hairline)
                .frame(height: 1)
        }
    }

    // MARK: 基本信息

    private var childText: String {
        guard let child = episode.child else { return "—" }
        if let age = child.ageDescription {
            return "\(child.name)(\(age))"
        }
        return child.name
    }

    private var endText: String {
        if let endedAt = episode.endedAt {
            return Fmt.monthDayTime.string(from: endedAt)
        }
        return "记录中"
    }

    private var infoSection: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
            GridRow {
                infoItem(label: "孩子", value: childText)
                infoItem(label: "持续时长", value: episode.durationDescription)
            }
            GridRow {
                infoItem(label: "开始时间", value: Fmt.monthDayTime.string(from: episode.startedAt))
                infoItem(label: "结束时间", value: endText)
            }
        }
    }

    private func infoItem(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(inkSecondary)
            Text(value)
                .font(.footnote.weight(.medium))
                .foregroundStyle(inkPrimary)
        }
    }

    // MARK: 统计

    private var maxTempText: String {
        guard let maxC = episode.maxTemperatureC else { return "—" }
        return Temp.display(maxC, unit: unit)
    }

    private var maxTempColor: Color {
        guard let maxC = episode.maxTemperatureC else { return inkPrimary }
        return Temp.color(for: maxC)
    }

    private var statsSection: some View {
        HStack(spacing: 10) {
            statBox(title: "最高体温", value: maxTempText, valueColor: maxTempColor)
            statBox(title: "测温次数", value: "\(episode.temperatureEvents.count) 次", valueColor: inkPrimary)
            statBox(title: "用药次数", value: "\(episode.medicationEvents.count) 次", valueColor: inkPrimary)
        }
    }

    private func statBox(title: String, value: String, valueColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(inkSecondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(boxFill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: 用药统计(按药名分列)

    private var medicationStats: [(name: String, count: Int)] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for event in episode.medicationEvents {
            let name: String
            if let medicationName = event.medicationName, !medicationName.isEmpty {
                name = medicationName
            } else {
                name = "未填写药名"
            }
            if counts[name] == nil { order.append(name) }
            counts[name, default: 0] += 1
        }
        return order.map { (name: $0, count: counts[$0] ?? 0) }
    }

    private var medicationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("用药统计(按药名)")
            ForEach(medicationStats, id: \.name) { stat in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("•")
                        .foregroundStyle(inkSecondary)
                    Text(stat.name)
                        .foregroundStyle(inkPrimary)
                    Text("共 \(stat.count) 次")
                        .foregroundStyle(inkSecondary)
                }
                .font(.footnote)
            }
        }
    }

    // MARK: 体温曲线

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("体温曲线")
            TemperatureChartView(episode: episode, compact: false)
                .frame(height: 220)
        }
    }

    // MARK: 记录明细表格

    private var eventTableSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("记录明细")
                .padding(.bottom, 8)

            if episode.sortedEvents.isEmpty {
                Text("暂无记录")
                    .font(.footnote)
                    .foregroundStyle(inkSecondary)
                    .padding(.vertical, 8)
            } else {
                tableRow(time: "时间", type: "类型", content: "内容", isHeader: true)
                Rectangle()
                    .fill(hairline)
                    .frame(height: 1)
                ForEach(episode.sortedEvents) { event in
                    tableRow(
                        time: Fmt.monthDayTime.string(from: event.timestamp),
                        type: event.kind.label,
                        content: contentText(for: event),
                        isHeader: false
                    )
                    Rectangle()
                        .fill(hairline.opacity(0.5))
                        .frame(height: 0.5)
                }
            }
        }
    }

    private func tableRow(time: String, type: String, content: String, isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(time)
                .frame(width: 104, alignment: .leading)
            Text(type)
                .frame(width: 64, alignment: .leading)
            Text(content)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(isHeader ? .footnote.weight(.semibold) : .footnote)
        .foregroundStyle(isHeader ? inkSecondary : inkPrimary)
        .padding(.vertical, 6)
    }

    private func contentText(for event: CareEvent) -> String {
        switch event.kind {
        case .temperature:
            var text = event.temperatureC.map { Temp.display($0, unit: unit) } ?? "—"
            if let note = event.note, !note.isEmpty {
                text += "(\(note))"
            }
            return text
        case .medication:
            var text: String
            if let medicationName = event.medicationName, !medicationName.isEmpty {
                text = medicationName
            } else {
                text = "未填写药名"
            }
            if let note = event.note, !note.isEmpty {
                text += "(\(note))"
            }
            return text
        case .cooling:
            if let note = event.note, !note.isEmpty {
                return note
            }
            return "物理降温"
        case .note:
            if let note = event.note, !note.isEmpty {
                return note
            }
            return "备注"
        }
    }

    // MARK: 页脚

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(hairline)
                .frame(height: 1)
            Text("生成时间:\(Fmt.monthDayTime.string(from: Date()))")
                .font(.caption2)
                .foregroundStyle(inkSecondary)
            Text(AppCopy.reportFooter)
                .font(.caption2)
                .foregroundStyle(inkSecondary)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(inkPrimary)
    }
}
