using Test
using UnixIO
using UnixIO.IOTraits
using UnixIO: dbstring, C
using AsyncLog
using LoggingTestSets
using Crayons

@testset LoggingTestSet "Pseudoterminal Tests" begin

function ptdump(f, cmd, cin, cout)

    #@info "ptdump" cmd cin cout

    blue = crayon"fg:blue"
    red = crayon"bold fg:red"

    println("┌ ", blue, cmd, inv(blue), ":")
    pad =   "│ "
    needpad = Ref(false)
    neednl = Ref(false)

    function fin()
        x = ""
        for _ in 1:30
            x = readline(cout; keep=true, timeout=0.1)
            if x != ""
                break
            end
        end
        if !endswith(x, "\n")
            x *= readline(cout; keep=true, timeout=0.1)
        end
        if x == ""
            return nothing
        end
        if neednl[]
            print(red, "!", inv(red), "\n")
        end
        neednl[] = false
        print(pad)
        print(blue, x, inv(blue))
        needpad[] = x[end] == '\n'
        x
    end

    function fout(x)
        if needpad[]
            print(pad)
        end
        for c in x
            write(cin, c)
            if c isa Char
                print(c)
            end
            sleep(0.05 * rand())
        end
        needpad[] = x[end] == '\n'
        neednl[] = x[end] != '\n'
    end

    f(fin, fout)

    println("\n└")
end

opts = (check_status=false,)

@info "Testing with Julia UnixIO pty client"

mktempdir() do d
    jlfile=joinpath(d, "tmp.jl")
    write(jlfile, """
        using UnixIO
        io = UnixIO.stdin
        try
            @show ENV["JULIA_UNIX_IO_DEBUG_LEVEL"]
            @show UnixIO.DEBUG_LEVEL
            @show typeof(io)
            @assert io isa UnixIO.FD{UnixIO.In,UnixIO.CanonicalMode}
            @assert !(io isa UnixIO.FD{UnixIO.In,UnixIO.Pseudoterminal})
            @show UnixIO.ReadUnit(io)
            @assert UnixIO.ReadUnit(io) == UnixIO.IOTraits.ReadUnit{:Line}()
        catch err
            exception=(err, catch_backtrace())
            @error "Error in pty client" exception
        end
        println("go!")
        while true
            try
                l = readline(io; keep=true)
                b = bytesavailable(io)
                UnixIO.println(length(l), ":", repr(l), ":", b)
            catch err
                exception=(err, catch_backtrace())
                @error "Error in pty client" exception
                println("Error done.")
            end
        end
        """)

    @info "readline() from pseudoterminal with fragmented writes."
    env = merge(ENV, Dict("JULIA_UNIX_IO_DEBUG_LEVEL" => "0",
                          "JULIA_DEBUG" => ""))
    UnixIO.ptopen(`$(Base.julia_cmd()) $jlfile`; env=env, opts...) do cin, cout
        @info "ptopen" cin cout
        cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
        cin=IOTraits.BaseIO(cin)
        @info "ptopen BaseIO" cin cout
    ptdump(Base.julia_cmd(), cin, cout) do fin, fout

        function wait_for(x)
            while true
                l = fin()
                if l == nothing
                    sleep(1)
                elseif contains(l, x)
                    return
                end
            end
        end

        function fin_check_error()
            l = fin()
            if l != nothing && contains(l, "Error in pty client")
                wait_for("Error done.")
            end
            l
        end

        wait_for("go!")

        fout("Hello1\n")
        @test fin_check_error() == """7:"Hello1\\n":0\n"""

        fout("Hello2\n")
        @test fin_check_error() == """7:"Hello2\\n":0\n"""

        fout("Hel")

        # Even after draining and waiting, the client read() has not returned
        # because of canonical mode.
        @test fin_check_error() == nothing
        fout("lo3\n")
        @test fin_check_error() == """7:"Hello3\\n":0\n"""

        # `CEOF` and sends a line with no "\n" (e.g. like the "bash$ " prompt)
        fout("Hello4")
        fout([UInt8(C.CEOF)])
        @test fin_check_error() == """6:"Hello4":0\n"""
        fout("Hello5\x04Hello6\n")
        @test fin_check_error() == """6:"Hello5":0\n"""
        @test fin_check_error() == """7:"Hello6\\n":0\n"""

        fout("Hello7\r")
        @test fin_check_error() == nothing
        fout("\x04")
        @test fin_check_error() == """7:"Hello7\\r":0\n"""
    end
    end
