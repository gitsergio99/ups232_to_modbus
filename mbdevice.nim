import std/[tables,sequtils,strutils,bitops,asyncnet, asyncdispatch,net,logging,times,strformat,marshal,streams,os]
import modbusutil
type
    ModBus_Device* = object
        device_name:string = "plc1"
        logging:bool = false
        modbus_adr:uint8 = 1
        auto_save_state:bool = false
        hregs* = initTable[int,seq[int16]]()
        iregs* = initTable[int,seq[int16]]()
        coils* = initTable[int,seq[bool]]()
        di* = initTable[int,seq[bool]]()
#init proc for Modbus device. For registers pattern is @[[0,10],[100,30],etc] where first number in array is start address of allowed reg
#second number of array is quantity 
proc initModBus_Device* (self: var ModBus_Device,name:string,log:bool,adr:uint8,save:bool,hr:seq[array[2,int]],ir:seq[array[2,int]],co:seq[array[2,int]],di:seq[array[2,int]]) =
    var
        hold = initTable[int,seq[int16]]()
        ireg = initTable[int,seq[int16]]()
        col = initTable[int,seq[bool]]()
        dis = initTable[int,seq[bool]]()
    self.auto_save_state = save
    self.device_name = name
    self.logging = log
    self.modbus_adr = adr
    for el in hr:
        hold.add(el[0],newSeq[int16](el[1]))
    for el in ir:
        ireg.add(el[0],newSeq[int16](el[1]))
    for el in co:
        col.add(el[0],newSeq[bool](el[1]))
    for el in di:
        dis.add(el[0],newSeq[bool](el[1]))
    self.hregs = hold
    self.iregs = ireg
    self.coils = col
    self.di = dis

template sets* [T] (regs:T,adr:int,val:untyped): untyped =
    var ret:bool = false
    for el in regs.pairs:
        if adr >= el[0] and (adr + val.len) <= (el[0] + el[1].len):
            for i in 0..val.len-1:
                regs[el[0]][(adr-el[0])+i] = val[i]
            ret = true
    ret

template  gets* [T] (regs:T,adr:int,qaunt:int, res:untyped): untyped =
    for el in regs.pairs:
        if adr >= el[0] and (adr + qaunt) <= (el[0] + el[1].len):
            res = regs[el[0]][(adr-el[0])..(adr-el[0])+qaunt-1]


# setter and getter of modbus device name
proc `device_name=`*(self: var ModBus_Device,name:string) =
    self.device_name = name

proc `device_name`*(self:ModBus_Device):string =
    self.device_name

proc save_state*(self:ModBus_Device) =
    var
        file_name:string = self.device_name&"_state.json"
        strm:FileStream = newFileStream(file_name,fmWrite)
    store(strm,self)
    strm.close()

proc load_state*(self: var ModBus_Device) =
    var
        file_name:string = self.device_name&"_state.json"
    if fileExists(file_name):
        let strm = newFileStream(file_name,fmRead)
        load(strm,self)
    
# setter and getter of modbus device address
proc `modbus_adr=`*(self: var ModBus_Device,adr:uint8) =
    self.modbus_adr = adr

proc `modbus_adr`*(self:ModBus_Device):uint8 =
    self.modbus_adr

# setter and getter logging, if true plc will be logging
proc `logging=`*(self: var ModBus_Device,lg:bool) =
    self.logging = lg

proc `logging`*(self:ModBus_Device):bool =
    self.logging

# setter and getter logging, if true plc will be logging
proc `auto_save_state=`*(self: var ModBus_Device,aus:bool) =
    self.auto_save_state = aus

proc `auto_save_state`*(self:ModBus_Device):bool =
    self.auto_save_state

# modbus error message for tcp transport
proc tcp_error_response(mbap:seq[char],adr:char,fn:char,err:char): string =
    var
        temp_resp:seq[char] = @[]
        res:string
    temp_resp.add(mbap)
    temp_resp.add('\x03')
    temp_resp.add(adr)
    temp_resp.add(cast_c(cast[uint8](fn)+128))
    temp_resp.add(err)
    apply(temp_resp,proc(it:char) = res.add(it))
    return res

