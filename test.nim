import ups_lib, tables, ups_lib
import std/[streams,marshal,parsecfg,strutils,sequtils]
import strformat, typetraits

proc num_to_bits (val: any): string =
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



var
    tab = initTable[string,array[3, string]]()
    dev: Ups
    val: float = 43.3
    val_s = "08"

#echo val.type.name
#if val.allIt(it.isDigit()):
#    val = fmt"{parseInt(val):#08b}"


#echo typedesc(val.typeof)
echo num_to_bits(val)

echo val
dev = Ups(
        ip_adress: "sdsdsd",
        port: 4001,
        name: "sdsdsd",
        model: "APC smart unknown",
        cycle_time: 5000,
        enabled: true
        )    


tab = {"bat_v": ["NA","B","0"], "int_t": ["NA","C","1"], "freq_l": ["NA","F","2"], "in_v": ["NA","L","3"], "in_max_v": ["NA","M","4"], "in_min_v": ["NA","N","5"], "out_v":["NA","O","6"] , "pow_l":["NA","P","7"], "bat_l": ["NA","f","8"], "flag_s": ["NA","Q","9"], "reg1": ["NA","~","10"], "reg2": ["NA","'","11"], "reg3": ["NA","8","12"]}.toTable()
#echo lowUpsRequest("~","10.39.225.52",4001)

#[fillUpsTable(tab,"10.39.225.52",4001)
for x,y in tab.pairs:
    echo x
]#
#dev.tags = {"bat_v": ["NA","B"], "int_t": ["NA","C"], "freq_l": ["NA","F"], "in_v": ["NA","L"], "in_max_v": ["NA","M"], "in_min_v": ["NA","N"], "out_v":["NA","O"] , "pow_l":["NA","P"], "bat_l": ["NA","f"], "flag_s": ["NA","Q"], "reg1": ["NA","~"], "reg2": ["NA","'"], "reg3": ["NA","8"]}.toTable()
#let strm: FileStream = newFileStream("test.json", fmWrite)
#store(strm,dev)

#echo dev