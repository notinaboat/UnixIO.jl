@assert C.termios_size == sizeof(C.termios)

@doc README"""
    UnixIO.tcgetattr(tty) -> C.termios_m

Get terminal device options.
See [tcgetattr(3)](https://man7.org/linux/man-pages/man3/tcgetattr.3.html).
"""
@db 2 function tcgetattr(tty, attr=termios(tty))
    aref = Ref(attr)
    @cerr C.tcgetattr_m(tty, aref)
    @db 2 return aref[]
end
tcgetattr(tty::FD{<:Any,<:S_IFCHR}) = tcgetattr(tty, termios(tty))


function termios(tty::FD{<:Any,<:S_IFCHR})
    get_extra(tty, :termios, ()->tcgetattr(tty, C.termios_m()))
end
termios(tty::Union{Cint,RawFD}) = tcgetattr(tty, C.termios_m())


@doc README"""
### `UnixIO.tcsetattr` -- Configure Terminals and Serial Ports.

    UnixIO.tcsetattr(tty, attr::C.termios_m)
    UnixIO.tcsetattr(tty) do attr
         [attr.c_iflag = ...]
         [attr.c_oflag = ...]
         [attr.c_cflag = ...]
         [attr.c_lflag = ...]
         [attr.speed = ...]
    end

Set terminal device options.

e.g.

    io = UnixIO.open("/dev/ttyUSB0", C.O_RDWR | C.O_NOCTTY)
    UnixIO.tcsetattr(io) do attr
        setraw(attr)
        attr.speed=9600
        attr.c_lflag |= C.ICANON
    end

See [tcsetattr(3)](https://man7.org/linux/man-pages/man3/tcsetattr.3.html)
for flag descriptions.

"""
function tcsetattr(f, tty::AnyFD)
    c = tcgetattr(tty)
    f(c)
    tcsetattr(tty, c)
end
tcsetattr(tty, attr::C.termios_m) =
    @cerr C.tcsetattr_m(tty, C.TCSANOW, Ref(attr))

DuplexIOs.@wrap tcsetattr
tcsetattr(f, tty::DuplexIO) = (tcsetattr(f, tty.in); tcsetattr(f, tty.out))

"""
Disabling all terminal input and output processing.
"""
@selfdoc function setraw(x::C.termios_m)
    x.c_iflag = 0
    x.c_oflag = 0
    x.c_cflag = C.CS8
    x.c_lflag = 0
    nothing
end

@selfdoc setraw(f) = tcsetattr(setraw, f)


function setspeed!(attr::C.termios_m, speed)
    flag = eval(:(C.$(Symbol("B$speed"))))
    @cerr C.cfsetspeed_m(Ref(attr), flag)
    nothing
end

Base.setproperty!(c::C.termios_m, f::Symbol, x) =
    f === :speed ? (setspeed!(c, x); x) :
                    @invoke setproperty!(c::Any, f::Symbol, x)


iscanon(tty) = (termios(tty).c_lflag & C.ICANON) != 0
setcanon(tty) = tcsetattr(c -> c.c_lflag &= C.ICANON, tty)


@doc README"""
### `UnixIO.flush` -- Discard untransmitted data.

    tcflush(tty, flags)

See [tcflush(3p)](https://man7.org/linux/man-pages/man3/tcflush.3p.html)
"""
tcflush(tty, flags) = @cerr C.tcflush(tty, flags)

DuplexIOs.@wrap tcflush

tcdrain(tty) = @cerr C.tcdrain(tty)

DuplexIOs.@wrap tcdrain


@doc README"""
### `UnixIO.tiocgwinsz` -- Get Terminal size.

    tiocgwinsz(tty) -> C.winsize

See [tty_ioctl(4)](https://man7.org/linux/man-pages/man4/tty_ioctl.4.html)
"""
tiocgwinsz(tty) = (x=[C.winsize()]; @cerr C.ioctl(tty, C.TIOCGWINSZ, x); x[1])

tiocgwinsz(tty::DuplexIO) = tiocgwinsz(tty.out)
