import SQLiteData

@Table
private struct Hobbit: Equatable {
  let id: Int
  var firstName: String
  var lastName: String
}

@main
struct Main {
  static func main() async throws {
    let database = try DatabaseQueue()
    try await withDependencies {
      $0.defaultDatabase = database
    } operation: {
      try await database.write { db in
        try #sql(
          """
          CREATE TABLE "hobbits" (
          "id" INTEGER PRIMARY KEY AUTOINCREMENT,
          "firstName" TEXT NOT NULL,
          "lastName" TEXT NOT NULL
          )
          """
        )
        .execute(db)
        _ = try Hobbit.insert { Hobbit(id: 1, firstName: "Frodo", lastName: "Baggins") }.execute(db)
        _ = try Hobbit.insert { Hobbit(id: 3, firstName: "Samwise", lastName: "Gamgee") }.execute(db)
      }

      @FetchAll var hobbits: [Hobbit]

      try await $hobbits.load()
      for hobbit in hobbits {
        print(hobbit.id, hobbit.firstName, hobbit.lastName)
      }
    }
  }
}
