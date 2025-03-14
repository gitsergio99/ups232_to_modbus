import modbusutil,mbdevice,ups_lib
import std/[tables,streams,marshal,parsecfg,strutils]

var
    file_json_ups:string = "ups_cfg.json"
    file_cfg_srv:string = "ups_modbus_srv.cfg"
    modbus_server_port: int = 502
    ups_devices:seq[Ups] = @[]
    mb_srv: ModBus_Device 

#Init ModbusServer
mb_srv.initModBus_Device("Modbus UPS server",true,uint8(1),false, @[[0,65536]], @[[0,100]], @[[0,100]],@[[0,100]])
var p_mb_srv:ptr[ModBus_Device] = mb_srv.addr
# load configuration file
let cfg = loadConfig(file_cfg_srv)
modbus_server_port = parseInt(cfg.getSectionValue("","port"))
# load UPS devices
let strm: FileStream = newFileStream(file_json_ups, fmRead)
load(strm,ups_devices)
for x in countup(0,len(ups_devices)-1):
    ups_devices[x].tags = {"bat_v": ["NA","B"], "int_t": ["NA","C"], "freq_l": ["NA","F"], "in_v": ["NA","L"], "in_max_v": ["NA","M"], "in_min_v": ["NA","N"], "out_v":["NA","O"] , "pow_l":["NA","P"], "bat_l": ["NA","f"], "flag_s": ["NA","Q"], "reg1": ["NA","~"], "reg2": ["NA","'"], "reg3": ["NA","8"]}.toTable()
#echo ups_devices
