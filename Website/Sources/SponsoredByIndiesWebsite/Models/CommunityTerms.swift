struct CommunityTerms: Decodable {
    var updatedOn: String
    var introduction: String
    var sections: [Section]

    struct Section: Decodable {
        var heading: String
        var paragraphs: [String]
    }
}
