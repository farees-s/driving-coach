import ctypes, ctypes.wintypes as wt
# this basically acts as the shared memory with assetto corsa, since i cannot find the actual file that assetto corsa gets out. this basically ports it out.|
# this was originally supposed to be with ACUDP, but i was facing so many bugs, that I just switched out to getting the shared memory. It had a lot of documentation, but I couldnt fix it.

class SPageFilePhysics(ctypes.Structure): # specific things i need for analysis
    _fields_ = [
        ("packetId",     ctypes.c_int),
        ("gas",          ctypes.c_float),
        ("brake",        ctypes.c_float),
        ("fuel",         ctypes.c_float),
        ("gear",         ctypes.c_int),
        ("rpms",         ctypes.c_int),
        ("steerAngle",   ctypes.c_float),
        ("speedKmh",     ctypes.c_float),

    ]
 ## I ASKED CHATGPT FOR HOW TO GET THE SHARED MEMORY WITH ASSETTO CORSA. THIS IS HOW SHARED MEMORY BASED MODS DO IT
class SharedMemory:
    FILE_MAP_READ = 0x0004 ##chatgpt

    def __init__(self, name: str, size: int):
        k32 = ctypes.windll.kernel32 ## chatgpt

        k32.OpenFileMappingW.restype = wt.HANDLE ## documention for how to actually open the file + make the handle
        handle = k32.OpenFileMappingW(self.FILE_MAP_READ, False, name)
        if not handle:
            raise RuntimeError(
                f"cant open shared memory '{name}'") ## throw error that it cant open, but should not run unless running without assetto corsa open


        k32.MapViewOfFile.restype = wt.LPVOID = ctypes.c_void_p #chat
        ptr = k32.MapViewOfFile(handle, self.FILE_MAP_READ, 0, 0, size) #chat
        if not ptr:
            raise RuntimeError("Cannot map view of shared memory.") #chat

        #updated selfs
        self._handle = handle
        self._ptr    = ptr

        #chat
        self.struct = SPageFilePhysics.from_address(ptr)


info = type(
    "ac_info",
    (),
    {"physics": SharedMemory("Local\\acpmf_physics",
                             ctypes.sizeof(SPageFilePhysics)).struct} #chatgpt to get the specific physics from assetto corsa
)