end

@info "Testing with C blocking read(2) from C-code"
mktempdir() do d
    cfile=joinpath(d, "tmp.c")
    write(cfile, """
        #include <stdio.h>
        #include <stdlib.h>
        #include <unistd.h>
        #include <string.h>
        #include <sys/socket.h>

        #define LEN 100

        int main()
        {
            for(;;) {
                char buf[LEN];
                int n = read(0, buf, LEN);
                if (n == -1) {
                    perror("Exiting");
                    exit(0);
                }
                printf("%d:", n);
                for (int i = 0 ; i < n ; i++) {
                    if (buf[i] == '\\n') {
                        printf("\\\\n");
                    } else {
                        printf("%c", buf[i]);
                    }
                }
                printf("\\n");
                fflush(stdout);
            }
        }
        """)
    binfile=joinpath(d, "tmp")
    UnixIO.system("gcc -o $binfile $cfile")

    @info "readline() from pseudoterminal with fragmented writes."
    UnixIO.ptopen(`$binfile`; opts...) do cin, cout
        cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
        cin=IOTraits.BaseIO(cin)
        write(cin, "Hello1\n")
        @test readline(cout; keep=true) == "7:Hello1\\n\n"
        write(cin, "Hello2\n")
        @test readline(cout; keep=true) == "7:Hello2\\n\n"

        write(cin, "Hel")
        UnixIO.@cerr C.tcdrain(cin.stream.fd)

        # Even after draining and waiting, the client read() has not returned
        # because of canonical mode.
        @test readline(cout; keep=true, timeout=1) == ""
        write(cin, "lo3\n")
        @test readline(cout; keep=true) == "7:Hello3\\n\n"

        write(cin, "Hello4\nHel")
        @test readline(cout; keep=true) == "7:Hello4\\n\n"

        @test readline(cout; keep=true, timeout=1) == ""
        write(cin, "lo5\n")
        @test readline(cout; keep=true) == "7:Hello5\\n\n"
    end

    @info "readline() from socket with fragmented writes."
    UnixIO.open(`$binfile`; opts...) do cin, cout
        cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
        cin=IOTraits.BaseIO(cin)
        write(cin, "Hello1\n")
        @test readline(cout; keep=true) == "7:Hello1\\n\n"
        write(cin, "Hello2\n")
        @test readline(cout; keep=true) == "7:Hello2\\n\n"
        write(cin, "Hel")
        @test readline(cout; keep=true, timeout=1) == "3:Hel\n"
        write(cin, "lo3\n")
        @test readline(cout; keep=true) == "4:lo3\\n\n"

        write(cin, "Hello4\nHel")
        @test readline(cout; keep=true) == "10:Hello4\\nHel\n"

        @test readline(cout; keep=true, timeout=1) == ""
        write(cin, "lo5\n")
        @test readline(cout; keep=true) == "4:lo5\\n\n"
    end
end

@info "readline() from pseudoterminal with fragmented writes."
mktempdir() do d
    cfile=joinpath(d, "tmp.c")
    write(cfile, """
        #include <stdlib.h>
        #include <unistd.h>
        #include <string.h>

        void write_s(char* s) {
            write(1, s, strlen(s));
        }

        int main()
        {
            sleep(1);
            write_s("Hel");
            sleep(1);
            write_s("lo1\\r\\n");
            write_s("Hello2\\r");
            sleep(1);
            write_s("\\nHello3");
            exit(0);
        }
        """)
    binfile=joinpath(d, "tmp")
    UnixIO.system("gcc -o $binfile $cfile")
    UnixIO.ptopen(`$binfile`; opts...) do cin, cout
        cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
        cin=IOTraits.BaseIO(cin)
        @test readline(cout; keep=true) == "Hello1\r\n"
        @test readline(cout; keep=true) == "Hello2\r\n"
        @test readline(cout; keep=true) == "Hello3"
    end
