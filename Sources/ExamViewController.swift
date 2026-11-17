import UIKit
import WebKit
import AVFoundation
import Network
import MediaPlayer

class ExamViewController: UIViewController, WKNavigationDelegate {

    private let examUrl: String
    private var webView: WKWebView!
    private var lblClock: UILabel!
    private var lblBattery: UILabel!
    private var imgBattery: UIImageView!
    private var imgNetwork: UIImageView!
    private var violationOverlay: UIView!

    private var frontCamSession: AVCaptureSession?
    private var frontCamLayer: AVCaptureVideoPreviewLayer?
    private let camContainer = UIView()

    private let networkMonitor = NWPathMonitor()
    private var statusTimer: Timer?
    private var currentZoom: CGFloat = 1.0
    private var isAuthorizedExit = false

    init(examUrl: String) {
        self.examUrl = examUrl
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        UIApplication.shared.isIdleTimerDisabled = true

        setupAudioMax()
        setupUI()
        setupWebView()
        setupFrontCamera()
        setupSecurityObservers()
        startStatusMonitoring()

        // Aktifkan Guided Access / Single App Mode jika diizinkan sistem
        UIAccessibility.requestGuidedAccessSession(enabled: true) { _ in }
    }

    private func setupUI() {
        // Bar Atas
        let topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor(red: 13/255, green: 71/255, blue: 161/255, alpha: 1.0)
        view.addSubview(topBar)

        // Kiri Atas: Ikon Jam, Baterai, Jaringan
        let imgClock = UIImageView(image: UIImage(systemName: "clock.fill"))
        imgClock.tintColor = .white
        imgClock.translatesAutoresizingMaskIntoConstraints = false

        lblClock = UILabel()
        lblClock.translatesAutoresizingMaskIntoConstraints = false
        lblClock.textColor = .white
        lblClock.font = UIFont.boldSystemFont(ofSize: 12)
        lblClock.text = "00:00"

        imgBattery = UIImageView(image: UIImage(systemName: "battery.100"))
        imgBattery.tintColor = UIColor(red: 165/255, green: 214/255, blue: 167/255, alpha: 1.0)
        imgBattery.translatesAutoresizingMaskIntoConstraints = false

        lblBattery = UILabel()
        lblBattery.translatesAutoresizingMaskIntoConstraints = false
        lblBattery.textColor = .white
        lblBattery.font = UIFont.boldSystemFont(ofSize: 12)
        lblBattery.text = "100%"

        imgNetwork = UIImageView(image: UIImage(systemName: "wifi"))
        imgNetwork.tintColor = UIColor(red: 105/255, green: 240/255, blue: 174/255, alpha: 1.0)
        imgNetwork.translatesAutoresizingMaskIntoConstraints = false

        let leftStack = UIStackView(arrangedSubviews: [imgClock, lblClock, imgBattery, lblBattery, imgNetwork])
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        leftStack.axis = .horizontal
        leftStack.spacing = 6
        leftStack.alignment = .center
        topBar.addSubview(leftStack)

        // Kanan Atas: Refresh & Keluar
        let btnRefresh = UIButton(type: .system)
        btnRefresh.translatesAutoresizingMaskIntoConstraints = false
        btnRefresh.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        btnRefresh.tintColor = .white
        btnRefresh.addTarget(self, action: #selector(handleRefresh), for: .touchUpInside)

        let btnExit = UIButton(type: .system)
        btnExit.translatesAutoresizingMaskIntoConstraints = false
        btnExit.setTitle("KELUAR", for: .normal)
        btnExit.backgroundColor = .systemRed
        btnExit.setTitleColor(.white, for: .normal)
        btnExit.titleLabel?.font = UIFont.boldSystemFont(ofSize: 11)
        btnExit.layer.cornerRadius = 6
        btnExit.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        btnExit.addTarget(self, action: #selector(handleExit), for: .touchUpInside)

        let rightStack = UIStackView(arrangedSubviews: [btnRefresh, btnExit])
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        rightStack.axis = .horizontal
        rightStack.spacing = 10
        rightStack.alignment = .center
        topBar.addSubview(rightStack)

        // Konfigurasi WKWebView + User-Agent: 10403445@ + Anti-Copy
        let config = WKWebViewConfiguration()
        let antiCopyScript = """
        document.documentElement.style.webkitUserSelect='none';
        document.documentElement.style.webkitTouchCallout='none';
        document.addEventListener('copy', function(e) { e.preventDefault(); });
        """
        let userScript = WKUserScript(source: antiCopyScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.customUserAgent = "10403445@"
        webView.navigationDelegate = self
        view.addSubview(webView)

        // Pojok Kiri Bawah: Live Kamera Depan Pengawas
        camContainer.translatesAutoresizingMaskIntoConstraints = false
        camContainer.backgroundColor = .black
        camContainer.layer.cornerRadius = 10
        camContainer.layer.borderWidth = 2
        camContainer.layer.borderColor = UIColor.systemRed.cgColor
        camContainer.clipsToBounds = true
        view.addSubview(camContainer)

        let lblCamBadge = UILabel()
        lblCamBadge.translatesAutoresizingMaskIntoConstraints = false
        lblCamBadge.text = "● PENGAWAS"
        lblCamBadge.textColor = .white
        lblCamBadge.backgroundColor = UIColor.systemRed.withAlphaComponent(0.85)
        lblCamBadge.font = UIFont.boldSystemFont(ofSize: 9)
        lblCamBadge.textAlignment = .center
        camContainer.addSubview(lblCamBadge)

        // Pojok Kanan Bawah: Zoom In & Zoom Out
        let btnZoomIn = createZoomButton(title: "+")
        btnZoomIn.addTarget(self, action: #selector(handleZoomIn), for: .touchUpInside)

        let btnZoomOut = createZoomButton(title: "−")
        btnZoomOut.addTarget(self, action: #selector(handleZoomOut), for: .touchUpInside)

        let zoomStack = UIStackView(arrangedSubviews: [btnZoomIn, btnZoomOut])
        zoomStack.translatesAutoresizingMaskIntoConstraints = false
        zoomStack.axis = .vertical
        zoomStack.spacing = 10
        view.addSubview(zoomStack)

        // Overlay Pelanggaran (Anti-Screen Recording / Pindah Aplikasi)
        violationOverlay = UIView()
        violationOverlay.translatesAutoresizingMaskIntoConstraints = false
        violationOverlay.backgroundColor = UIColor.systemRed.withAlphaComponent(0.95)
        violationOverlay.isHidden = true
        view.addSubview(violationOverlay)

        let lblViolation = UILabel()
        lblViolation.translatesAutoresizingMaskIntoConstraints = false
        lblViolation.text = "⚠️ PELANGGARAN TERDETEKSI!\n\nDilarang merekam layar, mengambil screenshot, atau keluar dari aplikasi ujian!"
        lblViolation.textColor = .white
        lblViolation.font = UIFont.boldSystemFont(ofSize: 18)
        lblViolation.numberOfLines = 0
        lblViolation.textAlignment = .center
        violationOverlay.addSubview(lblViolation)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 46),

            leftStack.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 12),
            leftStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            rightStack.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -12),
            rightStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            webView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            camContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            camContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            camContainer.widthAnchor.constraint(equalToConstant: 96),
            camContainer.heightAnchor.constraint(equalToConstant: 128),

            lblCamBadge.leadingAnchor.constraint(equalTo: camContainer.leadingAnchor),
            lblCamBadge.trailingAnchor.constraint(equalTo: camContainer.trailingAnchor),
            lblCamBadge.bottomAnchor.constraint(equalTo: camContainer.bottomAnchor),
            lblCamBadge.heightAnchor.constraint(equalToConstant: 18),

            zoomStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            zoomStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            violationOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            violationOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            violationOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            violationOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            lblViolation.centerYAnchor.constraint(equalTo: violationOverlay.centerYAnchor),
            lblViolation.leadingAnchor.constraint(equalTo: violationOverlay.leadingAnchor, constant: 24),
            lblViolation.trailingAnchor.constraint(equalTo: violationOverlay.trailingAnchor, constant: -24)
        ])
    }

