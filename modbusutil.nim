import std/[strutils,parseutils,math,algorithm,sequtils]
import macros

type 
    mb_function* {.pure.}  = enum 
        r_discret_inputs = 2'u8, #Read Discrete Inputs
        r_coils = 1'u8, #Read Coils
        w_single_coil = 5'u8 #Write Single Coil
        w_mult_coils = 15'u8 #Write Multiple Coils
        r_input_regs = 4'u8 #Read Input Registers
        r_mult_holding_regs = 3'u8 #Read Multiple Holding Registers
        w_single_holding_reg = 6'u8 #Write Single Holding Register
        w_mult_holding_regs = 16'u8 #Write Multiple Holding Registers
        r_w_mult_holding_regs =23'u8 #Read/Write Multiple Registers
        w_mask_regs = 22'u8 #Read/Write Multiple Registers

# tranform uint8 to char
proc cast_c*(ch:uint8):char =
    return cast[char](ch)

# count how many bytes need to pack bits
proc bytes_cnt*(bits_num:uint16):int =
  if (int(bits_num) mod 8) > 0:
    result = (int(bits_num) div 8) + 1
  else:
    result = int(bits_num) div 8
  return result

# transform uint16 or uint32 to sequence of chars
proc cast_u16*(ch:uint16|uint32):seq[char] = 
    return ch.toHex().parseHexStr().toSeq()

#macro to debug view
macro debug*(n: varargs[typed]): untyped =
  result = newNimNode(nnkStmtList, n)
  for i in 0..n.len-1:
    if n[i].kind == nnkStrLit:
      # pure string literals are written directly
      result.add(newCall("write", newIdentNode("stdout"), n[i]))
    else:
      # other expressions are written in <expression>: <value> syntax
      result.add(newCall("write", newIdentNode("stdout"), toStrLit(n[i])))
      result.add(newCall("write", newIdentNode("stdout"), newStrLitNode(": ")))
      result.add(newCall("write", newIdentNode("stdout"), n[i]))
    if i != n.len-1:
      # separate by ", "
      result.add(newCall("write", newIdentNode("stdout"), newStrLitNode(", ")))
    else:
      # add newline
      result.add(newCall("writeLine", newIdentNode("stdout"), newStrLitNode("")))
  
  
# coeff table for modbus rtu calculation
const crc16Table : array[0..255, uint16] = [0X0000, 0XC0C1, 0XC181, 0X0140, 0XC301, 0X03C0, 0X0280, 0XC241,
0XC601, 0X06C0, 0X0780, 0XC741, 0X0500, 0XC5C1, 0XC481, 0X0440,
0XCC01, 0X0CC0, 0X0D80, 0XCD41, 0X0F00, 0XCFC1, 0XCE81, 0X0E40,
0X0A00, 0XCAC1, 0XCB81, 0X0B40, 0XC901, 0X09C0, 0X0880, 0XC841,
0XD801, 0X18C0, 0X1980, 0XD941, 0X1B00, 0XDBC1, 0XDA81, 0X1A40,
0X1E00, 0XDEC1, 0XDF81, 0X1F40, 0XDD01, 0X1DC0, 0X1C80, 0XDC41,
0X1400, 0XD4C1, 0XD581, 0X1540, 0XD701, 0X17C0, 0X1680, 0XD641,
0XD201, 0X12C0, 0X1380, 0XD341, 0X1100, 0XD1C1, 0XD081, 0X1040,
0XF001, 0X30C0, 0X3180, 0XF141, 0X3300, 0XF3C1, 0XF281, 0X3240,
0X3600, 0XF6C1, 0XF781, 0X3740, 0XF501, 0X35C0, 0X3480, 0XF441,
0X3C00, 0XFCC1, 0XFD81, 0X3D40, 0XFF01, 0X3FC0, 0X3E80, 0XFE41,
0XFA01, 0X3AC0, 0X3B80, 0XFB41, 0X3900, 0XF9C1, 0XF881, 0X3840,
0X2800, 0XE8C1, 0XE981, 0X2940, 0XEB01, 0X2BC0, 0X2A80, 0XEA41,
0XEE01, 0X2EC0, 0X2F80, 0XEF41, 0X2D00, 0XEDC1, 0XEC81, 0X2C40,
0XE401, 0X24C0, 0X2580, 0XE541, 0X2700, 0XE7C1, 0XE681, 0X2640,
0X2200, 0XE2C1, 0XE381, 0X2340, 0XE101, 0X21C0, 0X2080, 0XE041,
0XA001, 0X60C0, 0X6180, 0XA141, 0X6300, 0XA3C1, 0XA281, 0X6240,
0X6600, 0XA6C1, 0XA781, 0X6740, 0XA501, 0X65C0, 0X6480, 0XA441,
0X6C00, 0XACC1, 0XAD81, 0X6D40, 0XAF01, 0X6FC0, 0X6E80, 0XAE41,
0XAA01, 0X6AC0, 0X6B80, 0XAB41, 0X6900, 0XA9C1, 0XA881, 0X6840,
0X7800, 0XB8C1, 0XB981, 0X7940, 0XBB01, 0X7BC0, 0X7A80, 0XBA41,
0XBE01, 0X7EC0, 0X7F80, 0XBF41, 0X7D00, 0XBDC1, 0XBC81, 0X7C40,
0XB401, 0X74C0, 0X7580, 0XB541, 0X7700, 0XB7C1, 0XB681, 0X7640,
0X7200, 0XB2C1, 0XB381, 0X7340, 0XB101, 0X71C0, 0X7080, 0XB041,
0X5000, 0X90C1, 0X9181, 0X5140, 0X9301, 0X53C0, 0X5280, 0X9241,
0X9601, 0X56C0, 0X5780, 0X9741, 0X5500, 0X95C1, 0X9481, 0X5440,
0X9C01, 0X5CC0, 0X5D80, 0X9D41, 0X5F00, 0X9FC1, 0X9E81, 0X5E40,
0X5A00, 0X9AC1, 0X9B81, 0X5B40, 0X9901, 0X59C0, 0X5880, 0X9841,
0X8801, 0X48C0, 0X4980, 0X8941, 0X4B00, 0X8BC1, 0X8A81, 0X4A40,
0X4E00, 0X8EC1, 0X8F81, 0X4F40, 0X8D01, 0X4DC0, 0X4C80, 0X8C41,
0X4400, 0X84C1, 0X8581, 0X4540, 0X8701, 0X47C0, 0X4680, 0X8641,
0X8201, 0X42C0, 0X4380, 0X8341, 0X4100, 0X81C1, 0X8081, 0X4040]

