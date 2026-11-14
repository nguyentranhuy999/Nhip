import Foundation
import CSQLite
import Darwin

public final class Repository {
    private var db: OpaquePointer?
    private var lockFD: Int32 = -1
    public let url: URL
    public init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        lockFD = Darwin.open(url.path + ".lock", O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
            if lockFD >= 0 { Darwin.close(lockFD); lockFD = -1 }
            throw JournalError.invalid("Bộ dữ liệu này đang được mở bởi một phiên Nhịp khác. Hãy dùng cửa sổ hiện có hoặc đóng phiên đó trước.")
        }
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw JournalError.invalid("Không mở được cơ sở dữ liệu.") }
        sqlite3_busy_timeout(db, 3000)
        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA synchronous=FULL;")
        try execute("CREATE TABLE IF NOT EXISTS journal (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL, updated REAL NOT NULL);")
        try execute("CREATE TABLE IF NOT EXISTS checkpoint (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL);")
    }
    deinit { sqlite3_close(db); if lockFD >= 0 { flock(lockFD, LOCK_UN); Darwin.close(lockFD) } }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw error() }
    }
    private func error() -> JournalError { .invalid("Lỗi lưu dữ liệu: \(String(cString: sqlite3_errmsg(db)))") }
    public func load(at now: Date = Date()) throws -> Journal {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT payload FROM journal WHERE id=1", -1, &statement, nil) == SQLITE_OK else { throw error() }
        defer { sqlite3_finalize(statement) }
        let status = sqlite3_step(statement)
        if status == SQLITE_DONE {
            var journal = Journal()
            SleepPlan.initializeFirstDay(journal: &journal, on: now)
            return journal
        }
        guard status == SQLITE_ROW, let raw = sqlite3_column_text(statement, 0) else { throw error() }
        var j = try JSONDecoder().decode(Journal.self, from: Data(String(cString: raw).utf8))
        var checkpoint: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT payload FROM checkpoint WHERE id=1", -1, &checkpoint, nil) == SQLITE_OK else { throw error() }
        defer { sqlite3_finalize(checkpoint) }
        if sqlite3_step(checkpoint) == SQLITE_ROW, let runtime = sqlite3_column_text(checkpoint, 0) {
            j.runtime = try JSONDecoder().decode(Runtime.self, from: Data(String(cString: runtime).utf8))
        }
        try Engine.validate(j)
        return j
    }
    public func save(_ journal: Journal) throws {
        let data = try JSONEncoder().encode(journal)
        guard let json = String(data: data, encoding: .utf8) else { throw JournalError.invalid("Không mã hóa được dữ liệu.") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT INTO journal(id,payload,updated) VALUES(1,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,updated=excluded.updated", -1, &statement, nil) == SQLITE_OK else { throw error() }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, json, -1, transient)
        sqlite3_bind_double(statement, 2, Date().timeIntervalSince1970)
        try execute("BEGIN IMMEDIATE;")
        do {
            guard sqlite3_step(statement) == SQLITE_DONE else { throw error() }
            try execute("DELETE FROM checkpoint;")
            try execute("COMMIT;")
        } catch { try? execute("ROLLBACK;"); throw error }
    }
    public func saveRuntime(_ runtime: Runtime) throws {
        let json = String(data: try JSONEncoder().encode(runtime), encoding: .utf8)!
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT INTO checkpoint(id,payload) VALUES(1,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload", -1, &statement, nil) == SQLITE_OK else { throw error() }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, json, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_DONE else { throw error() }
    }
}
