//
//  RxYepAudioService.swift
//  LearnRxSwift
//
//  Created by 宋宋 on 16/4/25.
//  Copyright © 2016年 DianQK. All rights reserved.
//

import UIKit
import AVFoundation
import AudioToolbox
import Proposer
import RxSwift
import RxCocoa
import RxOptional

class RxYepAudioService: NSObject {
    
    static let sharedManager = RxYepAudioService()
    
    var shouldIgnoreStart = false
    
    let queue = dispatch_queue_create("YepAudioService", DISPATCH_QUEUE_SERIAL)
    
    var audioFileURL: NSURL?
    
    var audioRecorder: AVAudioRecorder?
    
    var audioPlayer: AVAudioPlayer?
    
    var onlineAudioPlayer: AVPlayer?
    
    var audioPlayCurrentTime: NSTimeInterval {
        if let audioPlayer = audioPlayer {
            return audioPlayer.currentTime
        }
        return 0
    }
    
    var aduioOnlinePlayCurrentTime: CMTime {
        if let onlineAudioPlayerItem = onlineAudioPlayer?.currentItem {
            return onlineAudioPlayerItem.currentTime()
        }
        return CMTime()
    }
    
    func prepareAudioRecorderWithFileURL(fileURL: NSURL, audioRecorderDelegate: AVAudioRecorderDelegate) {
        
        audioFileURL = fileURL
        
        let settings: [String: AnyObject] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVEncoderAudioQualityKey : AVAudioQuality.Max.rawValue,
            AVEncoderBitRateKey : 64000,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey : 44100.0
        ]
        
        do {
            let audioRecorder = try AVAudioRecorder(URL: fileURL, settings: settings)
            audioRecorder.delegate = audioRecorderDelegate
            audioRecorder.meteringEnabled = true
            audioRecorder.prepareToRecord() // creates/overwrites the file at soundFileURL
            
            self.audioRecorder = audioRecorder
            
        } catch let error {
            self.audioRecorder = nil
            print("create AVAudioRecorder error: \(error)")
        }
    }
    
    var recordTimeoutAction: (() -> Void)?
    
    var checkRecordTimeoutTimer: NSTimer?
    
    func startCheckRecordTimeoutTimer() {
        
        let timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(YepAudioService.checkRecordTimeout(_:)), userInfo: nil, repeats: true)
        
        checkRecordTimeoutTimer = timer
        
        timer.fire()
    }
    
    func checkRecordTimeout(timer: NSTimer) {
        
        if audioRecorder?.currentTime > YepConfig.AudioRecord.longestDuration {
            
            endRecord()
            
            recordTimeoutAction?()
            recordTimeoutAction = nil
        }
    }
    
    func beginRecordWithFileURL(fileURL: NSURL, audioRecorderDelegate: AVAudioRecorderDelegate) {
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryRecord)
        } catch let error {
            print("beginRecordWithFileURL setCategory failed: \(error)")
        }
        
        //dispatch_async(queue) {
        do {
            
            proposeToAccess(.Microphone, agreed: {
                
                self.prepareAudioRecorderWithFileURL(fileURL, audioRecorderDelegate: audioRecorderDelegate)
                
                if let audioRecorder = self.audioRecorder {
                    
                    if (audioRecorder.recording){
                        audioRecorder.stop()
                        
                    } else {
                        if !self.shouldIgnoreStart {
                            audioRecorder.record()
                            print("audio record did begin")
                        }
                    }
                }
                
                }, rejected: {
                    if let
                        appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate,
                        viewController = appDelegate.window?.rootViewController {
                        //                        viewController.alertCanNotAccessMicrophone()
                    }
            })
        }
    }
    
    func endRecord() {
        
        if let audioRecorder = self.audioRecorder {
            if audioRecorder.recording {
                audioRecorder.stop()
            }
        }
        
        dispatch_async(queue) {
            let _ = try? AVAudioSession.sharedInstance().setActive(false, withOptions: AVAudioSessionSetActiveOptions.NotifyOthersOnDeactivation)
        }
        
        self.checkRecordTimeoutTimer?.invalidate()
        self.checkRecordTimeoutTimer = nil
    }
    
    var playbackTimer: NSTimer? {
        didSet {
            if let oldPlaybackTimer = oldValue {
                oldPlaybackTimer.invalidate()
            }
        }
    }
    
    func tryNotifyOthersOnDeactivation() {
        // playback 会导致从音乐 App 进来的时候停止音乐，所以需要重置回去
        
        dispatch_async(queue) {
            let _ = try? AVAudioSession.sharedInstance().setActive(false, withOptions: AVAudioSessionSetActiveOptions.NotifyOthersOnDeactivation)
        }
    }
    
    func resetToDefault() {
        
        tryNotifyOthersOnDeactivation()
        
        //        playingItem = nil
    }
    
    override init() {
        super.init()
        
        // MARK: Proximity
        
        NSNotificationCenter.defaultCenter()
            .rx_notification(UIDeviceProximityStateDidChangeNotification, object: self)
            .subscribeNext { _ in
            if UIDevice.currentDevice().proximityState {
                do {
                    try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
                } catch let error {
                    print("proximityStateChanged setCategory failed: \(error)")
                }
                
            } else {
                do {
                    try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                } catch let error {
                    print("proximityStateChanged setCategory failed: \(error)")
                }
            }
            }.addDisposableTo(rx_disposeBag)
        
    }

}