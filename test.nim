import ups_lib, tables, ups_lib
import std/[streams,marshal,parsecfg,strutils]

var
    tab = initTable[string,array[2, string]]()
    dev: Ups

    
    
dev = Ups(
        ip_adress: "sdsdsd",
        port: 4001,
        name: "sdsdsd",
        model: "APC smart unknown",
        cycle_time: 5000,
        enabled: true
        )    


#tab = {"bat_v": ["NA","B"], "int_t": ["NA","C"], "freq_l": ["NA","F"], "in_v": ["NA","L"], "in_max_v": ["NA","M"], "in_min_v": ["NA","N"], "out_v":["NA","O"] , "pow_l":["NA","P"], "bat_l": ["NA","f"], "flag_s": ["NA","Q"], "reg1": ["NA","~"], "reg2": ["NA","'"], "reg3": ["NA","8"]}.toTable()
#echo lowUpsRequest("~","10.39.225.52",4001)

#fillUpsTable(tab,"10.39.225.52",4001)
#dev.tags = {"bat_v": ["NA","B"], "int_t": ["NA","C"], "freq_l": ["NA","F"], "in_v": ["NA","L"], "in_max_v": ["NA","M"], "in_min_v": ["NA","N"], "out_v":["NA","O"] , "pow_l":["NA","P"], "bat_l": ["NA","f"], "flag_s": ["NA","Q"], "reg1": ["NA","~"], "reg2": ["NA","'"], "reg3": ["NA","8"]}.toTable()
#let strm: FileStream = newFileStream("test.json", fmWrite)
#store(strm,dev)


echo dev