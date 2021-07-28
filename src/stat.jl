# stat(2)


function fstat(fd)
    s = Ref(C.stat64())
#    @cerr C.fstat64(fd, s)
     C.__fxstat64(0, fd, s)
    return s[]
end

stat_mode(stat) = stat.st_mode & C.S_IFMT





# End of file: stat.jl
