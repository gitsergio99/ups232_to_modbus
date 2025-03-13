import std/[net,os]
var
    sock: Socket
    send_data:string
    recv_data:string
    send_data_pointer:pointer
    res:int

sock  = newSocket()
sock.connect("10.39.225.52",Port(4001))

send_data = "C"
send_data_pointer = send_data[0].addr()
res = sock.send(send_data_pointer,len(send_data))
#sleep(100)
try:
    recv_data = sock.recvLine(3000)
    echo recv_data
    sock.close()
except:
    sock.close()
    echo "Bad news"    
