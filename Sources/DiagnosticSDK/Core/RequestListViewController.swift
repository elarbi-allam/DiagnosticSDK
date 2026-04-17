//
//  RequestListViewController.swift
//  DiagnosticSDK
//
//  Created by wiame on 17/4/2026.
//

import UIKit

final class RequestListViewController: UIViewController {

    // MARK: - Properties
    private let store: JSONFileStore
    private var events: [NetworkEvent] = []
    private var filtered: [NetworkEvent] = []

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchBar = UISearchBar()
    private let toolbar = UIToolbar()

    // MARK: - Init
    init(store: JSONFileStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNav()
        setupSearch()
        setupTable()
        setupToolbar()
        loadEvents()
    }

    // MARK: - Setup

    private func setupNav() {
        title = "Network Inspector"
        view.backgroundColor = UIColor.systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .done,
            target: self,
            action: #selector(close)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(exportJSON)
        )

        // Style the nav bar like a dev tool
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.1, alpha: 1)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .systemBlue
    }

    private func setupSearch() {
        searchBar.placeholder = "Filter by URL, method, status..."
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.1, alpha: 1)
        searchBar.barTintColor = UIColor(red: 0.06, green: 0.06, blue: 0.1, alpha: 1)
    }

    private func setupTable() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.systemBackground
        tableView.register(RequestCell.self,
                           forCellReuseIdentifier: RequestCell.id)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.tableHeaderView = searchBar
        searchBar.frame = CGRect(x: 0, y: 0,
                                 width: view.bounds.width, height: 52)

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupToolbar() {
        let clearBtn = UIBarButtonItem(
            title: "Clear All",
            style: .plain,
            target: self,
            action: #selector(clearAll)
        )
        clearBtn.tintColor = .systemRed
        let space = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil, action: nil
        )
        let countLabel = UILabel()
        countLabel.font = .systemFont(ofSize: 12)
        countLabel.textColor = .secondaryLabel
        let countItem = UIBarButtonItem(customView: countLabel)

        toolbar.setItems([clearBtn, space, countItem], animated: false)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        tableView.contentInset.bottom = 44
    }

    // MARK: - Data

    private func loadEvents() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let all = self.store.readAll()
            DispatchQueue.main.async {
                self.events = all.reversed() // newest first
                self.filtered = self.events
                self.tableView.reloadData()
                self.updateCount()
            }
        }
    }

    private func updateCount() {
        guard let toolbar = toolbar.items?.last?.customView as? UILabel else { return }
        toolbar.text = "\(filtered.count) requests"
        toolbar.sizeToFit()
    }

    // MARK: - Actions

    @objc private func close() {
        DiagnosticOverlayWindow.shared.hide()
    }

    @objc private func exportJSON() {
        let url = store.fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            showAlert("No data yet", message: "Make some network requests first.")
            return
        }
        let activity = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        present(activity, animated: true)
    }

    @objc private func clearAll() {
        let alert = UIAlertController(
            title: "Clear all requests?",
            message: "This cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.store.clearAll()
            self?.events = []
            self?.filtered = []
            self?.tableView.reloadData()
            self?.updateCount()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func showAlert(_ title: String, message: String) {
        let a = UIAlertController(title: title,
                                  message: message,
                                  preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}

// MARK: - UITableViewDataSource / Delegate
extension RequestListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        filtered.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RequestCell.id, for: indexPath
        ) as! RequestCell
        cell.configure(with: filtered[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let detail = RequestDetailViewController(event: filtered[indexPath.row])
        navigationController?.pushViewController(detail, animated: true)
    }
}

// MARK: - UISearchBarDelegate
extension RequestListViewController: UISearchBarDelegate {

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filtered = events
        } else {
            let q = searchText.lowercased()
            filtered = events.filter {
                $0.request.url.lowercased().contains(q) ||
                $0.request.method.lowercased().contains(q) ||
                "\($0.response?.statusCode ?? 0)".contains(q)
            }
        }
        tableView.reloadData()
        updateCount()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
