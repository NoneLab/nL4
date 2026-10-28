# SPDX-License-Identifier: BSD-2-Clause
# Reassemble MKASMSYM values from GNU nm -S --radix=d output.
# nm's column 2 is symbol size, encoded as 1 + 32 * value bytes.
# Output names are a constant subset; the algorithm is independent of order.
NF >= 4 {
    name = $NF
    if (name ~ /_sign$/) {
        key=name; sub(/_sign$/, "", key)
        signs[key] = (($2 - 1) / 32 == 1) ? -1 : 1
        seen[key]=1
    } else if (name ~ /_b[0-7]$/) {
        key=name; sub(/_b[0-7]$/, "", key)
        digit=name; sub(/^.*_b/, "", digit)
        byte=($2 - 1) / 32
        if (byte < 0 || byte > 255 || int(byte) != byte) {
            print "Invalid byte in symbol: "name > "/dev/stderr"; exit 1
        }
        bytes[key, digit] = byte
        seen[key]=1
    }
}
END {
    for (key in seen) {
        # Emit the original width as two 32-bit halves to avoid awk's
        # floating point integer precision limitations for 64-bit constants.
        lo=bytes[key,0]+256*bytes[key,1]+65536*bytes[key,2]+16777216*bytes[key,3]
        hi=bytes[key,4]+256*bytes[key,5]+65536*bytes[key,6]+16777216*bytes[key,7]
        printf "#define %-30s %s(0x%08x%08x)\n",key,(signs[key]<0?"-":""),hi,lo
    }
}
