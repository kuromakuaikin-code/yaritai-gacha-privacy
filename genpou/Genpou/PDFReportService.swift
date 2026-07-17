import UIKit
import PDFKit

/// 日報 PDF・完了報告 PDF の生成（A4 縦 595×842pt / 完全オフライン動作）
final class PDFReportService {
    enum ReportError: Error {
        case noPhotos
    }

    private let pageSize = CGSize(width: 595, height: 842)
    private let margin: CGFloat = 40
    private let footerHeight: CGFloat = 26

    private var contentWidth: CGFloat { pageSize.width - margin * 2 }
    private var contentBottom: CGFloat { pageSize.height - margin - footerHeight }

    private var pageNumber = 0
    private var y: CGFloat = 0
    private var footerPhone: String?

    // MARK: - 公開 API

    /// 日報 PDF を生成してファイル URL を返す。
    func makeDailyReport(project: Project,
                         date: Date,
                         photos: [SitePhoto],
                         profile: CompanyProfile) throws -> URL {
        let fileName = sanitizedFileName("日報_\(project.name)_\(DateFormats.fileDate.string(from: date)).pdf")
        return try render(fileName: fileName, profile: profile) { ctx in
            drawHeader(ctx, profile: profile, title: "日報",
                       dateLabel: DateFormats.dateJP.string(from: date))
            drawProjectSummary(ctx, project: project, includePeriod: false)
            drawDivider(ctx)
            y += 8
            let sorted = photos.sorted { $0.takenAt < $1.takenAt }
            drawPhotoGrid(ctx, photos: sorted)
        }
    }

    /// 完了報告 PDF を生成してファイル URL を返す。
    func makeCompletionReport(project: Project,
                              photos: [SitePhoto],
                              profile: CompanyProfile) throws -> URL {
        let today = Date()
        let fileName = sanitizedFileName("完了報告_\(project.name)_\(DateFormats.fileDate.string(from: today)).pdf")
        return try render(fileName: fileName, profile: profile) { ctx in
            drawHeader(ctx, profile: profile, title: "工事完了報告書",
                       dateLabel: "報告日 " + DateFormats.dateJP.string(from: today))
            drawProjectSummary(ctx, project: project, includePeriod: true)
            drawDivider(ctx)
            y += 8

            // タグ別セクション（該当写真があるタグのみ）
            for tag in PhotoTag.allCases {
                let tagPhotos = photos
                    .filter { $0.tag == tag }
                    .sorted { $0.takenAt < $1.takenAt }
                guard !tagPhotos.isEmpty else { continue }
                ensureSpace(30, ctx)
                appendText(tag.labelJP, font: .boldSystemFont(ofSize: 14), ctx)
                y += 6
                drawPhotoGrid(ctx, photos: tagPhotos)
                y += 10
            }

            // 締めの文言 + 署名欄
            ensureSpace(90, ctx)
            y += 12
            appendText("上記工事は完了いたしました。", font: .systemFont(ofSize: 12), ctx)
            y += 20
            let signWidth: CGFloat = 240
            let signX = pageSize.width - margin - signWidth
            draw(profile.companyName, font: .boldSystemFont(ofSize: 12),
                 in: CGRect(x: signX, y: y, width: signWidth, height: 16))
            y += 20
            let representative = profile.representative ?? ""
            draw("代表者: \(representative)", font: .systemFont(ofSize: 12),
                 in: CGRect(x: signX, y: y, width: signWidth, height: 16))
            y += 20
            // 署名・押印用の下線
            let line = UIBezierPath()
            line.move(to: CGPoint(x: signX, y: y))
            line.addLine(to: CGPoint(x: signX + signWidth, y: y))
            UIColor.black.setStroke()
            line.lineWidth = 0.5
            line.stroke()
            y += 8
            draw("（署名・押印）", font: .systemFont(ofSize: 9), color: .gray,
                 in: CGRect(x: signX, y: y, width: signWidth, height: 12))
        }
    }

