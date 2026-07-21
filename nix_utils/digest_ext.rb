# digest_ext.rb — pure-Ruby Digest::MD5, Digest::SHA224, Digest::SHA384, Digest::SHA512
# Spinel's bundled digest only covers SHA1 and SHA256; this file opens the
# Digest module to add the remaining algorithms used by the *sum utilities.
# Pure Ruby so it runs under both CRuby and Spinel.
#
# SHA384 / SHA512: 64-bit words are represented as (H, L) pairs of 32-bit
# integers to stay within Spinel's int64_t range. All (H, L) values are in
# [0, 2^32-1] and never overflow int64_t.

module Digest
  DEXT_HEX  = "0123456789abcdef"
  DEXT_M32  = 0xFFFFFFFF

  # ---------- MD5 (RFC 1321) — 32-bit arithmetic ----------

  module MD5
    MD5_T = [
      0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
      0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
      0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
      0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
      0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
      0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
      0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
      0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
      0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
      0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
      0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
      0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
      0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
      0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
      0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
      0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
    ]
    MD5_S = [
       7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,
       5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,
       4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,
       6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21
    ]

    def self.hexdigest(msg)
      s = "" + msg
      orig_len = s.length
      mask = DEXT_M32

      bytes = [0]
      bi = 0
      while bi < orig_len
        bytes.push(s[bi].ord)
        bi += 1
      end
      bytes.push(0x80)
      while (bytes.length - 1) % 64 != 56
        bytes.push(0)
      end
      bit_len = orig_len * 8
      lbi = 0
      while lbi < 8
        bytes.push((bit_len >> (lbi * 8)) & 0xff)
        lbi += 1
      end

      a0 = 0x67452301; b0 = 0xefcdab89
      c0 = 0x98badcfe; d0 = 0x10325476

      num_blocks = (bytes.length - 1) / 64
      blk = 0
      while blk < num_blocks
        base = 1 + blk * 64
        m = [0]
        wi = 0
        while wi < 16
          off = base + wi * 4
          m.push(bytes[off] | (bytes[off+1] << 8) | (bytes[off+2] << 16) | (bytes[off+3] << 24))
          wi += 1
        end

        aa = a0; bb = b0; cc = c0; dd = d0
        ii = 0
        while ii < 64
          f = 0; g = 0
          if ii < 16
            f = ((bb & cc) | ((~bb) & dd)) & mask
            g = ii
          elsif ii < 32
            f = ((dd & bb) | ((~dd) & cc)) & mask
            g = (5 * ii + 1) % 16
          elsif ii < 48
            f = (bb ^ cc ^ dd) & mask
            g = (3 * ii + 5) % 16
          else
            f = (cc ^ (bb | (~dd))) & mask
            g = (7 * ii) % 16
          end
          temp = dd; dd = cc; cc = bb
          sv = MD5_S[ii]
          sum = (aa + f + MD5_T[ii] + m[g + 1]) & mask
          bb = (bb + (((sum << sv) | (sum >> (32 - sv))) & mask)) & mask
          aa = temp
          ii += 1
        end

        a0 = (a0 + aa) & mask; b0 = (b0 + bb) & mask
        c0 = (c0 + cc) & mask; d0 = (d0 + dd) & mask
        blk += 1
      end

      hx = DEXT_HEX
      hex = ""
      oi = 0
      while oi < 4
        w = 0
        if oi == 0; w = a0
        elsif oi == 1; w = b0
        elsif oi == 2; w = c0
        else; w = d0
        end
        bj = 0
        while bj < 4
          bv = (w >> (bj * 8)) & 0xff
          hex += hx[(bv >> 4) & 0xf]
          hex += hx[bv & 0xf]
          bj += 1
        end
        oi += 1
      end
      hex
    end
  end

  # ---------- SHA-224 / SHA-256 shared compression (32-bit) ----------

  SHA256_K = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ]

  def self.sha256_block(h, bytes, base)
    mask = DEXT_M32
    w = [0]
    wi = 0
    while wi < 16
      off = base + wi * 4
      w.push(((bytes[off] << 24) | (bytes[off+1] << 16) | (bytes[off+2] << 8) | bytes[off+3]) & mask)
      wi += 1
    end
    while wi < 64
      w0 = w[wi - 15 + 1]; w1 = w[wi - 2 + 1]
      s0 = (((w0 >> 7) | (w0 << 25)) ^ ((w0 >> 18) | (w0 << 14)) ^ (w0 >> 3)) & mask
      s1 = (((w1 >> 17) | (w1 << 15)) ^ ((w1 >> 19) | (w1 << 13)) ^ (w1 >> 10)) & mask
      w.push((w[wi - 16 + 1] + s0 + w[wi - 7 + 1] + s1) & mask)
      wi += 1
    end

    a = h[0]; b = h[1]; c = h[2]; d = h[3]
    e = h[4]; f = h[5]; g = h[6]; hh = h[7]

    ri = 0
    while ri < 64
      s1  = (((e >> 6) | (e << 26)) ^ ((e >> 11) | (e << 21)) ^ ((e >> 25) | (e << 7))) & mask
      ch  = ((e & f) ^ ((~e) & g)) & mask
      t1  = (hh + s1 + ch + SHA256_K[ri] + w[ri + 1]) & mask
      s0  = (((a >> 2) | (a << 30)) ^ ((a >> 13) | (a << 19)) ^ ((a >> 22) | (a << 10))) & mask
      maj = ((a & b) ^ (a & c) ^ (b & c)) & mask
      t2  = (s0 + maj) & mask
      hh = g; g = f; f = e
      e = (d + t1) & mask
      d = c; c = b; b = a
      a = (t1 + t2) & mask
      ri += 1
    end

    h[0] = (h[0] + a) & mask; h[1] = (h[1] + b) & mask
    h[2] = (h[2] + c) & mask; h[3] = (h[3] + d) & mask
    h[4] = (h[4] + e) & mask; h[5] = (h[5] + f) & mask
    h[6] = (h[6] + g) & mask; h[7] = (h[7] + hh) & mask
  end

  def self.sha256_pad_and_run(msg, h)
    s = "" + msg
    orig_len = s.length

    bytes = [0]
    bi = 0
    while bi < orig_len
      bytes.push(s[bi].ord)
      bi += 1
    end
    bytes.push(0x80)
    while (bytes.length - 1) % 64 != 56
      bytes.push(0)
    end
    bit_len = orig_len * 8
    lbi = 7
    while lbi >= 0
      bytes.push((bit_len >> (lbi * 8)) & 0xff)
      lbi -= 1
    end

    num_blocks = (bytes.length - 1) / 64
    blk = 0
    while blk < num_blocks
      sha256_block(h, bytes, 1 + blk * 64)
      blk += 1
    end
  end

  module SHA224
    SHA224_IVH = [0xc1059ed8, 0x367cd507, 0x3070dd17, 0xf70e5939,
                  0xffc00b31, 0x68581511, 0x64f98fa7, 0xbefa4fa4]

    def self.hexdigest(msg)
      h = [SHA224_IVH[0], SHA224_IVH[1], SHA224_IVH[2], SHA224_IVH[3],
           SHA224_IVH[4], SHA224_IVH[5], SHA224_IVH[6], SHA224_IVH[7]]
      Digest.sha256_pad_and_run(msg, h)
      hx = DEXT_HEX
      hex = ""
      hi = 0
      while hi < 7
        w = h[hi]
        bj = 3
        while bj >= 0
          bv = (w >> (bj * 8)) & 0xff
          hex += hx[(bv >> 4) & 0xf]
          hex += hx[bv & 0xf]
          bj -= 1
        end
        hi += 1
      end
      hex
    end
  end

  # ---------- SHA-512 / SHA-384 — (H, L) 32-bit pair representation ----------
  # Each 64-bit word is stored as two int32 values so all arithmetic stays
  # within Spinel's int64_t range. Sentinel at index 0 for IntArray typing.

  # KH[i] = SHA512_K[i] >> 32, KL[i] = SHA512_K[i] & 0xFFFFFFFF
  SHA512_KH = [
    1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221,
    3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580,
    3835390401, 4022224774, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986,
    2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711, 113926993, 338241895,
    666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, 2177026350, 2456956037,
    2730485921, 2820302411, 3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344,
    430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779,
    1955562222, 2024104815, 2227730452, 2361852424, 2428436474, 2756734187, 3204031479, 3329325298,
    3391569614, 3515267271, 3940187606, 4118630271, 116418474, 174292421, 289380356, 460393269,
    685471733, 852142971, 1017036298, 1126000580, 1288033470, 1501505948, 1607167915, 1816402316
  ]
  SHA512_KL = [
    0xd728ae22, 0x23ef65cd, 0xec4d3b2f, 0x8189dbbc, 0xf348b538, 0xb605d019, 0xaf194f9b, 0xda6d8118,
    0xa3030242, 0x45706fbe, 0x4ee4b28c, 0xd5ffb4e2, 0xf27b896f, 0x3b1696b1, 0x25c71235, 0xcf692694,
    0x9ef14ad2, 0x384f25e3, 0x8b8cd5b5, 0x77ac9c65, 0x592b0275, 0x6ea6e483, 0xbd41fbd4, 0x831153b5,
    0xee66dfab, 0x2db43210, 0x98fb213f, 0xbeef0ee4, 0x3da88fc2, 0x930aa725, 0xe003826f, 0x0a0e6e70,
    0x46d22ffc, 0x5c26c926, 0x5ac42aed, 0x9d95b3df, 0x8baf63de, 0x3c77b2a8, 0x47edaee6, 0x1482353b,
    0x4cf10364, 0xbc423001, 0xd0f89791, 0x0654be30, 0xd6ef5218, 0x5565a910, 0x5771202a, 0x32bbd1b8,
    0xb8d2d0c8, 0x5141ab53, 0xdf8eeb99, 0xe19b48a8, 0xc5c95a63, 0xe3418acb, 0x7763e373, 0xd6b2b8a3,
    0x5defb2fc, 0x43172f60, 0xa1f0ab72, 0x1a6439ec, 0x23631e28, 0xde82bde9, 0xb2c67915, 0xe372532b,
    0xea26619c, 0x21c0c207, 0xcde0eb1e, 0xee6ed178, 0x72176fba, 0xa2c898a6, 0xbef90dae, 0x131c471b,
    0x23047d84, 0x40c72493, 0x15c9bebc, 0x9c100d4c, 0xcb3e42b6, 0xfc657e2a, 0x3ad6faec, 0x4a475817
  ]

  # ROTR64(xH, xL, n) — high 32 bits of result
  def self.sp_rh(xh, xl, n)
    m = DEXT_M32
    if n < 32
      ((xh >> n) | (xl << (32 - n))) & m
    else
      q = n - 32
      ((xl >> q) | (xh << (32 - q))) & m
    end
  end

  # ROTR64(xH, xL, n) — low 32 bits of result
  def self.sp_rl(xh, xl, n)
    m = DEXT_M32
    if n < 32
      ((xl >> n) | (xh << (32 - n))) & m
    else
      q = n - 32
      ((xh >> q) | (xl << (32 - q))) & m
    end
  end

  # SHR64(xH, xL, n) — logical right shift, high 32 bits
  def self.sp_sh(xh, xl, n)
    n < 32 ? (xh >> n) : 0
  end

  # SHR64(xH, xL, n) — logical right shift, low 32 bits
  def self.sp_sl(xh, xl, n)
    m = DEXT_M32
    n < 32 ? (((xl >> n) | (xh << (32 - n))) & m) : (xh >> (n - 32))
  end

  # ADD64 high word (ah,al) + (bh,bl)
  def self.sp_ah(ah, al, bh, bl)
    (ah + bh + ((al + bl) >> 32)) & DEXT_M32
  end

  # ADD64 low word
  def self.sp_al(ah, al, bh, bl)
    (al + bl) & DEXT_M32
  end

  def self.sha512_block(hH, hL, bytes, base)
    m = DEXT_M32
    kh = SHA512_KH; kl = SHA512_KL

    # Load 16 message words as (H, L) pairs; sentinel at index 0
    wH = [0]; wL = [0]
    wi = 0
    while wi < 16
      off = base + wi * 8
      wh = bytes[off].to_i * 16777216 + bytes[off+1].to_i * 65536 + bytes[off+2].to_i * 256 + bytes[off+3].to_i
      wl = bytes[off+4].to_i * 16777216 + bytes[off+5].to_i * 65536 + bytes[off+6].to_i * 256 + bytes[off+7].to_i
      wH.push(wh); wL.push(wl)
      wi += 1
    end

    # Message schedule expansion (80 words)
    while wi < 80
      # sigma0: ROTR(w[i-15], 1) ^ ROTR(w[i-15], 8) ^ SHR(w[i-15], 7)
      p = wi - 15 + 1; q = wi - 2 + 1
      ph = wH[p]; pl = wL[p]
      s0h = (sp_rh(ph, pl, 1) ^ sp_rh(ph, pl, 8) ^ sp_sh(ph, pl, 7)) & m
      s0l = (sp_rl(ph, pl, 1) ^ sp_rl(ph, pl, 8) ^ sp_sl(ph, pl, 7)) & m
      # sigma1: ROTR(w[i-2], 19) ^ ROTR(w[i-2], 61) ^ SHR(w[i-2], 6)
      qh = wH[q]; ql = wL[q]
      s1h = (sp_rh(qh, ql, 19) ^ sp_rh(qh, ql, 61) ^ sp_sh(qh, ql, 6)) & m
      s1l = (sp_rl(qh, ql, 19) ^ sp_rl(qh, ql, 61) ^ sp_sl(qh, ql, 6)) & m
      # w[i] = w[i-16] + s0 + w[i-7] + s1
      r = wi - 16 + 1; s = wi - 7 + 1
      t0l = (wL[r] + s0l) & m; t0h = (wH[r] + s0h + ((wL[r] + s0l) >> 32)) & m
      t1l = (wL[s] + s1l) & m; t1h = (wH[s] + s1h + ((wL[s] + s1l) >> 32)) & m
      nwl = (t0l + t1l) & m; nwh = (t0h + t1h + ((t0l + t1l) >> 32)) & m
      wH.push(nwh); wL.push(nwl)
      wi += 1
    end

    # Working variables
    aH = hH[0]; aL = hL[0]; bH = hH[1]; bL = hL[1]
    cH = hH[2]; cL = hL[2]; dH = hH[3]; dL = hL[3]
    eH = hH[4]; eL = hL[4]; fH = hH[5]; fL = hL[5]
    gH = hH[6]; gL = hL[6]; hhH = hH[7]; hhL = hL[7]

    ri = 0
    while ri < 80
      # SIGMA1(e): ROTR(e,14) ^ ROTR(e,18) ^ ROTR(e,41)
      s1h = (sp_rh(eH, eL, 14) ^ sp_rh(eH, eL, 18) ^ sp_rh(eH, eL, 41)) & m
      s1l = (sp_rl(eH, eL, 14) ^ sp_rl(eH, eL, 18) ^ sp_rl(eH, eL, 41)) & m
      # Ch(e,f,g): (e&f) ^ (~e & g)
      chH = ((eH & fH) ^ ((~eH) & gH)) & m
      chL = ((eL & fL) ^ ((~eL) & gL)) & m
      # t1 = hh + S1 + Ch + K[ri] + w[ri]
      # Chain: t1 = ((hh + s1) + ch) + k + w  — four 64-bit adds
      u0l = (hhL + s1l) & m; u0h = (hhH + s1h + ((hhL + s1l) >> 32)) & m
      u1l = (u0l + chL) & m; u1h = (u0h + chH + ((u0l + chL) >> 32)) & m
      u2l = (u1l + kl[ri]) & m; u2h = (u1h + kh[ri] + ((u1l + kl[ri]) >> 32)) & m
      t1l = (u2l + wL[ri + 1]) & m; t1h = (u2h + wH[ri + 1] + ((u2l + wL[ri + 1]) >> 32)) & m
      # SIGMA0(a): ROTR(a,28) ^ ROTR(a,34) ^ ROTR(a,39)
      s0h = (sp_rh(aH, aL, 28) ^ sp_rh(aH, aL, 34) ^ sp_rh(aH, aL, 39)) & m
      s0l = (sp_rl(aH, aL, 28) ^ sp_rl(aH, aL, 34) ^ sp_rl(aH, aL, 39)) & m
      # Maj(a,b,c): (a&b) ^ (a&c) ^ (b&c)
      mjH = ((aH & bH) ^ (aH & cH) ^ (bH & cH)) & m
      mjL = ((aL & bL) ^ (aL & cL) ^ (bL & cL)) & m
      # t2 = S0 + Maj
      t2l = (s0l + mjL) & m; t2h = (s0h + mjH + ((s0l + mjL) >> 32)) & m

      # Rotate state
      hhH = gH; hhL = gL
      gH = fH; gL = fL
      fH = eH; fL = eL
      eH = (dH + t1h + ((dL + t1l) >> 32)) & m; eL = (dL + t1l) & m
      dH = cH; dL = cL
      cH = bH; cL = bL
      bH = aH; bL = aL
      aH = (t1h + t2h + ((t1l + t2l) >> 32)) & m; aL = (t1l + t2l) & m
      ri += 1
    end

    hH[0] = (hH[0] + aH + ((hL[0] + aL) >> 32)) & m; hL[0] = (hL[0] + aL) & m
    hH[1] = (hH[1] + bH + ((hL[1] + bL) >> 32)) & m; hL[1] = (hL[1] + bL) & m
    hH[2] = (hH[2] + cH + ((hL[2] + cL) >> 32)) & m; hL[2] = (hL[2] + cL) & m
    hH[3] = (hH[3] + dH + ((hL[3] + dL) >> 32)) & m; hL[3] = (hL[3] + dL) & m
    hH[4] = (hH[4] + eH + ((hL[4] + eL) >> 32)) & m; hL[4] = (hL[4] + eL) & m
    hH[5] = (hH[5] + fH + ((hL[5] + fL) >> 32)) & m; hL[5] = (hL[5] + fL) & m
    hH[6] = (hH[6] + gH + ((hL[6] + gL) >> 32)) & m; hL[6] = (hL[6] + gL) & m
    hH[7] = (hH[7] + hhH + ((hL[7] + hhL) >> 32)) & m; hL[7] = (hL[7] + hhL) & m
  end

  def self.sha512_pad_and_run(msg, hH, hL)
    s = "" + msg
    orig_len = s.length

    bytes = [0]
    bi = 0
    while bi < orig_len
      bytes.push(s[bi].ord)
      bi += 1
    end
    bytes.push(0x80)
    while (bytes.length - 1) % 128 != 112
      bytes.push(0)
    end
    # Append 128-bit big-endian length (high 64 bits always 0 for our inputs)
    lbi = 15
    while lbi >= 8
      bytes.push(0)
      lbi -= 1
    end
    bit_len = orig_len * 8
    lbi = 7
    while lbi >= 0
      bytes.push((bit_len >> (lbi * 8)) & 0xff)
      lbi -= 1
    end

    num_blocks = (bytes.length - 1) / 128
    blk = 0
    while blk < num_blocks
      sha512_block(hH, hL, bytes, 1 + blk * 128)
      blk += 1
    end
  end

  def self.sha512_hex_words(hH, hL, nwords)
    hx = DEXT_HEX
    hex = ""
    hi = 0
    while hi < nwords
      wh = hH[hi]; wl = hL[hi]
      bj = 3
      while bj >= 0
        bv = (wh >> (bj * 8)) & 0xff
        hex += hx[(bv >> 4) & 0xf]
        hex += hx[bv & 0xf]
        bj -= 1
      end
      bj = 3
      while bj >= 0
        bv = (wl >> (bj * 8)) & 0xff
        hex += hx[(bv >> 4) & 0xf]
        hex += hx[bv & 0xf]
        bj -= 1
      end
      hi += 1
    end
    hex
  end

  module SHA512
    # IVs as (H, L) pairs — all values fit in int32
    SHA512_IVH = [1779033703, 3144134277, 1013904242, 2773480762,
                  1359893119, 2600822924, 528734635, 1541459225]
    SHA512_IVL = [0xf3bcc908, 0x84caa73b, 0xfe94f82b, 0x5f1d36f1,
                  0xade682d1, 0x2b3e6c1f, 0xfb41bd6b, 0x137e2179]

    def self.hexdigest(msg)
      hH = [SHA512_IVH[0], SHA512_IVH[1], SHA512_IVH[2], SHA512_IVH[3],
            SHA512_IVH[4], SHA512_IVH[5], SHA512_IVH[6], SHA512_IVH[7]]
      hL = [SHA512_IVL[0], SHA512_IVL[1], SHA512_IVL[2], SHA512_IVL[3],
            SHA512_IVL[4], SHA512_IVL[5], SHA512_IVL[6], SHA512_IVL[7]]
      Digest.sha512_pad_and_run(msg, hH, hL)
      Digest.sha512_hex_words(hH, hL, 8)
    end
  end

  module SHA384
    SHA384_IVH = [3418070365, 1654270250, 2438529370, 355462360,
                  1731405415, 2394180231, 3675008525, 1203062813]
    SHA384_IVL = [0xc1059ed8, 0x367cd507, 0x3070dd17, 0xf70e5939,
                  0xffc00b31, 0x68581511, 0x64f98fa7, 0xbefa4fa4]

    def self.hexdigest(msg)
      hH = [SHA384_IVH[0], SHA384_IVH[1], SHA384_IVH[2], SHA384_IVH[3],
            SHA384_IVH[4], SHA384_IVH[5], SHA384_IVH[6], SHA384_IVH[7]]
      hL = [SHA384_IVL[0], SHA384_IVL[1], SHA384_IVL[2], SHA384_IVL[3],
            SHA384_IVL[4], SHA384_IVL[5], SHA384_IVL[6], SHA384_IVL[7]]
      Digest.sha512_pad_and_run(msg, hH, hL)
      Digest.sha512_hex_words(hH, hL, 6)
    end
  end
end
