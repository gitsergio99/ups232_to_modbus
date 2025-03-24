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

proc forming_resp(upss:ptr, id_n:int):string =
    var
        n:int = 0
        temp_str: string = """<html>
        <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
        <title>APC UPS RS232 to ModBus TCP server.</title>
        </head>
        <H2>Состояние Ups.</H2>
        <br>
        """
    temp_str.add(fmt"""
    <form action="" method="POST">
    <Select id="sel1" value="{intToStr(id_n)}" name="UPS">""")
    for x in upss[]:
        temp_str.add(fmt"""<option {(if n == id_n: "selected" else: "")} value="{n}">{x[].name}</option>""")
        n = n + 1
    temp_str.add("""
    </Select>
    <input type="submit" value="Отправить">
    </form>""")
    temp_str.add("""
        <table border="1">
        <caption>UPS</caption>
        <tr>
        <th>Name</th>
        <th>Model</th>
        <th>IP</th>
        <th>Batt V</th>
        <th>Internal T</th>
        <th>Line Freq</th>
        <th>In V</th>
        <th>In V max</th>
        <th>In V min</th>
        <th>Out V</th>
        <th>Power</th>
        <th>Batt Level</th>
        <th>Flags</th>
        <th>Register 1</th>
        <th>Register 2</th>
        <th>Register 3</th>
        </tr>
        """)
    temp_str.add(fmt"""  
    <tr>
    <td>{upss[][id_n].name}</td>
    <td>{upss[][id_n].model}</td>
    <td>{upss[][id_n].ip_adress}</td>
    <td>{upss[][id_n].tags["bat_v"][0]}</td>
    <td>{upss[][id_n].tags["int_t"][0]}</td>
    <td>{upss[][id_n].tags["freq_l"][0]}</td>
    <td>{upss[][id_n].tags["in_v"][0]}</td>
    <td>{upss[][id_n].tags["in_max_v"][0]}</td>
    <td>{upss[][id_n].tags["in_min_v"][0]}</td>
    <td>{upss[][id_n].tags["out_v"][0]}</td>
    <td>{upss[][id_n].tags["pow_l"][0]}</td>
    <td>{upss[][id_n].tags["bat_l"][0]}</td>
    <td>{num_to_bits(upss[][id_n].tags["flag_s"][0])}</td>
    <td>{num_to_bits(upss[][id_n].tags["reg1"][0])}</td>
    <td>{num_to_bits(upss[][id_n].tags["reg2"][0])}</td>
    <td>{num_to_bits(upss[][id_n].tags["reg3"][0])}</td>
    </tr>
    </table>
    """
    )
    temp_str.add(""" </table>
        <table border="1">
    <caption>Bits understanding</caption>
    <tr>
    <th>Flags</th>
    <th>Register 1</th>
    <th>Register 2</th>
    <th>Register 3</th>
    </tr>
        <tr>
    <td>0: Runtime calibration occuring</td>
    <td>0: In wake up mode</td>
    <td>0: Fan failure in electronic, UPS in bypass</td>
    <td>0: Output unpowered due to shutdown by low battery</td>
    </tr>
    <tr>
    <td>1: SmartTrim</td>
    <td>1: In bypass mode due to internal fault</td>
    <td>1: Fan failure in isolation unit</td>
    <td>1: Unable to transfer to battery due to overload</td>
    </tr>
    <tr>
    <td>2: SmartBoost</td>
    <td>2: Going to bypass mode due to command</td>
    <td>2: Bypass supply failure</td>
    <td>2: Main relay malfunction - UPS turned off</td>
    </tr>
    <tr>
    <td>3: On line</td>
    <td>3: In bypass mode due command</td>
    <td>3: Output voltage select failure, UPS in bypass</td>
    <td>3: In sleep mode from</td>
    </tr>
    <tr>
    <td>4: On battary</td>
    <td>4: Returning from bypass mode</td>
    <td>4: DC imbalance, UPS in bypass</td>
    <td>4: In shutdown mode from S</td>
    </tr>
    <tr>
    <td>5: Overloaded output</td>
    <td>5: In bypass mode due to manual bypass control</td>
    <td>5: Command sent to stop bypass with no battery connected - UPS still in bypass</td>
    <td>5: Battery charger failure</td>
    </tr>
    <tr>
    <td>6: Battary Low</td>
    <td>6: Ready to power load on user command</td>
    <td>6: Realy fault in SmartTrim or SmartBoost</td>
    <td>6: Bypass relay malfunction</td>
    </tr>
    <tr>
    <td>7: Replace battary</td>
    <td>7: Ready to power load on user command or return of line power</td>
    <td>7: Bad output voltage</td>
    <td>7: Normal operating temperature exceeded</td>
    </tr>
    </table>""")
    temp_str.add("""
    </body>
    </html>
    """)
    return temp_str
        



proc main_http(upss:ptr, h_port:int) {.async.} =
    var http_server = newAsyncHttpServer()
    var txt:string = "ok"
    
    proc handler_http(req: Request) {.async.} =
        var id_ups:int
        if len(req.url.path) == 1:
            try:
                id_ups = parseInt(req.body.split("=")[1])
            except:
                id_ups = 0
            txt = forming_resp(upss,id_ups)
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
    #echo modbus_server_port
    asyncCheck run_srv_asynch(pointer_mb_srv,modbus_server_port)
    runForever()

proc ups_task(mb: ptr, ups:ptr, lg:ptr) =
    while run_ups:
        if ups[].enabled:
            read_ups_write_modbus(mb,ups, lg)
        sleep(ups[].cycle_time)

proc main_task() =
    var
        #ntreads = countProcessors()
        tp = Taskpool.new(num_threads = 10)
    spawn(tp,mb_task())
    spawn(tp,http_task())
    for y in ups_devices_ptr:
        spawn(tp,ups_task(pointer_mb_srv,y,ups_log_ptr))
        sleep(10000)
    while true:
        sleep(1000)
main_task()


