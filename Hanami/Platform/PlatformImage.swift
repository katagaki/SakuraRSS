import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit

public typealias PlatformImage = UIImage
public typealias PlatformImageOrientation = UIImage.Orientation
#else
import AppKit

public typealias PlatformImage = NSImage
public typealias PlatformImageOrientation = PlatformImageBakedOrientation
#endif
