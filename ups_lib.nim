import std/[strformat,net,tables,os,typetraits,sequtils,strutils,bitops]


var
    tag_tables* = initTable[string,array[3, string]]()


tag_tables = {"bat_v": ["NA","B","0"], "int_t": ["NA","C","1"], "freq_l": ["NA","F","2"], "in_v": ["NA","L","3"], "in_max_v": ["NA","M","4"], "in_min_v": ["NA","N","5"], "out_v":["NA","O","6"] , "pow_l":["NA","P","7"], "bat_l": ["NA","f","8"], "flag_s": ["NA","Q","9"], "reg1": ["NA","~","10"], "reg2": ["NA","'","11"], "reg3": ["NA","8","12"]}.toTable()

type
    Ups_cmd* = enum
        fp_test = "A" #Front panel test
        bat_voltage = "B" #Battery voltage
        int_temp = "C" #Internal temperature
        runt_calib = "D" #Runtime calibration
        auto_self_test_int = "E" #Automatic self test intervals
        line_freq = "F" #Line freq. Hz
        cause_of_transf = "G" #Cause of transfer
        in_line_voltage = "L" #Input line voltage
        max_line_voltage = "M" #Maximum line voltage received since last M query
        min_line_voltage = "N" #Minimum line voltage received since last N query
        out_voltage = "O" #Output voltage
        power_load = "P" #Power load %
        status_flags = "Q" #Status flags
        self_test = "W" #Do self test of battery store in X
        res_self_test = "X"  #Result of selftest
        batt_level = "f" #Battery level %
        reg1 = "~" #Register 1
        reg2 = "'" #Register 2
        reg3 = "8" #Register 3



type
    Ups* = object
        index*:int
        ip_adress*:string
        port*:int
        name*:string
        model*:string = "APC smart unknown"
        cycle_time*:int
        enabled*:bool
        tags* = initTable[string,array[3, string]]()


# View current state of USP object in terminal
proc ups_str*(self: Ups): string =
    var
        temp_str = "Current state of "
    temp_str.add(fmt"{self.name} is :{'\n'}")
    for x,y in self.tags:
        temp_str.add(fmt"{x}:{y[0]}{'\n'}")
    return temp_str

# return color if bit in value true or white if false. for html
proc test_bit_set_color*(val:string,bit_indx:int,color:string):string =
    var
        default_color:string = "white"
        int_val: uint8
    try:
        int_val = uint8(parseInt(val))
    except:
        int_val = 0
    if int_val.testBit(bit_indx):
        result = color
    else:
        result = default_color


#Request to Smart USP RS232 via rs232/tcp server like moxa nport
proc lowUpsRequest*(cmd:string,ip:string,port:int): string =
    var
        cmd_pointer: pointer
        sock: Socket
        res:int
    cmd_pointer = cmd[0].addr
    sock = newSocket()
    try:
        sock.connect(ip,Port(port))
        res = sock.send(cmd_pointer,len(cmd))
        result = sock.recvLine(timeout = 200)
        sock.close()
    except:
        sock.close()
        result = "NA_request_error"


# represent value in string bit array
proc num_to_bits* (val: any): string =
    when val.type.name == "int":
        result = fmt"{val:#b}"
    elif val.type.name == "float":
        result = fmt"{cast[uint32](val):#b}"
    elif val.type.name == "string":
        if val.allIt(it.isDigit()):
            result = fmt"{parseInt(val):#b}"
        else:
            result = val
    else:
        result = "none"


# Get's data from rs232 Smart Ups via tcp
proc fillUpsTable*(upstable:var Table, ip:string, port:int) =
    var
        ups_answer:string
        strarting_command: string = "YY"
        temp_str:string
    temp_str = lowUpsRequest(strarting_command,ip,port)
    sleep(100)
    #echo fmt"IP is {ip} and port is {port}"
    for name_par,tag in upstable:
        ups_answer = lowUpsRequest(tag[1],ip,port)
        upstable[name_par] = [ups_answer,tag[1],tag[2]]
        sleep(100)
    #echo upstable


