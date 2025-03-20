import modbusutil,mbdevice,ups_lib
import std/[tables,streams,marshal,parsecfg,strutils,asyncnet,asyncdispatch,net,sequtils,os,logging,times,strformat,asynchttpserver]
import taskpools

var
    file_json_ups:string = "ups_cfg.json"
    file_cfg_srv:string = "ups_modbus_srv.cfg"
    modbus_server_port: int
    http_server_port: int = 9500
    ups_devices:seq[Ups] = @[]
    mb_srv: ModBus_Device
    ups_devices_ptr:seq[ptr[Ups]] = @[]
    run_ups:bool = true
    tmp_str: string = now().format("yyyy'_'MM'_'dd'_'HH'_'mm'_'ss'.log'")
    ups_log_name: string = fmt"ups_log_{tmp_str}"
    ups_logg = newFileLogger(ups_log_name,levelThreshold=lvlAll,fmtStr="[$datetime] - $levelname:")
    ups_log_ptr: ptr[FileLogger] = ups_logg.addr
    ups_seq_ptr: ptr[seq[ptr[Ups]]]
#Init ModbusServer
mb_srv.initModBus_Device("Modbus UPS server",true,uint8(1),false, @[[0,65536]], @[[0,100]], @[[0,100]],@[[0,100]])
var pointer_mb_srv:ptr[ModBus_Device] = mb_srv.addr
# load configuration file
let cfg = loadConfig(file_cfg_srv)
modbus_server_port = parseInt(cfg.getSectionValue("","port"))
http_server_port = parseInt(cfg.getSectionValue("","http_port"))
# load UPS devices
let strm: FileStream = newFileStream(file_json_ups, fmRead)
load(strm,ups_devices)
for x in countup(0,len(ups_devices)-1):
    ups_devices[x].tags = {"bat_v": ["NA","B","0"], "int_t": ["NA","C","1"], "freq_l": ["NA","F","2"], "in_v": ["NA","L","3"], "in_max_v": ["NA","M","4"], "in_min_v": ["NA","N","5"], "out_v":["NA","O","6"] , "pow_l":["NA","P","7"], "bat_l": ["NA","f","8"], "flag_s": ["NA","Q","9"], "reg1": ["NA","~","10"], "reg2": ["NA","'","11"], "reg3": ["NA","8","12"]}.toTable()
    ups_devices_ptr.add(ups_devices[x].addr)
ups_seq_ptr = ups_devices_ptr.addr
#echo ups_devices

proc main_http(upss:ptr):string =
    var
        n:int = 0
        temp_str: string = """<html>
        <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
        <title>APC UPS RS232 to ModBus TCP server.</title>
        </head>
        <body>
        <H2>Состояние Ups.</H2>
        <br>
        """
        #["""
        <table border="1">
        <caption>UPS</caption>
        <tr>
        <th>Name</th>
        <th>Value</th>
        <th>Alarm Up</th>
        <th>Alarm Down</th>
        <th>Warnning Up</th>
        <th>Warning Down</th>
        <th>Alarm Up State</th>
        <th>Alarm Down State</th>
        <th>Warnning Up State</th>
        <th>Warning Down State</th>
        <th>Alarm Enabled</th>
        </tr>
        """]#
    temp_str.add("""
    <form action="main2.html" method="post">
    <Select id="sel1" name="UPS">""")
    for x in upss[]:
        temp_str.add(fmt"""<option value="{n}">{x[].name}</option>""")
        n = n + 1
    temp_str.add("""
    </Select>
    <input id="2" type="text" name="e_date" size="23" maxlength="23" value="2">
    <input type="submit" value="Отправить">
    </form>
    </body>
    </html>
    """)
    return temp_str
        



proc main_http(upss:ptr, h_port:int) {.async.} =
    var http_server = newAsyncHttpServer()
    var txt:string = "ok"

    proc handler_http(req: Request) {.async.} =
        echo req.url.path
        if req.url.path[0] == '/':
            txt = main_http(upss)
        #echo txt
        await req.respond(Http200,txt)
    
    waitFor http_server.serve(Port(h_port),handler_http)


proc http_task() =
    waitFor main_http(ups_seq_ptr, http_server_port)


proc read_ups_write_modbus(mb:ptr, ups:ptr, lg: ptr) =
    var
        mb_base: int = 100
        temp_str: string = "0"
        res:bool
    fillUpsTable(ups[].tags,ups[].ip_adress,ups[].port)
    lg[].log(lvlInfo,ups[].ups_str)
    for x in ups[].tags.values:
        if (x[0] == "NA") or (x[0]=="NA_request_error"):
            temp_str = "0"
        else:
            temp_str = x[0]
        if (x[2] == "9") or (x[2] == "10") or (x[2] == "11") or  (x[2] == "12"):
            res = mb[].hregs.sets((mb_base+(100*ups[].index)+parseInt(x[2])),@[int16(parseInt(temp_str))])
        else:
            res = mb[].hregs.sets((mb_base+(100*ups[].index)+parseInt(x[2])),@[int16(parseFloat(temp_str)*100)])
             


proc mb_task() =
    echo modbus_server_port
    asyncCheck run_srv_asynch(pointer_mb_srv,modbus_server_port)
    runForever()

proc ups_task(mb: ptr, ups:ptr, lg:ptr) =
    while run_ups:
        if ups[].enabled:
            read_ups_write_modbus(mb,ups, lg)
            #echo ups[].ups_str()
        sleep(ups[].cycle_time)

proc main_task() =
    var
        #ntreads = countProcessors()
        tp = Taskpool.new(num_threads = 8)
    spawn(tp,mb_task())
    spawn(tp,http_task())
    for y in ups_devices_ptr:
        spawn(tp,ups_task(pointer_mb_srv,y,ups_log_ptr))
    while true:
        sleep(1000)
main_task()


