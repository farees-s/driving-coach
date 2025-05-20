# src/sim_info.py  – minimal fallback for Assetto Corsa shared memory
import ctypes, ctypes.wintypes as wt


class SPageFilePhysics(ctypes.Structure):
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
 ## I ASKED CHATGPT FOR HOW TO GET THE SHARED MEMORY WITH ASSETTO CORSA. THIS IS HOW MODS DO IT
class SharedMemory:
    """
    Simple read‑only mapping of an Assetto Corsa shared‑memory section.
    Keeps the OS handle and view pointer alive for the life of the object.
    """
    FILE_MAP_READ = 0x0004

    def __init__(self, name: str, size: int):
        k32 = ctypes.windll.kernel32

        # open the named file‑mapping created by AC
        k32.OpenFileMappingW.restype = wt.HANDLE
        handle = k32.OpenFileMappingW(self.FILE_MAP_READ, False, name)
        if not handle:
            raise RuntimeError(
                f"Cannot open shared memory '{name}'. Is AC on track?")

        # map a view of the entire section
        k32.MapViewOfFile.restype = wt.LPVOID = ctypes.c_void_p
        ptr = k32.MapViewOfFile(handle, self.FILE_MAP_READ, 0, 0, size)
        if not ptr:
            raise RuntimeError("Cannot map view of shared memory.")

        # keep references so they don’t get GC‑collected
        self._handle = handle
        self._ptr    = ptr

        # live C‑struct bound directly onto the view
        self.struct = SPageFilePhysics.from_address(ptr)


info = type(
    "ac_info",
    (),
    {"physics": SharedMemory("Local\\acpmf_physics",
                             ctypes.sizeof(SPageFilePhysics)).struct}
)
