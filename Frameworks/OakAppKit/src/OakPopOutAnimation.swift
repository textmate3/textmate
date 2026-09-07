import AppKit
import QuartzCore

/// The yellow flash: the text at a place the caret was sent to,
/// drawn once on a yellow card over the text view, popped up and faded out,
/// so the eye finds where a find, a live search or a bracket step landed.
/// It has been TextMate's since the first one.
@objc(OakPopOutAnimation)
@MainActor
public final class PopOutAnimation: NSObject {
  private static let extendWidth: CGFloat = 4
  private static let extendHeight: CGFloat = 1
  private static let maxScale: CGFloat = 1.3
  private static let shadowRadius: CGFloat = 2

  /// The flashes still on screen, so a new one can clear them.
  private static var live: [PopOutView] = []

  /// Shows the image, the rendered text of the range,
  /// over its rectangle in screen coordinates.
  /// With hidePrevious the flashes already showing go first,
  /// which is how a find clears the last one and a find all stacks them up.
  @objc public static func show(in parentView: NSView, at popOutRect: NSRect, image: NSImage, hidePrevious: Bool) {
    guard popOutRect.width > 0, popOutRect.height > 0 else { return }

    if hidePrevious {
      for view in live {
        view.finish()
      }
      live.removeAll()
    }

    // Room around the rectangle for the pop and the shadow, in the window, and the card's place inside it.
    var cardRect = popOutRect.insetBy(dx: -extendWidth, dy: -extendHeight)
    var windowRect = cardRect
    let extraWidth = ceil((maxScale - 1) * (cardRect.width + 4 * shadowRadius) / 2)
    let extraHeight = ceil((maxScale - 1) * (cardRect.height + 4 * shadowRadius) / 2)
    windowRect.origin.x -= extraWidth
    windowRect.origin.y -= extraHeight
    windowRect.size.width += 2 * extraWidth
    windowRect.size.height += 2 * extraHeight
    cardRect.origin = CGPoint(x: extraWidth, y: extraHeight)

    let window = NSWindow(contentRect: windowRect, styleMask: .borderless, backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.backgroundColor = .clear
    window.isExcludedFromWindowsMenu = true
    window.ignoresMouseEvents = true
    window.isOpaque = false
    window.contentView?.wantsLayer = true

    let view = PopOutView(frame: window.contentView?.bounds ?? .zero, cardRect: cardRect, image: blackened(image))
    view.autoresizingMask = [.width, .height]
    window.contentView?.addSubview(view)

    if let scrollView = parentView.enclosingScrollView {
      NotificationCenter.default.addObserver(view, selector: #selector(PopOutView.parentViewBoundsDidChange(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }

    window.setFrame(window.frameRect(forContentRect: windowRect), display: true)
    parentView.window?.addChildWindow(window, ordered: .above)
    live.append(view)
    view.start()
  }

  /// The text in black, whatever color it was drawn in, so it reads on yellow.
  private static func blackened(_ image: NSImage) -> NSImage {
    let result = NSImage(size: image.size, flipped: false) { rect in
      image.draw(in: rect)
      NSColor.black.set()
      rect.fill(using: .sourceAtop)
      return true
    }
    return result
  }

  fileprivate static func forget(_ view: PopOutView) {
    live.removeAll { $0 === view }
  }
}

/// One flash: a yellow rounded card with the text on it, and the animation that pops and fades it.
@MainActor
private final class PopOutView: NSView {
  private static let rectXRadius: CGFloat = 2
  private static let rectYRadius: CGFloat = 2
  private static let growStartTime = 0.00
  private static let growFinishTime = 0.10
  private static let fadeStartTime = 0.35
  private static let fadeFinishTime = 0.70

  private let shapeLayer = CAShapeLayer()
  private let imageLayer = CALayer()
  private let image: NSImage

  init(frame: NSRect, cardRect: NSRect, image: NSImage) {
    self.image = image
    super.init(frame: frame)

    var shapeRect = cardRect
    shapeRect.origin = .zero
    shapeRect = shapeRect.insetBy(dx: 0.25, dy: 0.25)
    let tooSmallToBeRounded = shapeRect.width < 2 * PopOutView.rectXRadius || shapeRect.height < 2 * PopOutView.rectYRadius
    let path = tooSmallToBeRounded ? CGPath(rect: shapeRect, transform: nil) : CGPath(roundedRect: shapeRect, cornerWidth: PopOutView.rectXRadius, cornerHeight: PopOutView.rectYRadius, transform: nil)

    wantsLayer = true

    shapeLayer.frame = cardRect
    shapeLayer.fillColor = NSColor.yellow.cgColor
    shapeLayer.strokeColor = NSColor(calibratedWhite: 0, alpha: 0.1).cgColor
    shapeLayer.lineWidth = 0.5
    shapeLayer.path = path
    shapeLayer.shadowOpacity = 0.25
    shapeLayer.shadowRadius = PopOutAnimation.shadowRadiusForView
    shapeLayer.shadowOffset = CGSize(width: 0, height: -1)
    layer?.addSublayer(shapeLayer)
    shapeLayer.addSublayer(imageLayer)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("The pop out is not loaded from a nib.")
  }

  override func viewDidMoveToWindow() {
    guard let scale = window?.screen?.backingScaleFactor, scale > 0 else { return }
    imageLayer.contents = image.layerContents(forContentsScale: scale)
    imageLayer.bounds = CGRect(origin: .zero, size: image.size)
    imageLayer.position = CGPoint(x: shapeLayer.bounds.midX, y: shapeLayer.bounds.midY)
  }

  /// One animation group, made once and copied onto each flash:
  /// a pop up and back in the first tenth of a second, a hold,
  /// then a fade between a third and two thirds of a second.
  private static let animationGroup: CAAnimationGroup = {
    let grow = CABasicAnimation(keyPath: "transform.scale")
    grow.beginTime = growStartTime
    grow.duration = (growFinishTime - growStartTime) / 2
    grow.fromValue = 1
    grow.toValue = PopOutAnimation.maxScaleForView
    grow.autoreverses = true
    grow.timingFunction = CAMediaTimingFunction(name: .easeIn)

    let fade = CABasicAnimation(keyPath: "opacity")
    fade.beginTime = fadeStartTime
    fade.duration = fadeFinishTime - fadeStartTime
    fade.fromValue = 1
    fade.toValue = 0
    fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

    let group = CAAnimationGroup()
    group.animations = [grow, fade]
    group.duration = fadeFinishTime
    group.fillMode = .forwards
    group.isRemovedOnCompletion = false
    return group
  }()

  func start() {
    let group = PopOutView.animationGroup
    group.delegate = self
    group.speed = 1
    shapeLayer.add(group, forKey: nil)
    group.delegate = nil
  }

  /// Ends the flash: the animation goes, since it holds the delegate, and the window closes.
  func finish() {
    shapeLayer.removeAllAnimations()
    window?.close()
    PopOutAnimation.forget(self)
  }

  @objc func parentViewBoundsDidChange(_ notification: Notification) {
    finish()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}

extension PopOutView: @preconcurrency CAAnimationDelegate {
  func animationDidStop(_ animation: CAAnimation, finished: Bool) {
    finish()
  }
}

extension PopOutAnimation {
  fileprivate static var shadowRadiusForView: CGFloat { shadowRadius }
  fileprivate static var maxScaleForView: CGFloat { maxScale }
}
