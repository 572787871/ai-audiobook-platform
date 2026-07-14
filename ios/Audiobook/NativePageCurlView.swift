import SwiftUI
import UIKit

struct NativePageCurlView: UIViewControllerRepresentable {
  let pages: [ReaderPage]
  @Binding var currentIndex: Int
  let background: UIColor
  let foreground: UIColor
  let fontSize: CGFloat
  let lineSpacing: CGFloat
  let horizontalPadding: CGFloat
  let onCenterTap: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeUIViewController(context: Context) -> UIPageViewController {
    let controller = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal)
    controller.isDoubleSided = false
    controller.dataSource = context.coordinator
    controller.delegate = context.coordinator
    controller.view.backgroundColor = background
    controller.setViewControllers([context.coordinator.controller(at: currentIndex)], direction: .forward, animated: false)
    let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.centerTapped(_:)))
    tap.delegate = context.coordinator
    controller.view.addGestureRecognizer(tap)
    return controller
  }

  func updateUIViewController(_ controller: UIPageViewController, context: Context) {
    context.coordinator.parent = self
    let signature = context.coordinator.renderSignature
    let nextSignature = RenderSignature(
      pageCount: pages.count,
      pageRanges: pages.map(\.range),
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      horizontalPadding: horizontalPadding,
      background: background,
      foreground: foreground
    )
    if signature != nextSignature {
      context.coordinator.renderSignature = nextSignature
      context.coordinator.visibleIndex = min(max(0, currentIndex), max(0, pages.count - 1))
      controller.view.backgroundColor = background
      controller.setViewControllers([context.coordinator.controller(at: context.coordinator.visibleIndex)], direction: .forward, animated: false)
      return
    }
    guard context.coordinator.visibleIndex != currentIndex else { return }
    let direction: UIPageViewController.NavigationDirection = currentIndex > context.coordinator.visibleIndex ? .forward : .reverse
    controller.setViewControllers([context.coordinator.controller(at: currentIndex)], direction: direction, animated: true)
    context.coordinator.visibleIndex = currentIndex
  }

  final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate {
    var parent: NativePageCurlView
    var visibleIndex: Int
    var renderSignature: RenderSignature
    init(_ parent: NativePageCurlView) {
      self.parent = parent
      visibleIndex = parent.currentIndex
      renderSignature = RenderSignature(
        pageCount: parent.pages.count,
        pageRanges: parent.pages.map(\.range),
        fontSize: parent.fontSize,
        lineSpacing: parent.lineSpacing,
        horizontalPadding: parent.horizontalPadding,
        background: parent.background,
        foreground: parent.foreground
      )
    }

    func controller(at index: Int) -> UIViewController {
      let page = parent.pages[min(max(0, index), max(0, parent.pages.count - 1))]
      let controller = UIViewController()
      let pageView = CoreTextReaderPageView(frame: .zero)
      pageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      pageView.frame = controller.view.bounds
      pageView.configure(
        text: page.text,
        startsMidParagraph: page.startsMidParagraph,
        fontSize: parent.fontSize,
        lineSpacing: parent.lineSpacing,
        horizontalPadding: parent.horizontalPadding,
        foreground: parent.foreground,
        background: parent.background
      )
      controller.view.addSubview(pageView)
      controller.view.tag = index
      controller.view.backgroundColor = parent.background
      return controller
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
      let index = viewController.view.tag - 1
      return index >= 0 ? controller(at: index) : nil
    }
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
      let index = viewController.view.tag + 1
      return index < parent.pages.count ? controller(at: index) : nil
    }
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
      guard completed, let index = pageViewController.viewControllers?.first?.view.tag else { return }
      visibleIndex = index; parent.currentIndex = index
    }
    @objc func centerTapped(_ gesture: UITapGestureRecognizer) {
      let x = gesture.location(in: gesture.view).x
      let width = gesture.view?.bounds.width ?? 1
      if x > width * 0.32 && x < width * 0.68 { parent.onCenterTap() }
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
  }
}

struct RenderSignature: Equatable {
  let pageCount: Int
  let pageRanges: [NSRange]
  let fontSize: CGFloat
  let lineSpacing: CGFloat
  let horizontalPadding: CGFloat
  let background: UIColor
  let foreground: UIColor

  static func == (lhs: RenderSignature, rhs: RenderSignature) -> Bool {
    lhs.pageCount == rhs.pageCount
      && lhs.pageRanges == rhs.pageRanges
      && lhs.fontSize == rhs.fontSize
      && lhs.lineSpacing == rhs.lineSpacing
      && lhs.horizontalPadding == rhs.horizontalPadding
      && lhs.background.isEqual(rhs.background)
      && lhs.foreground.isEqual(rhs.foreground)
  }
}
