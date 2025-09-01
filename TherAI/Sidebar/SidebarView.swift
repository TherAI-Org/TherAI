import SwiftUI

struct SlideOutSidebarView: View {
    @Binding var selectedTab: Tab
    @Binding var isOpen: Bool
    
    enum Tab {
        case chat
        case profile
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Text("TherAI")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                        isOpen = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
            
            // Navigation Items
            VStack(spacing: 8) {
                SidebarItem(
                    title: "Chat",
                    icon: "message.fill",
                    isSelected: selectedTab == .chat
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                        selectedTab = .chat
                        isOpen = false
                    }
                }
                
                SidebarItem(
                    title: "Profile",
                    icon: "person.fill",
                    isSelected: selectedTab == .profile
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                        selectedTab = .profile
                        isOpen = false
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(.separator)),
            alignment: .trailing
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 5, y: 0)
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
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(.separator)),
            alignment: .trailing
        )
    }
}

#Preview {
    SlideOutSidebarView(selectedTab: .constant(.chat), isOpen: .constant(true))
}
