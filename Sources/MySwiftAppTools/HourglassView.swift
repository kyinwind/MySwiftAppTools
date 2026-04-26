//
//  HourglassView.swift
//  RightClickMate
//
//  Created by yangxuehui on 2026/3/6.
//

import SwiftUI
import AVFoundation

// MARK: - 沙漏边框
struct HourglassFrame: Shape {
    
    func path(in rect: CGRect) -> Path {
        
        var path = Path()
        
        let w = rect.width
        let neckWidth = w * 0.15
        
        // 上半部分
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + neckWidth/2, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX - neckWidth/2, y: rect.midY))
        path.closeSubpath()
        
        // 下半部分
        path.move(to: CGPoint(x: rect.midX + neckWidth/2, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - neckWidth/2, y: rect.midY))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - 三角形
struct Triangle: Shape {
    
    func path(in rect: CGRect) -> Path {
        
        var path = Path()
        
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        path.closeSubpath()
        
        return path
    }
}

// MARK: - 沙堆形状
struct SandPile: Shape {
    
    func path(in rect: CGRect) -> Path {
        
        var path = Path()
        
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.midY)
        )
        
        path.closeSubpath()
        
        return path
    }
}

// MARK: - 上半部分沙子
struct SandTop: View {
    
    var progress: Double
    
    var body: some View {
        
        GeometryReader { geo in
            
            let h = geo.size.height
            
            Triangle()
                .rotation(.degrees(180))
                .fill(Color.orange)
                .mask(
                    VStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .frame(height: h * (1 - progress))
                    }
                )
        }
    }
}

// MARK: - 下半部分沙子
struct SandBottom: View {
    
    var progress: Double
    
    var body: some View {
        
        GeometryReader { geo in
            
            let h = geo.size.height
            
            ZStack(alignment: .bottom) {
                
                Triangle()
                    .fill(Color.orange.opacity(0.9))
                
                
                SandPile()
                    .fill(Color.orange)
                    .frame(height: h * 0.25)
            }
            .mask(
                VStack(spacing: 0) {
                    
                    Spacer(minLength: 0)
                    
                    Rectangle()
                        .frame(height: h * progress)
                }
            )
            .animation(.easeInOut(duration: 0.25), value: progress)
        }
    }
}

// MARK: - 沙粒
struct SandParticle: View {
    @State private var offset: CGFloat = 0
    @State private var delay: Double = 0
    
    // 允许外部传入大小，默认给一个值以防万一
    var size: CGFloat = 3.0
    
    var body: some View {
        Circle()
            .fill(Color.orange)
            .frame(width: size, height: size) // 动态大小
            .offset(y: offset)
            .onAppear {
                // 动画距离也可以基于 size 动态调整，防止沙粒很大但移动距离很短
                let moveRange = max(40, size * 10)
                
                let duration = Double.random(in: 0.6...1.2)
                delay = Double.random(in: 0...0.5)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                        offset = moveRange
                    }
                }
            }
    }
}

// MARK: - 流沙
struct SandFlow: View {
    var active: Bool
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            // 假设沙粒宽度占流沙通道宽度的 25% (根据你的美学调整)
            let particleSize = width * 0.25
            
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    SandParticle(size: particleSize)
                        .opacity(active ? 1 : 0)
                        // 水平分散间距也基于沙粒大小
                        .offset(x: CGFloat(index - 4) * (particleSize * 0.6))
                }
            }
            .frame(width: width)
        }
    }
}

// MARK: - 沙漏组件
struct HourglassView: View {
    
    /// 0 = 刚开始
    /// 1 = 结束
    @Binding var progress: Double
    @State var completionPlayer: AVAudioPlayer?
    
    var body: some View {
        
        ZStack(alignment: .center) {
            
            // 边框
            HourglassFrame()
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.9),
                            .white.opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 3
                )
                .shadow(color: .white.opacity(0.3), radius: 4)
                //.border(Color.yellow, width: 3)
            HStack(alignment: .center){
                Spacer()
                GeometryReader { geo in
                    
                    let w = geo.size.width
                    let h = geo.size.height
                    
                    VStack(alignment: .center,spacing: 0) {
                        SandTop(progress: progress)
                            .frame(width: w * 0.99, height: h * 0.48)
                        // 下沙
                        SandBottom(progress: progress)
                            .frame(width: w * 0.99, height: h * 0.48)
                    }
                    .padding(.vertical, h * 0.02) // 上下各留 2% 的边距
                    .padding(.horizontal, w * 0.005) // 左右微调
                    //.border(Color.red, width: 3)
                    //.frame(maxWidth: .infinity,maxHeight: .infinity)
                    .overlay(
                        // 流沙
                        VStack(alignment: .center){
                            Spacer(minLength: h * 0.5) // 👈 精确控制起始位置
                            SandFlow(active: progress > 0.01 && progress < 0.99)
                                .frame(width: w * 0.05, height: h * 0.3)
                                //.border(Color.white, width: 3)
                            Spacer()
                        }
                        
                    )
                }
                //.border(Color.white, width: 3)
                Spacer()
            }
            
        }
        .aspectRatio(1, contentMode: .fit)
        
        //.border(Color.blue, width: 3)
    }
}

// MARK: - 预览
// MARK: - 预览与测试
struct HourglassView_Previews: PreviewProvider {
    struct Container: View {
        @State var prog: Double = 0.5
        
        var body: some View {
            VStack {
                HourglassView(progress: $prog)
                    .frame(width: 200, height: 200)
                    .background(Color.black) // 深色背景方便查看白色边框
                
                Slider(value: $prog, in: 0...1)
                    .padding()
                
                Text("Progress: \(prog, specifier: "%.2f")")
            }
        }
    }
    
    static var previews: some View {
        Container()
    }
}
