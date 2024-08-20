import flatty, utils

type
  PacketKind* = enum pkInit, pkClose, pkRun, pkByteUpdate, pkFinish, pkConfirmAction, pkInput
  Packet* = object 
    processID*: int32 = -1 # -1 = No current process / irrelevant
    command*: string
    # done: bool Deemed unesscary with the pkFinish packet
    case kind*: PacketKind
    of pkInit: # Communicates server settings and states to the client. Sent once after connection. Type: Data
      mode*: WsshMode
    of pkConfirmAction:
      action*: PacketKind # Confirms that an action was processed. Must be sent in response before new ones will be sent out.
    of pkByteUpdate:
      isErr*: bool # Sends updated bytes from stream. See asyncHandleProcess
      bytes*: string
    of pkFinish:
      code*: int # Send when process finished
    of pkInput:
      input*: string # Write to STDIN
    else: # Close: CTRL-C. Stop the given process. Run: Run the given command.
      discard

# Packet constructors

proc newFinishPacket*(code: int, id = -1, command = ""): Packet =
  result = Packet(kind: pkFinish, code: code, processID: id.int32, command: command)

proc newByteUpdatePacket*(bytes: string, isErr: bool, id = -1, command = ""): Packet =
  result = Packet(kind: pkByteUpdate, bytes: bytes, isErr: isErr, processID: id.int32, command: command)

proc newConfirmActionPacket*(action: PacketKind, id = -1, command = ""): Packet =
  result = Packet(kind: pkConfirmAction, action: action, processID: id.int32, command: command)

proc newInitPacket*(mode: WsshMode): Packet =
  # Process is unused
  result = Packet(kind: pkInit, mode: mode)


# Packet convertors

template renderBin*(p: Packet): string = toFlatty(p)

template fromBin*(s: string): Packet = fromFlatty(s, Packet)