    // MARK: - レンダリング基盤

    private func render(fileName: String,
                        profile: CompanyProfile,
                        content: (UIGraphicsPDFRendererContext) -> Void) throws -> URL {
        pageNumber = 0
        footerPhone = profile.phone

        let dir = MediaStore.reportsDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        try renderer.writePDF(to: url) { ctx in
            beginPage(ctx)
            content(ctx)
        }
        return url
    }

    private func beginPage(_ ctx: UIGraphicsPDFRendererContext) {
        ctx.beginPage()
        pageNumber += 1
        drawFooter()
        y = margin
    }

    private func ensureSpace(_ height: CGFloat, _ ctx: UIGraphicsPDFRendererContext) {
        if y + height > contentBottom {
            beginPage(ctx)
        }
    }

    private func drawFooter() {
        let footerY = pageSize.height - margin - 12
        if let phone = footerPhone, !phone.isEmpty {
            draw("TEL: \(phone)", font: .systemFont(ofSize: 9), color: .gray,
                 in: CGRect(x: margin, y: footerY, width: 200, height: 12))
        }
        draw("ページ \(pageNumber)", font: .systemFont(ofSize: 9), color: .gray,
             in: CGRect(x: margin, y: footerY, width: contentWidth, height: 12),
             alignment: .center)
    }

    // MARK: - 共通パーツ

    private func drawHeader(_ ctx: UIGraphicsPDFRendererContext,
                            profile: CompanyProfile,
                            title: String,
                            dateLabel: String) {
        let logoHeight: CGFloat = 40
        var textX = margin
        if let logo = MediaStore.loadLogo(fileName: profile.logoFileName) {
            let scale = logoHeight / logo.size.height
            let logoWidth = min(logo.size.width * scale, 120)
            logo.draw(in: CGRect(x: margin, y: y, width: logoWidth, height: logoHeight))
            textX += logoWidth + 10
        }
        draw(profile.companyName, font: .boldSystemFont(ofSize: 14),
             in: CGRect(x: textX, y: y + 4, width: 250, height: 18))
        if let address = profile.address, !address.isEmpty {
            draw(address, font: .systemFont(ofSize: 9), color: .darkGray,
                 in: CGRect(x: textX, y: y + 24, width: 250, height: 12))
        }
        // 右側: タイトルと日付
        draw(title, font: .boldSystemFont(ofSize: 20),
             in: CGRect(x: margin, y: y, width: contentWidth, height: 26),
             alignment: .right)
        draw(dateLabel, font: .systemFont(ofSize: 11),
             in: CGRect(x: margin, y: y + 28, width: contentWidth, height: 14),
             alignment: .right)
        y += logoHeight + 12
    }

    private func drawProjectSummary(_ ctx: UIGraphicsPDFRendererContext,
                                    project: Project,
                                    includePeriod: Bool) {
        var lines: [(String, String)] = [("工事名称", project.name)]
        if let siteAddress = project.siteAddress, !siteAddress.isEmpty {
            lines.append(("現場住所", siteAddress))
        }
        if let clientName = project.clientName, !clientName.isEmpty {
            lines.append(("発注者", clientName))
        }
        if includePeriod, let start = project.startDate {
            let endText = project.endDate.map { DateFormats.dateJP.string(from: $0) } ?? ""
            lines.append(("工期", "\(DateFormats.dateJP.string(from: start)) 〜 \(endText)"))
        }
        for (label, value) in lines {
            ensureSpace(18, ctx)
            draw(label, font: .boldSystemFont(ofSize: 10), color: .darkGray,
                 in: CGRect(x: margin, y: y, width: 70, height: 14))
            let valueHeight = textHeight(value, font: .systemFont(ofSize: 11), width: contentWidth - 80)
            draw(value, font: .systemFont(ofSize: 11),
                 in: CGRect(x: margin + 80, y: y, width: contentWidth - 80, height: valueHeight))
            y += max(16, valueHeight + 3)
        }
        y += 4
    }

