import std/[strformat,net]

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
        
type
    Ups* = object
        ip_adress*: string
        name*:string
        model*:string = "APC smart unknown"
        bat_voltage*:float
        int_temp*:float
        line_freq*:float
        input_voltage*:float
        output_voltage*:float
        power_load*:float




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
        result = sock.recvLine(2000)
        sock.close()
    except:
        result = "NA_request_error"

        

