import Foundation
import AppKit
import ImageIO
import SceneKit
import SceneKit.ModelIO
import ModelIO
import Metal
import simd

/// サムネイル生成。
/// - 画像: ImageIOでダウンサンプリング（元画像をメモリに全展開しない）
/// - usdz系: SceneKitで読み込み、SCNRendererでオフスクリーンレンダリング
/// - GLB: ModelIO経由を試行（技術検証の結果、標準フレームワークはGLB非対応の
///   可能性が高い。失敗時はプレースホルダを返し thumbnailFailed とする。
///   本対応はv0.2でGLTFKit2等の導入を検討 → README参照）
enum ThumbnailGenerator {

    struct Result {
        var jpegData: Data
        var failed: Bool // 3D読み込み失敗によるプレースホルダか
    }

    static func generate(for url: URL, type: AssetFileType, maxPixel: Int) -> Result? {
        switch type {
        case .image:
            guard let data = imageThumbnail(url: url, maxPixel: maxPixel) else { return nil }
            return Result(jpegData: data, failed: false)
        case .usdz, .glb:
            if let scene = loadScene(url: url, type: type),
               let data = renderScene(scene, size: maxPixel) {
                return Result(jpegData: data, failed: false)
            }
            // 読み込み失敗 → プレースホルダ（種別ラベル入りタイル）
            guard let data = placeholder(text: type.label, size: maxPixel) else { return nil }
            return Result(jpegData: data, failed: true)
        case .other:
            return nil
        }
    }

    // MARK: - 画像

    private static func imageThumbnail(url: URL, maxPixel: Int) -> Data? {
        let srcOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, srcOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as [CFString: Any] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return jpegData(from: cgImage)
    }

    // MARK: - 3Dシーン読み込み

    /// プレビューペインでも使うため internal
    static func loadScene(url: URL, type: AssetFileType) -> SCNScene? {
        switch type {
        case .usdz:
            return try? SCNScene(url: url, options: nil)
        case .glb:
            // 技術検証: ModelIOがGLBを読めるか実行時に確認してから試す
            let ext = url.pathExtension.lowercased()
            guard MDLAsset.canImportFileExtension(ext) else {
                NSLog("[AssetLedger] ModelIOは .\(ext) 非対応（GLB本対応はv0.2）: \(url.lastPathComponent)")
                return nil
            }
            let asset = MDLAsset(url: url)
            asset.loadTextures()
            return SCNScene(mdlAsset: asset)
        default:
            return nil
        }
    }

    // MARK: - オフスクリーンレンダリング

    private static func renderScene(_ scene: SCNScene, size: Int) -> Data? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            NSLog("[AssetLedger] Metalデバイスが取得できません")
            return nil
        }
        scene.background.contents = NSColor(calibratedWhite: 0.16, alpha: 1.0)

        // ライティング（環境光＋指向性）
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 400
        scene.rootNode.addChildNode(ambient)

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.intensity = 900
        directional.simdEulerAngles = simd_float3(-0.9, 0.6, 0)
        scene.rootNode.addChildNode(directional)

        // モデル全体が収まる位置にカメラを配置
        let (center, radius) = boundingSphere(of: scene.rootNode)
        let r = max(radius, 0.001)
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.automaticallyAdjustsZRange = true
        let dir = simd_normalize(simd_float3(1.0, 0.6, 1.0))
        let distance = r * 2.8
        cameraNode.simdPosition = center + dir * distance
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.simdLook(at: center)

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode
        renderer.autoenablesDefaultLighting = true

        let image = renderer.snapshot(
            atTime: 0,
            with: CGSize(width: size, height: size),
            antialiasingMode: .multisampling4X
        )
        return jpegData(from: image)
    }

    private static func boundingSphere(of node: SCNNode) -> (simd_float3, Float) {
        let sphere = node.boundingSphere
        return (simd_float3(Float(sphere.center.x), Float(sphere.center.y), Float(sphere.center.z)),
                Float(sphere.radius))
    }

    // MARK: - プレースホルダ

    private static func placeholder(text: String, size: Int) -> Data? {
        let s = CGFloat(size)
        let image = NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
            NSColor(calibratedWhite: 0.22, alpha: 1.0).setFill()
            rect.fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: s * 0.2),
                .foregroundColor: NSColor(calibratedWhite: 0.65, alpha: 1.0)
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let strSize = str.size()
            str.draw(at: NSPoint(x: (rect.width - strSize.width) / 2,
                                 y: (rect.height - strSize.height) / 2))
            return true
        }
        return jpegData(from: image)
    }

    // MARK: - JPEGエンコード

    private static func jpegData(from image: NSImage, quality: CGFloat = 0.8) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    private static func jpegData(from cgImage: CGImage, quality: CGFloat = 0.8) -> Data? {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
}
