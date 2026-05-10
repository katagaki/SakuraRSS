import WebKit
import Hanami

struct InjectedUserScript {
    let source: String
    let time: WKUserScriptInjectionTime
    let mainFrameOnly: Bool
}