# current time to string - file name of log
proc dt_to_name_file():string =
  let dt = now()
  let year = dt.year
  let mm = dt.month.ord
  let dd = dt.monthday
  let hh = dt.hour
  let mint = dt.minute
  let sec = dt.second
  result = intToStr(year)&'_'&intToStr(mm)&'_'&intToStr(dd)&'_'&intToStr(hh)&'_'&intToStr(mint)&'_'&intToStr(sec)&".log"

# two char to int
proc char_adr_to_int*(c1:char,c2:char): int =
    var
        temp_str:string =""
    temp_str.add(c1)
    temp_str.add(c2)
    #temp_str.toHex.fromHex[:uint16]
    return int(temp_str.toHex.fromHex[:uint16])

proc chars_val_to_int16*(ch:seq[char]): seq[int16] =
    var
        res:seq[int16] = @[]
        temp_str:string = ""
    for i in 0..int(ch.len/2-1):
        temp_str.add(ch[i*2])
        temp_str.add(ch[i*2+1])
        res.add(temp_str.toHex.fromHex[:int16])
        temp_str =""
    return res

# sequance of int16 to sequance of chars
proc seq_int16_to_seq_chr*(i:seq[int16]):seq[char] =
    var out_seq:seq[char] = @[]
    for x in i:
        out_seq.add(x.toHex.parseHexStr.toSeq())
    return out_seq



