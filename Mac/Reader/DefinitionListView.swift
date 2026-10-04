import Hanami
import SwiftUI

struct DefinitionListView: View {

    let items: [ContentBlock.DefinitionListItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.term)
                        .font(.system(size: 15, weight: .semibold))
                    ForEach(item.definitions, id: \.self) { definition in
                        Text(definition)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
