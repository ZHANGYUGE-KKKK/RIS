import ctypes as C,ctypes.util,re,subprocess,time,sys
action=sys.argv[1]
owners=subprocess.run(['fuser','/dev/ttyUSB0'],capture_output=True,text=True).stdout.split()
if action=='close' and not owners: print('PORT_ALREADY_CLOSED');sys.exit(0)
if action=='open' and owners: print('PORT_ALREADY_OWNED',owners);sys.exit(0)
tree=subprocess.check_output(['xwininfo','-root','-tree'],text=True)
match=re.search(r'(0x[0-9a-f]+) "CuteCom - Default": \("cutecom"',tree)
if not match: raise RuntimeError('CuteCom window not found')
win=int(match[1],16)
x=C.CDLL(ctypes.util.find_library('X11')); t=C.CDLL(ctypes.util.find_library('Xtst'))
x.XOpenDisplay.argtypes=[C.c_char_p];x.XOpenDisplay.restype=C.c_void_p
d=x.XOpenDisplay(None)
if not d: raise RuntimeError('No display')
class Data(C.Union):
    _fields_=[('b',C.c_char*20),('s',C.c_short*10),('l',C.c_long*5)]
class Message(C.Structure):
    _fields_=[('type',C.c_int),('serial',C.c_ulong),('send_event',C.c_int),('display',C.c_void_p),('window',C.c_ulong),('message_type',C.c_ulong),('format',C.c_int),('data',Data)]
class Event(C.Union):
    _fields_=[('msg',Message),('pad',C.c_long*24)]
x.XDefaultRootWindow.argtypes=[C.c_void_p];x.XDefaultRootWindow.restype=C.c_ulong
x.XInternAtom.argtypes=[C.c_void_p,C.c_char_p,C.c_int];x.XInternAtom.restype=C.c_ulong
x.XSendEvent.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_long,C.POINTER(Event)]
x.XFlush.argtypes=[C.c_void_p]
e=Event();e.msg.type=33;e.msg.send_event=1;e.msg.display=d;e.msg.window=win
e.msg.message_type=x.XInternAtom(d,b'_NET_ACTIVE_WINDOW',0);e.msg.format=32
e.msg.data.l[0]=2;e.msg.data.l[1]=0
x.XSendEvent(d,x.XDefaultRootWindow(d),0,(1<<20)|(1<<19),C.byref(e));x.XFlush(d)
# Keep the connection button clear of the desktop dock when CuteCom was
# previously positioned partly outside the screen.
e.msg.message_type=x.XInternAtom(d,b'_NET_MOVERESIZE_WINDOW',0)
e.msg.data.l[0]=(2<<12)|(1<<8)|(1<<9)
e.msg.data.l[1]=200;e.msg.data.l[2]=100
e.msg.data.l[3]=0;e.msg.data.l[4]=0
x.XSendEvent(d,x.XDefaultRootWindow(d),0,(1<<20)|(1<<19),C.byref(e));x.XFlush(d)
time.sleep(.6)
x.XRaiseWindow.argtypes=[C.c_void_p,C.c_ulong];x.XRaiseWindow(d,win)
x.XSetInputFocus.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_ulong];x.XSetInputFocus(d,win,2,0)
x.XTranslateCoordinates.argtypes=[C.c_void_p,C.c_ulong,C.c_ulong,C.c_int,C.c_int,C.POINTER(C.c_int),C.POINTER(C.c_int),C.POINTER(C.c_ulong)]
x.XDefaultRootWindow.argtypes=[C.c_void_p];x.XDefaultRootWindow.restype=C.c_ulong
px=C.c_int();py=C.c_int();child=C.c_ulong()
x.XTranslateCoordinates(d,win,x.XDefaultRootWindow(d),48,45,C.byref(px),C.byref(py),C.byref(child))
if not (100<=px.value<1800 and 80<=py.value<1000):
    raise RuntimeError(f'Connection button is not safely visible: {px.value},{py.value}')
t.XTestFakeMotionEvent.argtypes=[C.c_void_p,C.c_int,C.c_int,C.c_int,C.c_ulong]
t.XTestFakeButtonEvent.argtypes=[C.c_void_p,C.c_uint,C.c_int,C.c_ulong]
t.XTestFakeMotionEvent(d,-1,px.value,py.value,0)
t.XTestFakeButtonEvent(d,1,1,0);t.XTestFakeButtonEvent(d,1,0,0)
x.XFlush.argtypes=[C.c_void_p];x.XFlush(d)
time.sleep(.5)
print('CUTE_COM_PORT_BUTTON_CLICKED',action)
