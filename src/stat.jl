# stat(2)


function fstat(fd)
    #FIXME 
    s = Ref(C.stat64())
    @cerr C.fstat64(fd, s)
    return s[]
end

abstract type S_IFIFO  end
abstract type S_IFCHR  end
abstract type S_IFDIR  end
abstract type S_IFBLK  end
abstract type S_IFREG  end
abstract type S_IFLNK  end
abstract type S_IFSOCK end

function fdtype(fd)
    s = stat(fd)
    isfile(s)     ? S_IFREG  :
    isblockdev(s) ? S_IFBLK  :
    ischardev(s)  ? S_IFCHR  :
    isdir(s)      ? S_IFDIR  :
    isfifo(s)     ? S_IFIFO  :
    islink(s)     ? S_IFLNK  :
    issocket(s)   ? S_IFSOCK :
                     Nothing
end



# End of file: stat.jl
