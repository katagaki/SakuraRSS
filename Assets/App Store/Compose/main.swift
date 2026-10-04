import Foundation

let languages = ["en", "ja"]

var allComposed = true
for language in languages {
    for spread in IPhoneSpreads.all + IPadSpreads.all + MacSpreads.all {
        allComposed = compose(spread, language: language) && allComposed
    }
}
exit(allComposed ? 0 : 1)
