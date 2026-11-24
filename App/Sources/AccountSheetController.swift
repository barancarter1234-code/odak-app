import UIKit

/// Instagram'daki gibi hesap listesi: dokun = o hesaba geç, sola kaydır = listeden kaldır,
/// en altta "Instagram hesabı ekle".
final class AccountSheetController: UITableViewController {
    var onSelect: ((String) -> Void)?
    var onAdd: (() -> Void)?
    var onRemove: ((String) -> Void)?

    private var accounts: [InstagramAccount]
    private let current: String?
    private var avatars: [String: UIImage] = [:]
    private let avatarSize = CGSize(width: 44, height: 44)

    init(accounts: [InstagramAccount], current: String?) {
        self.accounts = accounts
        self.current = current
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) kullanılmıyor")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Hesaplar"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        accounts.forEach { loadAvatar(for: $0) }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? accounts.count : 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.imageProperties.reservedLayoutSize = avatarSize
        if indexPath.section == 0 {
            let account = accounts[indexPath.row]
            content.text = account.username
            content.textProperties.font = .systemFont(ofSize: 16, weight: .semibold)
            content.image = avatars[account.username] ?? UIImage(systemName: "person.crop.circle.fill")
            content.imageProperties.maximumSize = avatarSize
            content.imageProperties.cornerRadius = avatarSize.width / 2
            content.imageProperties.tintColor = .systemGray3
            cell.accessoryType = account.username == current ? .checkmark : .none
        } else {
            content.text = "Instagram hesabı ekle"
            content.image = UIImage(systemName: "plus.circle")
            content.imageProperties.tintColor = .label
            cell.accessoryType = .none
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 {
            let add = onAdd
            dismiss(animated: true) { add?() }
            return
        }
        let username = accounts[indexPath.row].username
        guard username != current else {
            dismiss(animated: true)
            return
        }
        let select = onSelect
        dismiss(animated: true) { select?(username) }
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 0, accounts[indexPath.row].username != current else { return nil }
        let remove = UIContextualAction(style: .destructive, title: "Kaldır") { [weak self] _, _, done in
            guard let self = self else {
                done(false)
                return
            }
            let username = self.accounts.remove(at: indexPath.row).username
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            self.onRemove?(username)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [remove])
    }

    private func loadAvatar(for account: InstagramAccount) {
        guard let link = account.avatarURL, let url = URL(string: link) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                guard let self = self,
                      let row = self.accounts.firstIndex(where: { $0.username == account.username }) else { return }
                self.avatars[account.username] = image
                self.tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
            }
        }.resume()
    }
}