end



@info "readline() from pseudoterminal with fragmented writes (via bash)."
bash = "echo -n 'Hel'               ;" *
       "sleep 1                     ;" * 
       "echo -n 'lo1\r\nHello2\r'   ;" * 
       "sleep 1                     ;" *
       "echo -n '\nHello3'          ;"
UnixIO.ptopen(`bash -c "$bash"`; opts...) do cin, cout
    cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
    cin=IOTraits.BaseIO(cin)
    @test readline(cout) == "Hello1"
    @test readline(cout) == "Hello2"
    @test readline(cout) == "Hello3"
end




@info "readline() from socket with fragmented packets."
UnixIO.open(`cat`; opts...) do cin, cout
    cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
    cin=IOTraits.BaseIO(cin)

    write(cin, "Hello1\nHel")
    @test readline(cout) == "Hello1"

    # In socket mode, the partial line is in the fd buffer.
    @test String(take!(copy(cout.stream.buffer))) == "Hel"

    write(cin, "lo2")
    r = Ref{Any}(nothing)
    @sync begin
        @async r[] = readline(cout)
        sleep(1)

        # readline() is waiting for the end of line.
        @test r[] == nothing
        close(cin)
    end

    # After close(), readline() compeltes.
    @test r[] == "Hello2"
end


@info "readline() from pseudoterminal with fragmented writes (via cat)."
UnixIO.ptopen(`cat`; opts...) do cin, cout
    cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
    cin=IOTraits.BaseIO(cin)
    @sync begin
        @async begin
            write(cin, "Hello0\nHello1\nHel")
            sleep(0.1)
            write(cin, "lo2\n")
            sleep(0.1)
            write(cin, "Hello3\nHel")
            write(cin, UInt8(C.CEOF)) # Terminate partial line.
            write(cin, UInt8(C.CEOF)) # Singal end of file
        end
        @test readline(cout; keep=true) == "Hello0\n"
        # In canonical mode, the partial "Hel" line is buffered by the OS
        # in cat's output buffer so only "Hello2\n" line is in the fd buffer.
        @test bytesavailable(cout.stream.buffer) == 7
        @test String(take!(copy(cout.stream.buffer))) == "Hello1\n"
        @test readline(cout; keep=true) == "Hello1\n"
        @test bytesavailable(cout.stream.buffer) == 0
        @test readline(cout; keep=true) == "Hello2\n"
        @test readline(cout; keep=true) == "Hello3\n"
        # At end of transmission the partial line is returned:
        @test readline(cout; keep=true) == "Hel"
    end
end

@info "readline() from pseudoterminal non-canonlical mode."
UnixIO.ptopen(`cat`; opts...) do cin, cout
        
    UnixIO.tcsetattr(a -> a.c_lflag = 0, cout) # not C.ICANON
    cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
    cin=IOTraits.BaseIO(cin)
    
    @sync begin
        @async begin
            write(cin, "Hello0\nHello1\nHel")
            sleep(0.1)
            write(cin, "lo2")
            sleep(0.1)
            write(cin, UInt8(C.CEOF))
            sleep(0.1)
            write(cin, "Hello3\nHel")
            close(cin)
        end
        @test readline(cout; keep=true) == "Hello0\n"
        @test readline(cout; keep=true) == "Hello1\n"
        # In non canonical mode, the partial line is in the fd buffer:
        @test bytesavailable(cout.stream.buffer) == 3
        # `CEOF` and sends a line with no "\n" (e.g. like the "bash$ " prompt)
        @test readline(cout; keep=true) == "Hello2\x04Hello3\n"
        # At end of transmission the partial line is returned:
        @test readline(cout; keep=true, timeout=1) == "Hel"
    end
end


