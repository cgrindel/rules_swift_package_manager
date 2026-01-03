import GRDB

// A simple example demonstrating GRDB usage on Linux

struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var name: String
    var score: Int

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

func main() throws {
    // Create an in-memory database
    let dbQueue = try DatabaseQueue()

    try dbQueue.write { db in
        // Create the players table
        try db.create(table: "player") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("score", .integer).notNull()
        }

        // Insert some players
        var alice = Player(id: nil, name: "Alice", score: 100)
        try alice.insert(db)

        var bob = Player(id: nil, name: "Bob", score: 85)
        try bob.insert(db)

        var charlie = Player(id: nil, name: "Charlie", score: 120)
        try charlie.insert(db)
    }

    // Query and display all players
    let players = try dbQueue.read { db in
        try Player.order(Column("score").desc).fetchAll(db)
    }

    print("Players (sorted by score):")
    for player in players {
        print("  \(player.name): \(player.score)")
    }

    // Query specific player
    let topScorer = try dbQueue.read { db in
        try Player.order(Column("score").desc).fetchOne(db)
    }

    if let top = topScorer {
        print("Top scorer: \(top.name) with \(top.score) points")
    }

    print("GRDB example completed successfully!")
}

try main()
