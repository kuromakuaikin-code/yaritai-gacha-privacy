import Foundation
import AVFoundation

/// AVFoundation などの生エラーを、利用者向けの平易な日本語へ変換する。
/// アプリ独自エラー(CompositionEngineError)は既に日本語なのでそのまま通す。
/// 対応が分からないものは fallback(画面ごとの汎用文言)に落とす — 英語まじりの
/// localizedDescription をそのまま見せない。
enum FriendlyError {
    static func message(_ error: Error, fallback: String) -> String {
        if let engineError = error as? CompositionEngineError {
            return engineError.errorDescription ?? fallback
        }

        let nsError = error as NSError
        switch nsError.domain {
        case NSCocoaErrorDomain where nsError.code == NSFileReadNoSuchFileError:
            return "動画ファイルが見つかりませんでした。もう一度えらび直してください"
        case AVFoundationErrorDomain:
            switch nsError.code {
            case AVError.diskFull.rawValue:
                return "iPhoneの空き容量が足りません。写真や不要なアプリを整理してからお試しください"
            case AVError.fileFormatNotRecognized.rawValue,
                 AVError.invalidSourceMedia.rawValue,
                 AVError.failedToLoadMediaData.rawValue:
                return "この動画は読み込めない形式でした。別の動画でお試しください"
            case AVError.decodeFailed.rawValue,
                 AVError.exportFailed.rawValue,
                 AVError.mediaServicesWereReset.rawValue,
                 AVError.operationInterrupted.rawValue:
                return "動画の処理が途中で止まりました。もう一度お試しください"
            default:
                return fallback
            }
        default:
            return fallback
        }
    }
}