    private func drawDivider(_ ctx: UIGraphicsPDFRendererContext) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageSize.width - margin, y: y))
        UIColor(white: 0.7, alpha: 1).setStroke()
        path.lineWidth = 0.8
        path.stroke()
        y += 4
    }

    /// 写真 2 列グリッド（画像 + タグ + HH:mm + キャプション 1 行）
    private func drawPhotoGrid(_ ctx: UIGraphicsPDFRendererContext, photos: [SitePhoto]) {
        let gap: CGFloat = 15
        let cellWidth = (contentWidth - gap) / 2
        let imageHeight: CGFloat = 165
        let metaHeight: CGFloat = 32
        let cellHeight = imageHeight + metaHeight

        var index = 0
        while index < photos.count {
            ensureSpace(cellHeight + 8, ctx)
            for column in 0..<2 {
                guard index < photos.count else { break }
                let photo = photos[index]
                let x = margin + CGFloat(column) * (cellWidth + gap)
                drawPhotoCell(photo, in: CGRect(x: x, y: y, width: cellWidth, height: cellHeight),
                              imageHeight: imageHeight)
                index += 1
            }
            y += cellHeight + 8
        }
    }

    private func drawPhotoCell(_ photo: SitePhoto, in rect: CGRect, imageHeight: CGFloat) {
        let imageRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: imageHeight)
        // 枠
        UIColor(white: 0.85, alpha: 1).setStroke()
        let border = UIBezierPath(rect: imageRect)
        border.lineWidth = 0.5
        border.stroke()

        if let original = MediaStore.loadPhoto(photo) {
            // PDF 肥大化を防ぐため縮小してから埋め込む
            let image = MediaStore.resized(original, maxSide: 1200)
            let scale = min(imageRect.width / image.size.width, imageRect.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: imageRect.midX - drawSize.width / 2,
                                 y: imageRect.midY - drawSize.height / 2)
            image.draw(in: CGRect(origin: origin, size: drawSize))
        } else {
            draw("（画像なし）", font: .systemFont(ofSize: 10), color: .gray,
                 in: CGRect(x: imageRect.minX, y: imageRect.midY - 6, width: imageRect.width, height: 12),
                 alignment: .center)
        }

        let metaY = imageRect.maxY + 3
        let meta = "\(photo.tag.labelJP)  \(DateFormats.time.string(from: photo.takenAt))"
        draw(meta, font: .boldSystemFont(ofSize: 9), color: .darkGray,
             in: CGRect(x: rect.minX, y: metaY, width: rect.width, height: 12))
        if let caption = photo.caption, !caption.isEmpty {
            draw(caption, font: .systemFont(ofSize: 9),
                 in: CGRect(x: rect.minX, y: metaY + 13, width: rect.width, height: 12),
                 lineBreak: .byTruncatingTail)
        }
    }

    // MARK: - テキスト描画ユーティリティ

    /// 現在の y 位置に描画して y を進める。
    private func appendText(_ text: String, font: UIFont, color: UIColor = .black,
                            _ ctx: UIGraphicsPDFRendererContext) {
        let height = textHeight(text, font: font, width: contentWidth)
        ensureSpace(height, ctx)
        draw(text, font: font, color: color,
             in: CGRect(x: margin, y: y, width: contentWidth, height: height))
        y += height + 2
    }

    private func draw(_ text: String, font: UIFont, color: UIColor = .black,
                      in rect: CGRect, alignment: NSTextAlignment = .left,
                      lineBreak: NSLineBreakMode = .byWordWrapping) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = lineBreak
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    private func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: font],
            context: nil
        )
        return ceil(bounds.height)
    }

    // MARK: - ファイル名

    private func sanitizedFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r\t")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }
}
