import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit

public typealias PlatformImage = UIImage
public typealias PlatformImageOrientation = UIImage.Orientation
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
#else
import AppKit

public typealias PlatformImage = NSImage
public typealias PlatformImageOrientation = PlatformImageBakedOrientation
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
#endif
