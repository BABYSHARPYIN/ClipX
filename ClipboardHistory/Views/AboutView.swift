import SwiftUI

struct AboutView: View {
    @EnvironmentObject var locale: LocaleManager

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.25))
                    .frame(width: 80, height: 80)

                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
            }

            Text(locale.tr("about.title"))
                .font(.system(size: 16, weight: .bold))

            Text(locale.tr("about.subtitle"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text(locale.tr("about.description"))
                    .font(.system(size: 12))
                Text(locale.tr("about.built"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(width: 220)

            Text(locale.tr("about.contact"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/BABYSHARPYIN")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 11))
                        Text("github.com/BABYSHARPYIN")
                            .font(.system(size: 12))
                    }
                }

                Link(destination: URL(string: "mailto:1455395994@qq.com")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope")
                            .font(.system(size: 11))
                        Text("1455395994@qq.com")
                            .font(.system(size: 12))
                    }
                }
            }

            Text(locale.tr("about.thanks"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(width: 320)
    }
}
