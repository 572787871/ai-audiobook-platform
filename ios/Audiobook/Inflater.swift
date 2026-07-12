import Foundation

/// 纯 Swift 的 RFC1951 (zlib/deflate) 解压缩实现。
/// 忠实移植自 zlib 发行版随附的参考解压器 `puff.c`（Mark Adler, zlib），
/// 仅依赖 Foundation，可在 iOS 真机直接调用（无需 Compression/系统库），
/// 用于解压 EPUB（zip）内部的 deflate 压缩内容文档。
enum Inflater {
  enum InflateError: Error { case structure }

  /// 解压 raw DEFLATE 数据（不含 zlib 头；zip 内部即如此）。
  static func inflate(_ source: Data) -> Data? {
    var s = State(source: source)
    return s.puff()
  }

  private struct State {
    let input: Data
    var index = 0
    var bitbuf: UInt = 0
    var bitcnt = 0
    var output = Data()

    init(source: Data) { self.input = source }

    static let lenbase: [Int] = [3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258]
    static let lenext: [Int] = [0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0]
    static let distbase: [Int] = [1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577]
    static let distext: [Int] = [0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13]
    static let order: [Int] = [16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15]

    mutating func puff() -> Data? {
      while true {
        let last = bits(1)
        let typ = bits(2)
        if typ == 0 {
          stored()
        } else if typ == 1 {
          if codes(fixedLengths(), fixedDists()) != 0 { return nil }
        } else if typ == 2 {
          guard let (l, d) = dynamic() else { return nil }
          if codes(l, d) != 0 { return nil }
        } else {
          return nil
        }
        if last != 0 { break }
      }
      return output
    }

    mutating func bits(_ need: Int) -> Int {
      while bitcnt < need {
        if index >= input.count {
          bitbuf |= 0 << bitcnt
        } else {
          bitbuf |= UInt(input[index]) << bitcnt
          index += 1
        }
        bitcnt += 8
      }
      let val = Int(bitbuf & ((1 << need) - 1))
      bitbuf >>= need
      bitcnt -= need
      return val
    }

    mutating func stored() {
      // 丢弃到字节边界
      if bitcnt & 7 != 0 { _ = bits(bitcnt & 7) }
      guard index + 4 <= input.count else { return }
      let len = Int(input[index]) | (Int(input[index + 1]) << 8)
      index += 4
      guard index + len <= input.count else { return }
      output.append(input.subdata(in: index..<(index + len)))
      index += len
    }

    func construct(_ lengths: [Int], _ n: Int) -> (count: [Int], symbol: [Int], maxbits: Int)? {
      var count = Array(repeating: 0, count: 16)
      var offs = Array(repeating: 0, count: 17)
      for sym in 0..<n { count[lengths[sym]] += 1 }
      if count[0] == n { return (count, Array(repeating: -1, count: n), 0) }
      var left = 1
      for l in 1..<16 {
        left <<= 1
        left -= count[l]
        if left < 0 { return nil }
      }
      offs[1] = 0
      for l in 1..<15 { offs[l + 1] = offs[l] + count[l] }
      var symbol = Array(repeating: -1, count: n)
      var offs2 = offs
      for sym in 0..<n {
        if lengths[sym] != 0 {
          symbol[offs2[lengths[sym]]] = sym
          offs2[lengths[sym]] += 1
        }
      }
      let maxbits = lengths.filter { $0 > 0 }.max() ?? 0
      return (count, symbol, maxbits)
    }

    mutating func decode(_ h: (count: [Int], symbol: [Int], maxbits: Int)) -> Int {
      var code = 0, first = 0, idx = 0
      for l in 1...h.maxbits {
        code |= bits(1)
        let c = h.count[l]
        if code - c < first { return h.symbol[idx + (code - first)] }
        idx += c; first += c; first <<= 1; code <<= 1
      }
      return -10
    }

    mutating func codes(_ lencode: (count: [Int], symbol: [Int], maxbits: Int),
                        _ distcode: (count: [Int], symbol: [Int], maxbits: Int)) -> Int {
      while true {
        let symbol = decode(lencode)
        if symbol < 0 { return 2 }
        if symbol == 256 { return 0 }
        if symbol < 256 {
          output.append(UInt8(symbol))
        } else {
          let sym = symbol - 257
          guard sym < State.lenbase.count else { return 2 }
          let length = State.lenbase[sym] + (State.lenext[sym] > 0 ? bits(State.lenext[sym]) : 0)
          let d = decode(distcode)
          guard d >= 0, d < State.distbase.count else { return 2 }
          let dist = State.distbase[d] + (State.distext[d] > 0 ? bits(State.distext[d]) : 0)
          guard dist <= output.count else { return 2 }
          for _ in 0..<length { output.append(output[output.count - dist]) }
        }
      }
    }

    func fixedLengths() -> [Int] {
      var lengths = Array(repeating: 8, count: 288)
      for i in 144..<256 { lengths[i] = 9 }
      for i in 256..<280 { lengths[i] = 7 }
      for i in 280..<288 { lengths[i] = 8 }
      return lengths
    }
    func fixedDists() -> [Int] { Array(repeating: 5, count: 30) }

    mutating func dynamic() -> ((count: [Int], symbol: [Int], maxbits: Int),
                                (count: [Int], symbol: [Int], maxbits: Int))? {
      let nlen = bits(5) + 257
      let ndist = bits(5) + 1
      let ncode = bits(4) + 4
      var lengths = Array(repeating: 0, count: 19)
      for i in 0..<ncode { lengths[State.order[i]] = bits(3) }
      guard let h = construct(lengths, 19) else { return nil }
      var lens: [Int] = []
      while lens.count < nlen + ndist {
        let sym = decode(h)
        guard sym >= 0 else { return nil }
        if sym < 16 {
          lens.append(sym)
        } else if sym == 16 {
          guard let last = lens.last else { return nil }
          lens.append(contentsOf: Array(repeating: last, count: bits(2) + 3))
        } else if sym == 17 {
          lens.append(contentsOf: Array(repeating: 0, count: bits(3) + 3))
        } else if sym == 18 {
          lens.append(contentsOf: Array(repeating: 0, count: bits(7) + 11))
        } else {
          return nil
        }
      }
      guard lens.count == nlen + ndist else { return nil }
      guard let lencode = construct(Array(lens[0..<nlen]), nlen) else { return nil }
      guard let distcode = construct(Array(lens[nlen...]), ndist) else { return nil }
      return (lencode, distcode)
    }
  }
}
