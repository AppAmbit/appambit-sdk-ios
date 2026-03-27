import SwiftUI
import AppAmbit

struct CmsView: View {
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var selectedFilter = "All Posts"

    let filters = [
        "All Posts",
        "Category = tech",
        "Category ≠ tech",
        "Search 'swift'",
        "Title contains 't1'",
        "Category starts with 'n'",
        "Category IN [science, tech]",
        "Category NOT IN [tech, news]",
        "Views > 1000",
        "Views ≥ 555",
        "Views < 15000",
        "Views ≤ 15000",
        "Sort Title ↑",
        "Sort Title ↓",
        "Page 1 (2 per page)"
    ]

    var body: some View {
        NavigationView {
            VStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(filters, id: \.self) { filter in
                            Button(action: {
                                selectedFilter = filter
                                loadPosts()
                            }) {
                                Text(filter)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding()
                }

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    List(posts) { post in
                        PostCard(post: post)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("CMS Posts")
            .onAppear {
                loadPosts()
            }
        }
    }

    private func loadPosts() {
        isLoading = true
        let query = Cms.content("blog_extended", modelType: Post.self)

        switch selectedFilter {
        case "Category = tech": _ = query.equals("category", "tech")
        case "Category ≠ tech": _ = query.notEquals("category", "tech")
        case "Search 'swift'": _ = query.search("swift")
        case "Title contains 't1'": _ = query.contains("title", "t1")
        case "Category starts with 'n'": _ = query.startsWith("category", "n")
        case "Category IN [science, tech]": _ = query.inList("category", ["science", "tech"])
        case "Category NOT IN [tech, news]": _ = query.notInList("category", ["tech", "news"])
        case "Views > 1000": _ = query.greaterThan("views_count", 1000)
        case "Views ≥ 555": _ = query.greaterThanOrEqual("views_count", 555)
        case "Views < 15000": _ = query.lessThan("views_count", 15000)
        case "Views ≤ 15000": _ = query.lessThanOrEqual("views_count", 15000)
        case "Sort Title ↑": _ = query.orderByAscending("title")
        case "Sort Title ↓": _ = query.orderByDescending("title")
        case "Page 1 (2 per page)": _ = query.setPage(1).setPerPage(2)
        default: break
        }

        query.getList { results in
            DispatchQueue.main.async {
                self.posts = results
                self.isLoading = false
            }
        }
    }
}

struct PostCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageUrl = post.featuredImage, let url = URL(string: imageUrl) {
                Color.clear
                    .frame(height: 200)
                    .overlay(
                        AsyncImage(url: url) { image in
                            image.resizable()
                                 .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.2))
                        }
                    )
                    .clipped()
                    .cornerRadius(12)
            }

            Text(post.title ?? "No Title")
                .font(.headline)
            
            Text(post.body ?? "")
                .font(.subheadline)
                .lineLimit(3)
                .foregroundColor(.secondary)

            HStack {
                Label("\(Int(post.viewsCount ?? 0))", systemImage: "eye.fill")
                Spacer()
                Text(post.author?.displayString ?? post.authorEmail ?? "No Author")
            }
            .font(.caption)
            .padding(.top, 4)

            HStack {
                if let isPublished = post.isPublished {
                    Text(isPublished ? "Published" : "Draft")
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isPublished ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .foregroundColor(isPublished ? .green : .orange)
                        .cornerRadius(4)
                }
                Spacer()
                Text(post.category ?? "Uncategorized")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            
            if let date = post.eventDate {
                Text("Event: \(date)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if let meta = post.metaData {
                Text("Meta: \(meta.description)")
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
    }
}
