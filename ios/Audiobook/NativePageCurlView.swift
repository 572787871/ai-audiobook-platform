import SwiftUI
import UIKit

struct NativePageCurlView: UIViewControllerRepresentable {
  let pages: [String]
  @Binding var currentIndex: Int
  let background: UIColor
  let foreground: UIColor
  let fontSize: CGFloat
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
    guard context.coordinator.visibleIndex != currentIndex else { return }
    let direction: UIPageViewController.NavigationDirection = currentIndex > context.coordinator.visibleIndex ? .forward : .reverse
    controller.setViewControllers([context.coordinator.controller(at: currentIndex)], direction: direction, animated: true)
    context.coordinator.visibleIndex = currentIndex
  }

  final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate {
    var parent: NativePageCurlView
    var visibleIndex: Int
    init(_ parent: NativePageCurlView) { self.parent = parent; visibleIndex = parent.currentIndex }

    func controller(at index: Int) -> UIViewController {
      let view = PageTextView(text: parent.pages[index], background: Color(parent.background), foreground: Color(parent.foreground), fontSize: parent.fontSize)
      let host = UIHostingController(rootView: view)
      host.view.tag = index
      host.view.backgroundColor = parent.background
      return host
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

private struct PageTextView: View {
  let text: String; let background: Color; let foreground: Color; let fontSize: CGFloat
  var body: some View {
    ZStack {
      background.ignoresSafeArea()
      Text(text).font(.system(size: fontSize, design: .serif)).foregroundStyle(foreground).lineSpacing(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(.horizontal, 30).padding(.top, 76).padding(.bottom, 40)
    }
  }
}
