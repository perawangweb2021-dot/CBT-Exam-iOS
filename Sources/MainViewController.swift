import UIKit

class MainViewController: UIViewController {

    private let primaryColor = UIColor(red: 13/255, green: 71/255, blue: 161/255, alpha: 1.0)
    private let accentColor = UIColor(red: 255/255, green: 143/255, blue: 0/255, alpha: 1.0)
    private let bgLight = UIColor(red: 244/255, green: 246/255, blue: 249/255, alpha: 1.0)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgLight
        setupUI()
    }

    private func setupUI() {
        // Logo Sekolah
        let logoImageView = UIImageView()
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.image = UIImage(named: "logo_sekolah")
        view.addSubview(logoImageView)

        if let url = URL(string: "https://smpn1tualang.sch.id/images/aplikasi/logo.png") {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async {
                        logoImageView.image = img
                    }
                }
            }.resume()
        }

        // Judul Aplikasi
        let lblTitle = UILabel()
        lblTitle.translatesAutoresizingMaskIntoConstraints = false
        lblTitle.text = "CBT EXAM BROWSER"
        lblTitle.font = UIFont.boldSystemFont(ofSize: 22)
        lblTitle.textColor = primaryColor
        lblTitle.textAlignment = .center
        view.addSubview(lblTitle)

        let lblSub = UILabel()
        lblSub.translatesAutoresizingMaskIntoConstraints = false
        lblSub.text = "SMP NEGERI 1 TUALANG"
        lblSub.font = UIFont.boldSystemFont(ofSize: 14)
        lblSub.textColor = .darkGray
        lblSub.textAlignment = .center
        view.addSubview(lblSub)

        // Stack Menu Utama
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        view.addSubview(stack)

        let btnScan = createMenuButton(
            title: "SCAN QR CODE UJIAN",
            systemIcon: "qrcode.viewfinder",
            bgColor: primaryColor,
            fgColor: .white,
            borderColor: primaryColor
        )
        btnScan.addTarget(self, action: #selector(handleScanQr), for: .touchUpInside)

        let btnInput = createMenuButton(
            title: "MASUKKAN LINK UJIAN",
            systemIcon: "link",
            bgColor: .white,
            fgColor: primaryColor,
            borderColor: primaryColor
        )
        btnInput.addTarget(self, action: #selector(handleInputLink), for: .touchUpInside)

        let btnHelp = createMenuButton(
            title: "BANTUAN",
            systemIcon: "info.circle.fill",
            bgColor: .white,
            fgColor: .black,
            borderColor: accentColor
        )
        btnHelp.addTarget(self, action: #selector(handleBantuan), for: .touchUpInside)

        stack.addArrangedSubview(btnScan)
        stack.addArrangedSubview(btnInput)
        stack.addArrangedSubview(btnHelp)

        // Footer Pembuat
        let lblFooter = UILabel()
        lblFooter.translatesAutoresizingMaskIntoConstraints = false
        lblFooter.text = "Copy 2026 Dibuat oleh TRI SUTRISNO, S.Kom"
        lblFooter.font = UIFont.boldSystemFont(ofSize: 12)
        lblFooter.textColor = .darkGray
        lblFooter.textAlignment = .center
        view.addSubview(lblFooter)

        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 36),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 110),
            logoImageView.heightAnchor.constraint(equalToConstant: 110),

            lblTitle.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 14),
            lblTitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            lblTitle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            lblSub.topAnchor.constraint(equalTo: lblTitle.bottomAnchor, constant: 4),
            lblSub.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            lblSub.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            stack.topAnchor.constraint(equalTo: lblSub.bottomAnchor, constant: 34),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            lblFooter.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            lblFooter.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            lblFooter.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    private func createMenuButton(title: String, systemIcon: String, bgColor: UIColor, fgColor: UIColor, borderColor: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        btn.heightAnchor.constraint(equalToConstant: 68).isActive = true
        btn.backgroundColor = bgColor
        btn.layer.cornerRadius = 14
        btn.layer.borderWidth = 1.5
        btn.layer.borderColor = borderColor.cgColor

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
        let icon = UIImage(systemName: systemIcon, withConfiguration: config)
        btn.setImage(icon, for: .normal)
        btn.setTitle("   " + title, for: .normal)
        btn.tintColor = fgColor
        btn.setTitleColor(fgColor, for: .normal)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        btn.contentHorizontalAlignment = .left
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        return btn
    }

    @objc private func handleScanQr() {
        let scannerVC = QrScannerViewController()
        scannerVC.onCodeScanned = { [weak self] code in
            self?.bukaHalamanUjian(urlString: code)
        }
        scannerVC.modalPresentationStyle = .fullScreen
        present(scannerVC, animated: true)
    }

    @objc private func handleInputLink() {
        let alert = UIAlertController(title: "Masukkan Link Ujian", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "https://..."
            textField.keyboardType = .URL
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
            textField.spellCheckingType = .no
            textField.textContentType = .none // Nonaktifkan saran & history ketikan
            textField.text = ""
        }

        alert.addAction(UIAlertAction(title: "BATAL", style: .cancel) { _ in
            alert.textFields?.first?.text = ""
        })

        alert.addAction(UIAlertAction(title: "MASUK UJIAN", style: .default) { [weak self] _ in
            guard let tf = alert.textFields?.first else { return }
            var urlText = (tf.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            tf.text = "" // Hapus ketikan segera
            if !urlText.isEmpty {
                if !urlText.hasPrefix("http://") && !urlText.hasPrefix("https://") {
                    urlText = "https://" + urlText
                }
                self?.bukaHalamanUjian(urlString: urlText)
            }
        })

        present(alert, animated: true)
    }

    @objc private func handleBantuan() {
        let pesan = """
        CBT EXAM BROWSER dibuat untuk tujuan mempermudah dalam melaksanakan sistem ujian yang transparan dan jujur.

        Aplikasi ini dibuat oleh :
        TRI SUTRISNO, S.Kom
        Guru SMP Negeri 1 Tualang
        trisutrisno79@guru.smp.belajar.id
        +6281276534734
        """
        let alert = UIAlertController(title: "Tentang Aplikasi & Bantuan", message: pesan, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "TUTUP", style: .default))
        present(alert, animated: true)
    }

    private func bukaHalamanUjian(urlString: String) {
        let examVC = ExamViewController(examUrl: urlString)
        navigationController?.pushViewController(examVC, animated: true)
    }
}
