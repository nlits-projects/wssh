import backend/packets
import std/base64

while true:
  echo "Enter base64 packet: "
  let inp = readLine(stdin)

  if inp == ":q":
    break

  let p = fromBin(decode(inp))
  echo $p