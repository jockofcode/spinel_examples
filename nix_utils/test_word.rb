MASK64 = 0xFFFFFFFFFFFFFFFF
bytes = [0, 0xbb, 0x67, 0xae, 0x85, 0x84, 0xca, 0xa7, 0x3b]
off = 1
# Force BigInt by multiplying int by BigInt multipliers
B7 = 0x100000000000000
B6 = 0x1000000000000
B5 = 0x10000000000
B4 = 0x100000000
word = bytes[off].to_i * B7 + bytes[off+1].to_i * B6 +
       bytes[off+2].to_i * B5 + bytes[off+3].to_i * B4 +
       bytes[off+4].to_i * 0x1000000 + bytes[off+5].to_i * 0x10000 +
       bytes[off+6].to_i * 0x100 + bytes[off+7].to_i
word = word & MASK64
puts "" + word.to_s
