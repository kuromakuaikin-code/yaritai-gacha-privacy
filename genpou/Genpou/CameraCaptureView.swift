import SwiftUI
import AVFoundation
import UIKit

/// AVFoundation ベースの連続撮影カメラ。
/// シャッターごとに onCapture が呼ばれ、「完了」で閉じる。
struct CameraCaptureView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = onCapture
        controller.onClose = { dismiss() }
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

final class CameraViewController: UIViewController {
    var onCapture: ((UIImage) -> Void)?
    var onClose: (() -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "genpou.camera.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?

    private let shutterButton = UIButton(type: .custom)
    private let closeButton = UIButton(type: .system)
    private let countLabel = UILabel()
    private let deniedLabel = UILabel()
    private var captureCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureSession()
                    } else {
                        self?.showDenied()
                    }
                }
            }
        default:
            showDenied()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning, !self.session.inputs.isEmpty else { return }
            self.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupUI() {
        // シャッター（大きめタップ）
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 37
        shutterButton.layer.borderWidth = 5
        shutterButton.layer.borderColor = UIColor.lightGray.cgColor
        shutterButton.addTarget(self, action: #selector(didTapShutter), for: .touchUpInside)
        view.addSubview(shutterButton)

        // 完了
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("完了", for: .normal)
        closeButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        view.addSubview(closeButton)

        // 撮影枚数
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.textColor = .white
        countLabel.font = .boldSystemFont(ofSize: 16)
        countLabel.text = ""
        view.addSubview(countLabel)

        // 権限拒否時の案内
        deniedLabel.translatesAutoresizingMaskIntoConstraints = false
        deniedLabel.textColor = .white
        deniedLabel.font = .systemFont(ofSize: 15)
        deniedLabel.numberOfLines = 0
        deniedLabel.textAlignment = .center
        deniedLabel.text = "カメラを使用できません。\n設定アプリでカメラへのアクセスを許可してください。"
        deniedLabel.isHidden = true
        view.addSubview(deniedLabel)

        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            shutterButton.widthAnchor.constraint(equalToConstant: 74),
            shutterButton.heightAnchor.constraint(equalToConstant: 74),

            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            closeButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),

            countLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            countLabel.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),

            deniedLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            deniedLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            deniedLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            deniedLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input),
                  self.session.canAddOutput(self.photoOutput) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.showDenied() }
                return
            }
            self.session.addInput(input)
            self.session.addOutput(self.photoOutput)
            self.session.commitConfiguration()

            DispatchQueue.main.async {
                let layer = AVCaptureVideoPreviewLayer(session: self.session)
                layer.videoGravity = .resizeAspectFill
                layer.frame = self.view.bounds
                self.view.layer.insertSublayer(layer, at: 0)
                self.previewLayer = layer
            }
            self.session.startRunning()
        }
    }

    private func showDenied() {
        deniedLabel.isHidden = false
        shutterButton.isEnabled = false
        shutterButton.alpha = 0.4
    }

    @objc private func didTapShutter() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    @objc private func didTapClose() {
        onClose?()
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        captureCount += 1
        countLabel.text = "\(captureCount)枚"

        // シャッターフィードバック
        UIView.animate(withDuration: 0.08, animations: { self.view.alpha = 0.4 }) { _ in
            UIView.animate(withDuration: 0.08) { self.view.alpha = 1 }
        }
        onCapture?(image)
    }
}
