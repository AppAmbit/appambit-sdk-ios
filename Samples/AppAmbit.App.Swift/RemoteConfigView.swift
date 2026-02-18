import SwiftUI
import AppAmbit

struct RemoteConfigView: View {
    
    @State private var bannerVisible: Bool = false
    @State private var message: String = ""
    @State private var discount: Int = 0
    @State private var maxUpload: Double = 0.0

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                
                if bannerVisible {
                    VStack {
                        Text("BANNER")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Remote Data:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    Text(message.isEmpty ? "No message" : message)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 2)
                        )
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Discount:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.green)
                        Text("\(discount)% available")
                            .font(.headline)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green, lineWidth: 2)
                    )
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Max Upload Size:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    Text(String(format: "%.1f MB", maxUpload))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 2)
                        )
                        .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .onAppear {
            updateValues()
        }
    }
    
    private func updateValues() {
        bannerVisible = RemoteConfig.getBoolean("banner")
        message = RemoteConfig.getString("data")
        discount = RemoteConfig.getInt("discount")
        maxUpload = RemoteConfig.getDouble("max_upload")
    }
}