#if our device have tcp transport
proc response*(self: var ModBus_Device, ask_data:seq[char]): string =
    var
        supported_fn:array[0..9,char] = ['\x01','\x02','\x03','\x04','\x05','\x06','\x0F','\x10','\x16','\x17']
        mbap_strater:seq[char] = ask_data[0..4]
        tmp_adr:char = ask_data[6]
        tmp_fn:char = ask_data[7]
        outer_str:string
        outer_seq:seq[char] = @[]
        reg_adr:int = 0
        quan:int = 0
        regs_g:seq[int16]
        d_g:seq[bool]
    if tmp_adr == cast_c(self.modbus_adr):
        if tmp_fn in supported_fn:
            reg_adr = char_adr_to_int(ask_data[8],ask_data[9])
            quan = char_adr_to_int(ask_data[10],ask_data[11])
            outer_seq.add(ask_data[0..3])
            case tmp_fn
            of '\x03', '\x04': #read holding or input registers from modbus device
                if tmp_fn == '\x03':
                    self.hregs.gets(reg_adr,quan,regs_g)
                else:
                    self.iregs.gets(reg_adr,quan,regs_g)
                if regs_g.len > 0:
                    let byte_count:uint8 = uint8(quan)*2
                    let tcp_bytes:uint16 = uint16(quan)*2 + 3                 
                    outer_seq.add(cast_u16(tcp_bytes))
                    outer_seq.add(tmp_adr)
                    outer_seq.add(tmp_fn)
                    outer_seq.add(cast_c(byte_count))
                    outer_seq.add(seq_int16_to_seq_chr(regs_g))
                    apply(outer_seq, proc(c:char) = outer_str.add(c))
                else:
                    outer_str = tcp_error_response(mbap_strater,tmp_adr,tmp_fn,'\x02')
            of '\x01', '\x02': #read coils from modbus device
                if tmp_fn == '\x01':
                    self.coils.gets(reg_adr,quan,d_g)
                else:
                    self.di.gets(reg_adr,quan,d_g)
                if d_g.len > 0:
                    let bytes_of_d:seq[char] = bools_pack_to_bytes(d_g)
                    let byte_count:uint8 = uint8(bytes_of_d.len)
                    let tcp_bytes:uint16 = uint16(byte_count) + 3
                    outer_seq.add(cast_u16(tcp_bytes))
                    outer_seq.add(tmp_adr)
                    outer_seq.add(tmp_fn)
                    outer_seq.add(cast_c(byte_count))
                    outer_seq.add(bytes_of_d)
                    apply(outer_seq, proc(c:char) = outer_str.add(c))
                else:
                    outer_str = tcp_error_response(mbap_strater,tmp_adr,tmp_fn,'\x02')
            of '\x05': # set coil in modbus device
                if quan == 0 or quan == 65280:
                    if self.coils.sets(reg_adr,@[quan != 0]):
                        outer_seq = ask_data
                        apply(outer_seq, proc(c:char) = outer_str.add(c))
                    else:
                        outer_str = tcp_error_response(mbap_strater,tmp_adr,tmp_fn,'\x02')
                else:
                    outer_str = tcp_error_response(mbap_strater,tmp_adr,tmp_fn,'\x03')
            of '\x06': # write to holding register in modbus device
                if self.hregs.sets(reg_adr,chars_val_to_int16(ask_data[10..11])):
                    outer_seq = ask_data
                    apply(outer_seq, proc(c:char) = outer_str.add(c))
                else:
                    outer_str = tcp_error_response(mbap_strater,tmp_adr,tmp_fn,'\x02')
            of '\x0F': # write to coils in modbus device
                let last_el:int = 12 + int(cast[uint8](ask_data[12]))
                if self.coils.sets(reg_adr,bytes_to_seq_of_bools(ask_data[13..last_el],quan)):
                    outer_seq = ask_data[0..11]
                    apply(outer_seq, proc(c:char) = outer_str.add(c))
                else:
                    outer_str = tcp_error_response(mbap_strater,tmp_adr,tmp_fn,'\x02')
            of  '\x10': # write to holding registers in modbus device
                let last_el:int = 12 + int(cast[uint8](ask_data[12]))
                if self.hregs.sets(reg_adr,chars_val_to_int16(ask_data[13..last_el])):
                    outer_seq = ask_data[0..11]
                    apply(outer_seq, proc(c:char) = outer_str.add(c))
                else:
                    outer_str = tcp_error_response(mbap_strater,tmp_adr,tmp_fn,'\x02')
            of  '\x17': # read/write holding registers in modbus device
                var h_regs_g:seq[int16]
                self.hregs.gets(reg_adr,quan,h_regs_g)
                if h_regs_g.len > 0:
                    let byte_count:uint8 = uint8(quan)*2
                    let tcp_bytes:uint16 = uint16(quan)*2 + 3                 
                    outer_seq.add(cast_u16(tcp_bytes))
                    outer_seq.add(tmp_adr)
                    outer_seq.add(tmp_fn)
                    outer_seq.add(cast_c(byte_count))
                    outer_seq.add(seq_int16_to_seq_chr(h_regs_g))
                    apply(outer_seq, proc(c:char) = outer_str.add(c))
                    let last_el:int = 16 + int(cast[uint8](ask_data[16]))
                    if not self.hregs.sets(reg_adr,chars_val_to_int16(ask_data[17..last_el])):
                        outer_str = tcp_error_response(mbap_strater,tmp_adr,tmp_fn,'\x02')
                else:
                    outer_str = tcp_error_response(mbap_strater,tmp_adr,tmp_fn,'\x02')
            of '\x16': # write mask holding registers in modbus device
                var seqres:seq[int16]
                var h_r:int16
                self.hregs.gets(reg_adr,1,seqres)
                if seqres.len > 0:
                    h_r = seqres[0]
                    let and_mask:int16 = chars_val_to_int16(ask_data[10..11])[0]
                    let or_mask:int16 = chars_val_to_int16(ask_data[12..13])[0]
                    #let masked_reg:int16 = bitor(bitand(h_r,and_mask),bitand(or_mask,not and_mask))
                    if self.hregs.sets(reg_adr,@[bitor(bitand(h_r,and_mask),bitand(or_mask,not and_mask))]):
                        outer_seq = ask_data
                        apply(outer_seq, proc(c:char) = outer_str.add(c))
                else:
                    outer_str = tcp_error_response(mbap_strater,tmp_adr,tmp_fn,'\x02')
            else:
                outer_str = ""
        else:
            outer_str = tcp_error_response(mbap_strater,tmp_adr,tmp_fn,'\x01')
    else:
        outer_str = ""
    if tmp_fn in ['\x16','\x17','\x10','\x0F','\x06','\x05'] and self.auto_save_state:
        self.save_state()
    return outer_str

