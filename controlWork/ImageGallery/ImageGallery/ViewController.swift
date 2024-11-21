//
//  ViewController.swift
//  ImageGallery
//
//  Created by Сабиров Мльнур Марсович on 21.11.2024.
//


import UIKit

class ViewController: UIViewController {
    private var images: [UIImage?] = Array(repeating: nil, count: 15)
    private var queue = OperationQueue()
    private var collectionView: UICollectionView!
    private var activityIndicator: UIActivityIndicatorView!
    private var progressView: UIProgressView!
    private var cancellationTask: Task<Void, Never>? = nil

    private let segmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Параллельно", "Последовательно"])
        sc.selectedSegmentIndex = 0
        return sc
    }()

    private let startButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Начать вычисления", for: .normal)
        return button
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Отмена", for: .normal)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadImages()
    }

    private func setupUI() {
        view.backgroundColor = .white

        segmentedControl.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
        startButton.addTarget(self, action: #selector(startCalculations), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelCalculations), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [segmentedControl, startButton, cancelButton])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)
        stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 100)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: "ImageCell")
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            progressView.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: -10),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        view.addSubview(activityIndicator)
    }

    private func loadImages() {
        for index in 0..<images.count {
            if let image = UIImage(named: "image_\(index)") {
                images[index] = image
            }
        }
        collectionView.reloadData()
    }

    @objc private func segmentedControlChanged() {
    }

    @objc private func startCalculations() {
        activityIndicator.startAnimating()
        cancellationTask = Task {
            for i in 1...20 {
                let factorial = await calculateFactorial(of: i)
                print("Факториал \(i) = \(factorial)")

                await MainActor.run {
                    self.progressView.progress += 1 / 20.0
                }
            }
            self.activityIndicator.stopAnimating()
        }
    }
    
    func calculateFactorial(of number: Int) async -> Int {
        if number > 1 {
            let result = await calculateFactorial(of: number - 1)
            return number * result
        } else {
            return 1
        }
    }
    
    @objc private func cancelCalculations() {
        cancellationTask?.cancel()
        activityIndicator.stopAnimating()
    }
}



extension ViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImageCell

        cell.startLoading()
        let image = images[indexPath.item]

        Task {
            let processedImage: UIImage?
            if segmentedControl.selectedSegmentIndex == 0 {
                processedImage = await applyFilterConcurrently(image: image)
            } else {
                processedImage = await applyFilterSequentially(image: image)
            }
            await MainActor.run {
                cell.stopLoading()
                cell.configure(with: processedImage)
            }
        }

        return cell
    }

    private func applyFilterConcurrently(image: UIImage?) async -> UIImage? {
        guard let image = image else { return nil }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let filteredImage = ImageProcessor.applyFilter(to: image)
                continuation.resume(returning: filteredImage)
            }
        }
    }

    private func applyFilterSequentially(image: UIImage?) async -> UIImage? {
        guard let image = image else { return nil }
        return await withUnsafeContinuation { continuation in
            queue.addOperation {
                let filteredImage = ImageProcessor.applyFilter(to: image)
                OperationQueue.main.addOperation {
                    continuation.resume(returning: filteredImage)
                }
            }
        }
    }
}