    private func createZoomButton(title: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor(red: 13/255, green: 71/255, blue: 161/255, alpha: 1.0)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        btn.layer.cornerRadius = 21
        btn.widthAnchor.constraint(equalToConstant: 42).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 42).isActive = true
        return btn
    }

    private func setupWebView() {
        if let url = URL(string: examUrl) {
            webView.load(URLRequest(url: url))
        }
    }

    // Kamera Depan Pengawas
    private func setupFrontCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .low // Ringan & hemat baterai

        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: frontCamera),
              session.canAddInput(input) else {
            camContainer.isHidden = true
            return
        }

        session.addInput(input)
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = CGRect(x: 0, y: 0, width: 96, height: 128)
        camContainer.layer.insertSublayer(preview, at: 0)

        frontCamSession = session
        frontCamLayer = preview

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    // Maksimalkan Volume iPhone & Bunyikan Alarm
    private func setupAudioMax() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)

        let volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        view.addSubview(volumeView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                slider.value = 1.0
            }
        }
    }

    private func bunyikanAlarm() {
        setupAudioMax()
        AudioServicesPlaySystemSound(1005) // Alarm sistem iOS keras
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    // Monitor Jam, Baterai & Jaringan Realtime
    private func startStatusMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true

        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self?.imgNetwork.image = UIImage(systemName: "wifi")
                    self?.imgNetwork.tintColor = UIColor(red: 105/255, green: 240/255, blue: 174/255, alpha: 1.0)
                } else {
                    self?.imgNetwork.image = UIImage(systemName: "wifi.slash")
                    self?.imgNetwork.tintColor = .systemRed
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .background))

        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            self?.lblClock.text = formatter.string(from: Date())

            let bat = Int(UIDevice.current.batteryLevel * 100)
            if bat >= 0 {
                self?.lblBattery.text = "\(bat)%"
                self?.imgBattery.tintColor = bat <= 20 ? .systemRed : UIColor(red: 165/255, green: 214/255, blue: 167/255, alpha: 1.0)
            }
        }
    }

    // Proteksi Anti-Screenshot, Anti-Screen Record & Deteksi Pindah Aplikasi
    private func setupSecurityObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main) { [weak self] _ in
            if self?.isAuthorizedExit == false {
                self?.bunyikanAlarm()
                self?.violationOverlay.isHidden = false
            }
        }

        NotificationCenter.default.addObserver(forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            if UIScreen.main.isCaptured && self?.isAuthorizedExit == false {
                self?.bunyikanAlarm()
                self?.violationOverlay.isHidden = false
            } else {
                self?.violationOverlay.isHidden = true
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            if self?.isAuthorizedExit == false {
                self?.bunyikanAlarm()
            }
        }
    }

    @objc private func handleRefresh() {
        webView.reload()
    }

    @objc private func handleZoomIn() {
        if currentZoom < 2.0 {
            currentZoom += 0.1
            webView.evaluateJavaScript("document.body.style.zoom = '\(currentZoom)'", completionHandler: nil)
        }
    }

    @objc private func handleZoomOut() {
        if currentZoom > 0.6 {
            currentZoom -= 0.1
            webView.evaluateJavaScript("document.body.style.zoom = '\(currentZoom)'", completionHandler: nil)
        }
    }

    @objc private func handleExit() {
        bunyikanAlarm()
        let alert = UIAlertController(
            title: "IZIN KELUAR UJIAN",
            message: "Masukkan password pengawas untuk keluar dari aplikasi:",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "Password pengawas"
            tf.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: "LANJUT UJIAN", style: .cancel))
        alert.addAction(UIAlertAction(title: "KELUAR", style: .destructive) { [weak self] _ in
            let pass = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if pass == "xyz" {
                self?.isAuthorizedExit = true
                self?.statusTimer?.invalidate()
                self?.networkMonitor.cancel()
                self?.frontCamSession?.stopRunning()
                UIAccessibility.requestGuidedAccessSession(enabled: false) { _ in }
                self?.navigationController?.popViewController(animated: true)
            } else {
                self?.bunyikanAlarm()
                let err = UIAlertController(title: "PASSWORD SALAH", message: "Akses keluar ditolak!", preferredStyle: .alert)
                err.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(err, animated: true)
            }
        })
        present(alert, animated: true)
    }

    deinit {
        statusTimer?.invalidate()
        networkMonitor.cancel()
        frontCamSession?.stopRunning()
        NotificationCenter.default.removeObserver(self)
    }
}