proc log_device(en:bool,lg:FileLogger,lv:Level,msg:string):void =
    if en:
        lg.log(lv,msg)

proc add_dead_bytes*(data:string,size:int):seq[char] =
    var
        cur_len:int = data.len
        res:seq[char] = @[]
    res.add(data.toHex.parseHexStr.toSeq())
    while cur_len < size:
        res.add('\x00')
        cur_len += 1
    return res

proc run_srv_synh* (plc: var ModBus_Device,port:int,ip_adr="") {.async.} =
    var
        tmp:seq[char] = @[]
        resp:string = ""
        ask:seq[char] = @[]
        bytes_to_get:int
        srv_log: FileLogger
    let socket = newSocket()
    srv_log = newFileLogger(dt_to_name_file(),fmtStr ="[$datetime] - $levelname:",lvlAll)
    log_device(plc.logging,srv_log,lvlInfo,"TCP ModBus device is started")
    socket.bindAddr(Port(port))
    socket.listen()
    var client: Socket
    var address = ""
    while true:
        socket.acceptAddr(client, address)
        try:
            let line = client.recv(6)
            tmp = line.toHex.parseHexStr.toSeq()
            bytes_to_get = char_adr_to_int(tmp[4],tmp[5])
            let line2 = client.recv(bytes_to_get)
            ask = tmp
        #ask.add(line2.toHex.parseHexStr.toSeq())
            if line2.len != bytes_to_get:
                log_device(plc.logging,srv_log,lvlWarn,fmt"Bytes expected {bytes_to_get}, recived {line2.len}")
            ask.add(add_dead_bytes(line2,bytes_to_get))
            log_device(plc.logging,srv_log,lvlNotice,fmt"Request:{ask}")
            resp = plc.response(ask)
            log_device(plc.logging,srv_log,lvlNotice,fmt"Response:{resp.toHex.parseHexStr.toSeq()}")
            client.send(resp)
        except CatchableError:
            log_device(plc.logging,srv_log,lvlError,fmt"Error until data exchange:{getCurrentExceptionMsg()}")
        client.close()


proc prClient(plc:ptr,client: AsyncSocket,srv_log:FileLogger) {.async.} =
    var
        tmp:seq[char] = @[]
        resp:string = ""
        ask:seq[char] = @[]
        bytes_to_get:int
    while true:
        try:
            let line = await client.recv(6)
            tmp = line.toHex.parseHexStr.toSeq()
            bytes_to_get = char_adr_to_int(tmp[4],tmp[5])
            let line2 = await client.recv(bytes_to_get)
            ask = tmp
        #ask.add(line2.toHex.parseHexStr.toSeq())
            if line2.len != bytes_to_get:
                log_device(plc.logging,srv_log,lvlWarn,fmt"Bytes expected {bytes_to_get}, recived {line2.len}")
            ask.add(add_dead_bytes(line2,bytes_to_get))
            log_device(plc[].logging,srv_log,lvlNotice,fmt"Request:{ask}")
            resp = plc[].response(ask)
            log_device(plc[].logging,srv_log,lvlNotice,fmt"Response:{resp.toHex.parseHexStr.toSeq()}")
            if line.len == 0: break
            await client.send(resp)
        except:
            log_device(plc.logging,srv_log,lvlError,fmt"Error until data exchange:{getCurrentExceptionMsg()}")
            break


proc run_srv_asynch* (plc:ptr,port:int,ip_adr="") {.async.} =
    var
        tmp:seq[char] = @[]
        resp:string = ""
        ask:seq[char] = @[]
        bytes_to_get:int
        line:string
        srv_log: FileLogger
    srv_log = newFileLogger(dt_to_name_file(),fmtStr ="[$datetime] - $levelname:",lvlAll)
    log_device(plc[].logging,srv_log,lvlInfo,"Async TPC ModBus device is started")
    var server = newAsyncSocket()
    server.setSockOpt(OptReuseAddr, true)
    server.bindAddr(Port(502))
    server.listen()
    while true:
        let client = await server.accept()
        asyncCheck prClient(plc,client,srv_log)
