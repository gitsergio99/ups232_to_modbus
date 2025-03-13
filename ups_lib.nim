import std/[strformat,net]

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

        

