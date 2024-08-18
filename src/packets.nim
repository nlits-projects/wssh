import flatty, utils

type
  PacketKind* = enum pkInit, pkClose, pkRun, pkByteUpdate, pkFinish, pkConfirmAction, pkInput
  Packet* = object 
    processID: int32 = -1
    command: string
    done: bool
    case kind: PacketKind
    of pkInit: # Communicates server settings and states to the client. Sent once after connection. Type: Data
      mode: WsshMode
    of pkConfirmAction:
      action: PacketKind # Confirms that an action was processed. Must be sent in response before new ones will be sent out.
    of pkByteUpdate:
      isErr: bool # Sends updated bytes from stream. See asyncHandleProcess
      bytes: string
    of pkFinish:
      code: int # Send when process finished
    of pkInput:
      input: string # Write to STDIN
    else:
      discard

# Packet constructors

proc newInitPacket*(mode: WsshMode): Packet =
  # Process is unused
  result = Packet(kind: pkInit, mode: mode)


# Packet convertors

template renderBin*(p: Packet): string = toFlatty(p)

template fromBin*(s: string): Packet = fromFlatty(s, Packet)