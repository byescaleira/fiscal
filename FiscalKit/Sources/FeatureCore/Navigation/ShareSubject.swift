public enum ShareSubject: Hashable, Sendable {
    case person(slug: String)
    case vote(id: String)
    case expenses(slug: String, year: Int)
    case race(id: String)
    case compare(slugs: [String])
    case representatives(uf: String)
    case highlight(id: String)
}