#calculate CRC16 for rtu modbus message
proc calc_CRC16*(buf: openArray[char|uint8]): uint16 =
  result = uint16(0xffff)
  for i in 0..buf.high:
    result = (result shr 8) xor crc16Table[(result xor uint8(buf[i])) and 0x00ff]

#transform uin16 crc16 to bytes
proc crc16_seq*(crc:uint16):seq[char] =
  var
    tmp = newSeq[char]()
  tmp = crc.toHex.parseHexStr.toSeq()
  return @[tmp[1],tmp[0]]

#create pdu for readable modbus functions
proc modbus_read_pdu*(fn:mb_function,reg_adr:uint16,quantity:uint16):seq[char] =
  var
    res = newSeq[char]()
  case fn
  of r_coils,r_discret_inputs,r_input_regs,r_mult_holding_regs:
    res.add(cast_c(uint8(fn.ord)))
  else:
    res.add("Bad ModBus function!".toSeq())
  res.add(cast_u16(reg_adr))
  res.add(cast_u16(quantity))
  return res

  #create pdu for writetable modbus functions
proc modbus_write_pdu*(fn:mb_function,reg_adr:uint16,quantity:uint16,write_data:seq[uint16]):seq[char] =
  var
    fnc:uint8
    res = newSeq[char]()
    num_bytes:uint16
    #n:uint16 = 0
    #m:uint16 = 1 
    num_words:uint16
    data_seq:seq[char]
  case fn
  of w_single_coil,w_single_holding_reg: #quantity no matter, value of coil is write_data[0] from data seq other data no matter
    fnc = 5 # A value of 0XFF00 requests the coil to be On. A value of 0X0000 requests the coil to be off.
    res.add(cast_c(uint8(fn.ord)))
    res.add(cast_u16(reg_adr))
    res.add(cast_u16(write_data[0]))
  of w_mult_coils: #quntity is number of coil which you need to write. Bits transfer in bytes. Unused bits you must fill by zero
    fnc = 15 #The more significant bits contain the higher coil variables.
    res.add(cast_c(fnc))
    res.add(cast_u16(reg_adr))
    res.add(cast_u16(quantity))
    num_bytes = uint16(ceilDiv(quantity,8))
    res.add(cast_u16(num_bytes)[1])
    num_words = uint16(ceilDiv(num_bytes,2))
    for i in write_data:
      if uint16(data_seq.len) <= num_bytes-1:
        data_seq.add(cast_u16(i)[0])
      else:
        break
      if uint16(data_seq.len) <= num_bytes-1:
        data_seq.add(cast_u16(i)[1])
      else:
        break
    res.add(data_seq)
  of w_mult_holding_regs:
    fnc = 16
    res.add(cast_c(fnc))
    res.add(cast_u16(reg_adr))
    res.add(cast_u16(quantity))
    num_bytes = quantity*2
    res.add(cast_u16(num_bytes)[1])
    for i in write_data[0 .. quantity-1]:
      data_seq.add(cast_u16(i))
    res.add(data_seq)
  of w_mask_regs: # Sense of write data is mask for holding register word[0] for 'and mask' and word[1] for 'or mask'
    fnc = 22
    res.add(cast_c(fnc))
    res.add(cast_u16(reg_adr))
    for i in write_data[0..1]:
      res.add(cast_u16(i))
  else:
    res.add("Bad ModBus function!".toSeq())
  return res

