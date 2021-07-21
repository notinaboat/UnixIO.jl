# stat(2)


function fstat(fd)
    #FIXME 
    s = Ref(C.stat64())
    @cerr C.fstat64(fd, s)
    return s[]
end





# End of file: stat.jl