hexdump_output = "00000000  48 65 6c 6c 6f 0a 48 65  6c 6c 6f 0a              |Hello.Hello.|\n0000000c\n"

@info "Short hexdump via socketpair."
p, out = UnixIO.open(`hexdump -C`; opts...) do cin, cout
    cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
    cin=IOTraits.BaseIO(cin)
    write(cin, "Hello\nHello\n")
    close(cin)
    read(cout, String)
end
@test out == hexdump_output

@info "Short hexdump via pseudoterminal."
p, out = UnixIO.ptopen(`hexdump -C`; opts...) do cin, cout
    cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
    cin=IOTraits.BaseIO(cin)
    println(cin, "Hello")
    println(cin, "Hello")
    close(cin)
    read(cout, String)
end
@test out == hexdump_output

@info "Short pseudoterminal hexdump, read before writet."
p, out = UnixIO.ptopen(`hexdump -C`; opts...) do cin, cout
    cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
    cin=IOTraits.BaseIO(cin)
    @sync begin
        @async begin
            println(cin, "Hello")
            println(cin, "Hello")
            close(cin)
        end
        read(cout, String)
    end
end
@test out == hexdump_output

@info "Short pseudoterminal hexdump, interleaved read/write."
p, out = UnixIO.ptopen(`hexdump -C`; opts...) do cin, cout
    cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
    cin=IOTraits.BaseIO(cin)
    @sync begin
        println(cin, "Hello")
        @async begin
            println(cin, "Hello")
            close(cin)
        end
        read(cout, String)
    end
end
@test out == hexdump_output


@info "Interactive bash script via pseudoterminal."
UnixIO.ptopen(`bash`; opts...) do cin, cout
    cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
    cin=IOTraits.BaseIO(cin)
    ptdump(`bash`, cin, cout) do fin, fout
        # Wait for "bash-3.2$" prompt.
        while !contains(fin(), r"\$") end

        fout(raw"""i=1""" * "\n")                 ; @test contains(fin(), r"\$")
        fout(raw"""while [ $i -lt 11 ]""" * "\n") ; @test endswith(fin(), "> ")
        fout(raw"""do""" * "\n")                  ; @test endswith(fin(), "> ")
        fout(raw"""    sleep 0.2""" * "\n")       ; @test endswith(fin(), "> ")
        fout(raw"""    echo "COUNT$i" """ * "\n") ; @test endswith(fin(), "> ")
        fout(raw"""    i=$(($i+1))""" * "\n")     ; @test endswith(fin(), "> ")
        fout(raw"""done""" * "\n")

        for i in 1:10
            @test endswith(fin(), "COUNT$i\n")
        end
        @test contains(fin(), r"\$")
    end
end


@info "Interactive julia script via pseudoterminal."
env = merge(ENV, Dict("TERM" => "dumb"))

UnixIO.ptopen(`$(Base.julia_cmd()) --color=yes`; env=env) do cin, cout
    cout=IOTraits.BaseIO(IOTraits.LazyBufferedInput(cout))
    cin=IOTraits.BaseIO(cin)

    ptdump(Base.julia_cmd(), cin, cout) do fin, fout

        # Wait for "julia>" prompt.
        while !contains(fin(), r"julia> ") end

        fout(raw"""ENV["TERM"]""" * "\n")
        @test fin() == "\"dumb\"\n"
        @test fin() == "\n"
        @test fin() == "julia> "

        fout(raw"""i=1""" * "\n")
        @test fin() == "1\n"
        @test fin() == "\n"
        @test fin() == "julia> "

        fout(raw"""while i < 11""" * "\n")
        fout(raw"""    sleep(0.2)""" * "\n")
        fout(raw"""    println("COUNT$i")""" * "\n")
        fout(raw"""    i += 1""" * "\n")
        fout(raw"""end""" * "\n")

        for i in 1:10
            @test fin() == "COUNT$i\n"
        end
        @test fin() == "\n"
        @test fin() == "julia> "
    end
end


end # @testset "Pseudoterminal Tests"