# pdu for 23 modbus function
proc read_write_pdu_f23* (r_adr:uint16,r_quantity:uint16,w_adr:uint16,w_quantity:uint16,write_data:seq[uint16]): seq[char] =
  var
    num_bytes:uint8
    res = newSeq[char]()
  res.add(cast_c(uint8(23)))
  res.add(cast_u16(r_adr))
  res.add(cast_u16(r_quantity))
  num_bytes = uint8(w_quantity)*2
  res.add(cast_u16(w_adr))
  res.add(cast_u16(w_quantity))
  res.add(cast_c(num_bytes))
  for i in write_data[0..w_quantity-1]:
    res.add(cast_u16(i))
  return res  


#transform seq of chars to 16bit regs
proc seq_of_chars_to_hold_regs*(rgs:seq[char]):seq[int16] = 
    var
        i:int = 0
        res = newSeq[int16]()
        temp_str:string
    while i < rgs.len:
        temp_str = (rgs[i]&rgs[i+1]).toHex()
        res.add(temp_str.fromHex[:int16])
        i = i + 2
    return res

#transfor seq of chars to 32floats, float pattern is correct seq of bytes to compile float like [2,3,0,1] or [0,1,2,3] or etc
proc seq_of_chars_to_floats*(rgs:seq[char],float_pattern:array[0..3,int]):seq[float] =
  var
    i:int = 0
    res = newSeq[float]()
    temp_str:string  
  while i < rgs.len:
    temp_str = (rgs[i+float_pattern[0]]&rgs[i+float_pattern[1]]&rgs[i+float_pattern[2]]&rgs[i+float_pattern[3]]).toHex()
    res.add(cast[float32](temp_str.fromHex[:uint32]))
    i = i + 4
  return res

#tranform floats32 to seq of chars
proc seq_of_float_to_seq_of_chars*(flts:seq[float32],float_pattern:array[0..3,int]):seq[char] =
  var
    res = newSeq[char]()
    temp_i:uint32
    tmp_seq = newSeq[char]()
  for f in flts:
    temp_i = cast[uint32](f)
    tmp_seq.add(cast_u16(temp_i))
    res.add(tmp_seq[0])
    res.add(tmp_seq[1])
    res.add(tmp_seq[2])
    res.add(tmp_seq[3])
    tmp_seq.setLen(0)
  return res

# bits from bytes to seq of bools
proc bytes_to_seq_of_bools*(bts:seq[char],quantity:int):seq[bool] = 
  var
    res = newSeq[bool]()
    temp:string
  for i in bts:
    temp=int(i).toBin(8)
    for n in countdown(7,0):
      if temp[n] == '1':
        res.add(true)
      else:
        res.add(false)
  res = res[0..quantity-1]
  return res


#packing seq of bools to bytes
proc bools_pack_to_bytes*(bls:seq[bool]):seq[char] = 
  var
    res = newSeq[char]()
    bls_len:int
    i:int = 0
    j:int = 0
    temp_str:string
    tmp:int
    parsed:uint8
  bls_len = bls.len
  while i < bls_len:
    if j <= 7:
      if bls[i] == true:
        temp_str = temp_str & "1"
      else:
        temp_str = temp_str & "0"
      j = j + 1
    else:
      temp_str.reverse()
      tmp = parseBin(temp_str,parsed)
      res.add(cast_c(parsed))
      temp_str = ""
      j = 0
      i = i - 1
    i = i + 1
    if i == bls_len and j < 7:
      for n in (j..7):
        temp_str = temp_str & "0"
      temp_str.reverse()
      tmp = parseBin(temp_str,parsed)
      res.add(cast_c(parsed))
      temp_str = ""
  return res