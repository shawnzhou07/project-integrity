import SwiftUI

struct TutorialView: View {
    var isFromSettings: Bool = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var currentPage = 0

    private let totalPages = 6
    private let inactiveDot = Color(hex: "3A3A3A")

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    slide1.tag(0)
                    slide2.tag(1)
                    slide3.tag(2)
                    slide4.tag(3)
                    slide5.tag(4)
                    slide6.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                navControls
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                    .background(Color.appBackground)
            }
        }
    }

    // MARK: - Navigation Controls

    var navControls: some View {
        HStack {
            // Left: Skip (hidden on last slide)
            if currentPage < totalPages - 1 {
                Button("Skip") { finishTutorial() }
                    .font(.system(size: 16))
                    .foregroundColor(.appSecondary)
                    .frame(minWidth: 60, alignment: .leading)
            } else {
                Spacer().frame(width: 60)
            }

            Spacer()

            // Center: dot indicators
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage ? Color.appGold : inactiveDot)
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }

            Spacer()

            // Right: Next or Get Started
            if currentPage < totalPages - 1 {
                Button("Next →") {
                    withAnimation(.easeInOut) { currentPage += 1 }
                }
                .font(.system(size: 16))
                .foregroundColor(.appGold)
                .frame(minWidth: 60, alignment: .trailing)
            } else {
                Button("Get Started") { finishTutorial() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.appGold)
                    .clipShape(Capsule())
            }
        }
    }

    func finishTutorial() {
        if isFromSettings {
            dismiss()
        } else {
            withAnimation(.easeInOut(duration: 0.35)) {
                hasSeenTutorial = true
            }
        }
    }

    // MARK: - Slide 1: Welcome to Veritas

    var slide1: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                Image("veritas-logo")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.appGold)

                Spacer().frame(height: 16)

                Text("Welcome to Veritas")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                Text("Poker Bankroll Tracker")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appGold)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 32)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Not just another tracker.")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Most poker apps just record your buy-ins and cash-outs. Veritas goes further — it tracks your real financial truth, including exchange rates, platform balances, and verified records that can never be altered.")
                        .font(.system(size: 15))
                        .foregroundColor(.appSecondary)
                        .lineSpacing(4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appSurface)
                .cornerRadius(16)
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)
            }
        }
    }

    // MARK: - Slide 2: Verified vs Unverified

    var slide2: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 50)

                HStack(spacing: 16) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.appSecondary)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.appSecondary)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.appGold)
                }

                Spacer().frame(height: 24)

                Text("Two States. One Truth.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 16)

                VStack(spacing: 0) {
                    // Unverified section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("UNVERIFIED")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appBorder)
                            .cornerRadius(6)

                        Text("When you finish a session, it starts as unverified. You can still edit contextual details like location, game type, and blinds.")
                            .font(.system(size: 14))
                            .foregroundColor(.appSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)

                    Divider()
                        .background(Color.appBorder)

                    // Verified section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("VERIFIED")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "1A1500"))
                            .cornerRadius(6)

                        Text("Once you verify a session, the financial details — buy-in, cash-out, and net result — are permanently locked forever. This is your sworn record of truth.")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
                .background(Color.appSurface)
                .cornerRadius(16)
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                Text("Only you can verify a session. Veritas never changes your numbers.")
                    .font(.system(size: 13))
                    .italic()
                    .foregroundColor(.appGold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 24)
            }
        }
    }

    // MARK: - Slide 3: Why Verification Matters

    var slide3: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 50)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.appGold)

                Spacer().frame(height: 20)

                Text("Your Numbers. Locked.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 16)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Other apps let you edit sessions anytime. That means your records are only as honest as your memory — or your mood.")
                        .font(.system(size: 15))
                        .foregroundColor(.appSecondary)

                    Divider()
                        .background(Color.appBorder)

                    Text("Veritas is different. When you verify a session, the buy-in, cash-out, exchange rates, and net result are sealed permanently. No edits. No revisions. No rationalizing a bad session.")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .lineSpacing(4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appSurface)
                .cornerRadius(16)
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                VStack(spacing: 12) {
                    tutorialFeatureRow(icon: "checkmark.circle.fill", iconColor: .appProfit, text: "Financial fields locked after verification")
                    tutorialFeatureRow(icon: "checkmark.circle.fill", iconColor: .appProfit, text: "Contextual details always editable")
                    tutorialFeatureRow(icon: "checkmark.circle.fill", iconColor: .appProfit, text: "One unverified session at a time enforced")
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)
            }
        }
    }

    // MARK: - Slide 4: Exchange Rates

    var slide4: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 50)

                HStack(spacing: 12) {
                    Text("USD")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.appSecondary)

                    Text("CAD")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.appGold)
                }

                Spacer().frame(height: 20)

                Text("Real Exchange Rates. Real Profits.")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Play live cash games in USD but track in CAD? Most apps just apply today's Google rate — which is wrong.")
                        .font(.system(size: 15))
                        .foregroundColor(.appSecondary)

                    Divider()
                        .background(Color.appBorder)

                    Text("Veritas lets you record the actual exchange rate you got at the casino cage or currency exchange — both at buy-in and cash-out separately. Your CAD profit is calculated from what you actually paid and received, not an approximation.")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .lineSpacing(4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appSurface)
                .cornerRadius(16)
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                // Example inner card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Example")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appGold)

                    Text("Buy-in: $200 USD at 1.36 rate = $272.00 CAD cost")
                        .font(.system(size: 13))
                        .foregroundColor(.white)

                    Text("Cash-out: $350 USD at 1.41 rate = $493.50 CAD received")
                        .font(.system(size: 13))
                        .foregroundColor(.white)

                    Divider()
                        .background(Color.appBorder)

                    Text("Real profit: +$221.50 CAD")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appProfit)

                    Text("Not just +$150 USD converted at today's rate")
                        .font(.system(size: 12))
                        .foregroundColor(.appSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appSurface2)
                .cornerRadius(12)
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)
            }
        }
    }

    // MARK: - Slide 5: Platform Balance Tracking

    var slide5: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 50)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.appGold)

                Spacer().frame(height: 20)

                Text("Your Online Bankroll. Perfectly Tracked.")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Veritas tracks every deposit and withdrawal to your online poker platforms — PokerStars, GGPoker, ClubWPT, and more.")
                        .font(.system(size: 15))
                        .foregroundColor(.appSecondary)

                    Divider()
                        .background(Color.appBorder)

                    Text("When you deposit, Veritas records the exact rate you paid. This means your platform profit isn't just a raw number — it's the true CAD return on every dollar you moved.")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .lineSpacing(4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appSurface)
                .cornerRadius(16)
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)

                VStack(spacing: 12) {
                    tutorialFeatureRow(icon: "checkmark.circle.fill", iconColor: .appGold, text: "Track deposits and withdrawals per platform")
                    tutorialFeatureRow(icon: "checkmark.circle.fill", iconColor: .appGold, text: "Real profit accounts for FX rates paid")
                    tutorialFeatureRow(icon: "checkmark.circle.fill", iconColor: .appGold, text: "Current balance always up to date")
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)
            }
        }
    }

    // MARK: - Slide 6: You're Ready

    var slide6: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                Image("veritas-logo")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .foregroundColor(.appGold)

                Spacer().frame(height: 20)

                Text("You're Ready.")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 8)

                Text("Track honestly. Verify truthfully. Know your real numbers.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.appGold)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 32)

                VStack(spacing: 0) {
                    nextStepRow(number: "1.", text: "Start a session after your next game")
                    Divider().background(Color.appBorder)
                    nextStepRow(number: "2.", text: "Record your buy-in and cash-out")
                    Divider().background(Color.appBorder)
                    nextStepRow(number: "3.", text: "Verify it to lock your truth forever")
                }
                .background(Color.appSurface)
                .cornerRadius(16)
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)

                Text("Precision Truth in Every Session.")
                    .font(.system(size: 13))
                    .italic()
                    .foregroundColor(.appSecondary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 24)
            }
        }
    }

    // MARK: - Helper Views

    func tutorialFeatureRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white)
            Spacer()
        }
    }

    func nextStepRow(number: String, text: String) -> some View {
        HStack(spacing: 16) {
            Text(number)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.appGold)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(20)
    }
}

#Preview {
    TutorialView()
        .preferredColorScheme(.dark)
}
