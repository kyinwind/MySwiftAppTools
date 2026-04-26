//
//  AudioPlayer.swift
//

import SwiftUI
import AVFoundation
import AppKit
import Combine

@MainActor
public final class AudioPlayer: NSObject, ObservableObject {
    
    public static let shared = AudioPlayer()
    
    @Published public var player: AVAudioPlayer?
    @Published public var isPlaying: Bool = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - 播放 Bundle 音频
    
    public func playAudio(forResource name: String,
                   ofType type: String,
                   rate: Float = 1.0) {
        
        guard let url = Bundle.main.url(forResource: name, withExtension: type) else {
            print("❌ 找不到音频文件 \(name).\(type)")
            return
        }
        
        play(url: url, rate: rate)
    }
    
    // MARK: - 直接播放 URL
    
    public func play(url: URL, rate: Float = 1.0) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.enableRate = true
            player?.rate = rate
            player?.numberOfLoops = 0
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            
            isPlaying = true
        } catch {
            print("❌ 音频播放失败: \(error)")
        }
    }
    
    // MARK: - 预加载音频
    
    public func loadAudio(forResource name: String, ofType type: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: type) else {
            print("❌ 找不到音频文件")
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
        } catch {
            print("❌ 音频加载失败 \(error)")
        }
    }
    
    // MARK: - 控制
    
    public func play(rate: Float = 1.0) {
        player?.enableRate = true
        player?.rate = rate
        player?.play()
        isPlaying = true
    }
    
    public func pause() {
        player?.pause()
        isPlaying = false
    }
    
    public func stop() {
        player?.stop()
        isPlaying = false
    }
    
    // MARK: - 播放 macOS 系统提示音
    
    public func playSystemSound(_ name: String = "Glass", times: Int = 6) {
        for i in 0..<times {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 1) {
                NSSound(named: name)?.play()
            }
        }
    }
    
    // MARK: - Zen / 专注提示音
    
    public func playCompletionSound() {
        playSystemSound("Tink")
    }
}


extension AudioPlayer: AVAudioPlayerDelegate {
    
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            AudioPlayer.shared.isPlaying = false
            NotificationCenter.default.post(
                name: Notification.Name("AudioPlayerFinished"),
                object: nil
            )
        }
    }
}
