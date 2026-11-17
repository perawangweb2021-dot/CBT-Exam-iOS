import UIKit
import AVFoundation

class QrScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var onCodeScanned: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              captureSession.canAddInput(videoInput) else {
            return
        }
        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        let lblHint = UILabel()
        lblHint.translatesAutoresizingMaskIntoConstraints = false
        lblHint.text = "Arahkan Kamera ke QR Code Ujian dari Guru Pengawas"
        lblHint.textColor = .white
        lblHint.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        lblHint.textAlignment = .center
        lblHint.font = UIFont.boldSystemFont(ofSize: 14)
        view.addSubview(lblHint)

        let btnClose = UIButton(type: .system)
        btnClose.translatesAutoresizingMaskIntoConstraints = false
        btnClose.setTitle("BATAL", for: .normal)
        btnClose.backgroundColor = .systemRed
        btnClose.setTitleColor(.white, for: .normal)
        btnClose.layer.cornerRadius = 8
        btnClose.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        btnClose.addTarget(self, action: #selector(closeScanner), for: .touchUpInside)
        view.addSubview(btnClose)

        NSLayoutConstraint.activate([
            lblHint.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            lblHint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            lblHint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            lblHint.heightAnchor.constraint(equalToConstant: 40),

            btnClose.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            btnClose.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            btnClose.widthAnchor.constraint(equalToConstant: 140),
            btnClose.heightAnchor.constraint(equalToConstant: 44)
        ])

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let stringValue = metadataObject.stringValue {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            dismiss(animated: true) {
                self.onCodeScanned?(stringValue)
            }
        }
    }

    @objc private func closeScanner() {
        captureSession.stopRunning()
        dismiss(animated: true)
    }
}
