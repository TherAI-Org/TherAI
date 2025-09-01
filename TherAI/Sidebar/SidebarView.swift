import SwiftUI

struct SlideOutSidebarView: View {
    @Binding var selectedTab: Tab
    @Binding var isOpen: Bool
    @EnvironmentObject private var viewModel: SlideOutSidebarViewModel
    
    enum Tab {
        case chat
        case profile
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with profile picture and chat button
            HStack {
                // Profile Picture Button
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                        selectedTab = .profile
                        isOpen = false
                    }
                }) {
                    ProfilePictureView()
                }
                
                Spacer()
                
                // Chat Button
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                        selectedTab = .chat
                        isOpen = false
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        
                        Image(systemName: "message.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
            
            // Empty space for future content
            Spacer()
            
            // Bottom section for future features
            VStack(spacing: 16) {
                Text("More features coming soon...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // Blue-Pink Gradient Background
            ZStack {
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.8),
                        Color.pink.opacity(0.6),
                        Color.blue.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Floating orbs for depth
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 150, height: 150)
                    .blur(radius: 30)
                    .offset(x: -50, y: -100)
                
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .offset(x: 100, y: 200)
            }
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 5, y: 0)
    }
}

// MARK: - Profile Picture View
struct ProfilePictureView: View {
    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
            
            // White border
            Circle()
                .fill(.white)
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            
            // Main avatar with blue gradient (matching profile screen)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay(
                    Text("M")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
        }
    }
}

struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Keep the old SidebarView for backward compatibility if needed
struct SidebarView: View {
    @Binding var selectedTab: Tab
    @State private var isExpanded = false
    
    enum Tab {
        case chat
        case profile
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Text("TherAI")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "sidebar.right" : "sidebar.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                }
                
                Divider()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Navigation Items
            VStack(spacing: 8) {
                SidebarItem(
                    title: "Chat",
                    icon: "message.fill",
                    isSelected: selectedTab == .chat
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = .chat
                    }
                }
                
                SidebarItem(
                    title: "Profile",
                    icon: "person.fill",
                    isSelected: selectedTab == .profile
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = .profile
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(width: isExpanded ? 250 : 80)
        .background(Color(.systemBackground))

    }
}

#Preview {
    SlideOutSidebarView(selectedTab: .constant(.chat), isOpen: .constant(true))
}
