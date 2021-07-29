# UnixIO.jl Architecture

## Unfiled Notes

 - Channel API?
   - all options configured on channel, not passed to take!
 - consider @noinline and @nospecialize, @noinline
 - specify types on kw args? check compiler log of methods generated

## 

## Overview of Architecture 

### Waiting for IO Events

### Waiting for Child Processes

 - P_PIDFD -  https://man7.org/linux/man-pages/man2/waitpid.2.html
        #define P_PIDFD		3

 - SIGCHILD ? 
 - sleep poll ?
 - signalfd ?
 -  kqueue EVFILT_PROC EVFILT_SIGNAL EVFILT_PROCDESC
    https://gist.github.com/davmac314/422dff2caf0254f982955a8bdf2c5704

### Buffering?



# Unfinished Ideas


## Layers and Traits

 - Basic layer should be thin wrapper of posix io, no buffering,
    - no exceptions?
 - Use traits to handle differerences (chr/file/socket, poll/epoll/sleep)
 - Use traits to handle speial features: read line, read packet
 - Use wrappers to add features: read line, tee, logging, buffering

 - Use global const for OS - specific traits


## IOWrappers

   - TeeIO ? 
   - BufferedIO
   - IODebug.jl https://github.com/JuliaWeb/HTTP.jl/blob/master/src/IODebug.jl


## Traits? 

struct ReadsLines end
struct ReadsBytes end

ReadStyle(::Type{S_IFIFO}) = ReadsLines()

speed:
 - fast mmap - ok for small and large requests
 - fast local - but slow for small requests
 - fast network - but slow for small requests
 - slow serial - no problem with small requests\be

event sources:
 - can be polled
 - can be selected
 - can be epolled
 - can be AIOed
 - can be sleep polled?

content:
 - Has bytes
 - no content (links)
 - directory

mappable:
 - yes
 - no

End / Size
 - staticly know (file) but not immutablne
 - infinite

more data available?
 - statically knowable
 - dynamically knowable
 - not knowable without attempting to read

reads what ?
 - lines ? gaurantee to read one at a time?
 - bytes ?
 - packets
 - can efficiently read bytes?
 - can read 
  - natural page size?

 writing
  - needs flush?
  - efficient to write one byte at a time?
  - natural page size?

struct  end

    HasLength, SizeUnknown, HasShape, IsInfinite
"""


# Motivation

## Related Issues?
https://github.com/JuliaLang/julia/issues/14747
Intermittent deadlock in readbytes(open(echo \$text)) on Linux ? #14747

Spawning turns IO race into process hang #24440
https://github.com/JuliaLang/julia/issues/24440

Redirected STDOUT on macOS is hanging when more than 512 bytes are written at once #20812
https://github.com/JuliaLang/julia/issues/20812

Deadlock in reading stdout from cmd #22832
https://github.com/JuliaLang/julia/issues/22832

support serial port #1970
https://github.com/libuv/libuv/issues/1970

Pseudo-tty support #2640
https://github.com/libuv/libuv/issues/2640

add uv_device_t as stream on windows and Linux to handle device IO #484
https://github.com/libuv/libuv/pull/484

