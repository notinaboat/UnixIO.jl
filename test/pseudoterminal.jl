using Test
using UnixIO
using UnixIO: dbstring
using AsyncLog
using LoggingTestSets
using Crayons

@testset LoggingTestSet "Pseudoterminal Tests" begin

function ptdump(f, cmd, cin, cout)

    color = crayon"bold fg:blue"

    println("┌ ", color, cmd, inv(color), ":")
    pad =   "│ "
    needpad = Ref(false)

    function fin(;wait=false)
        x = readline(cout; keep=true, wait=wait)
        print(pad)
        needpad[] = false
        print(x)
        x
    end

    function fout(x)
        if needpad[]
            print(pad)
        end
        for c in x * "\n"
            write(cin, c)
            print(c)
            sleep(0.05 * rand())
        end
        needpad[] = true
    end

    f(fin, fout)

    println("\n└")
end

opts = (check_status=false,)

@info "Testing with Julia UnixIO pty clinet"

mktempdir() do d
    jlfile=joinpath(d, "tmp.jl")
    write(jlfile, """
        using UnixIO
        io = UnixIO.stdin
        @assert io isa UnixIO.ReadFD{UnixIO.S_IFCHR}
        @assert !(io isa UnixIO.ReadFD{UnixIO.Pseudoterminal})
        println("go!")
        while true
            l = readline(io; keep=true)
            b = bytesavailable(io.buffer)
            UnixIO.println(length(l), ":", repr(l), ":", b)
        end
        """)

    @info "readline() from pseudoterminal with fragmented writes."
    UnixIO.ptopen(`julia $jlfile`; opts...) do cin, cout
        while readline(cout) != "go!" end
        write(cin, "Hello1\nHello2\n")
        @test readline(cout) == """7:"Hello1\\n":0"""
        @test readline(cout) == """7:"Hello2\\n":0"""

        write(cin, "Hel")
        UnixIO.@cerr C.tcdrain(cin.fd)

        # Even after draining and waiting, the client read() has not returned
        # because of canonical mode.
        @test readline(cout, timeout=1) == ""
        write(cin, "lo3\n")
        @test readline(cout) == """7:"Hello3\\n":0"""

        # `CEOF` and sends a line with no "\n" (e.g. like the "bash$ " prompt)
        write(cin, "Hello4")
        write(cin, UInt8(C.CEOF))
        @test readline(cout) == """6:"Hello4":0"""
        write(cin, "Hello5\x04Hello6\n")
        @test readline(cout) == """6:"Hello5":0"""
        @test readline(cout) == """7:"Hello6\\n":0"""

        write(cin, "Hello7\r")
        @test readline(cout, timeout=1) == ""
        write(cin, UInt8(C.CEOF))
        @test readline(cout) == """7:"Hello7\\r":0"""
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
        write(cin, "Hello1\n")
        @test readline(cout; keep=true) == "7:Hello1\\n\n"
        write(cin, "Hello2\n")
        @test readline(cout; keep=true) == "7:Hello2\\n\n"

        write(cin, "Hel")
        UnixIO.@cerr C.tcdrain(cin.fd)

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
    @test readline(cout) == "Hello1"
    @test readline(cout) == "Hello2"
    @test readline(cout) == "Hello3"
end




@info "readline() from socket with fragmented packets."
UnixIO.open(`cat`; opts...) do cin, cout

    write(cin, "Hello1\nHel")
    @test readline(cout) == "Hello1"

    # In socket mode, the partial line is in the fd buffer.
    @test String(take!(copy(cout.buffer))) == "Hel"

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
        # In canonical mode, the parial "Hel" line is buffered by the OS
        # in cat's output buffer so only "Hello2\n" line is in the fd buffer.
        @test bytesavailable(cout.buffer) == 7
        @test String(take!(copy(cout.buffer))) == "Hello1\n"
        @test readline(cout; keep=true) == "Hello1\n"
        @test bytesavailable(cout.buffer) == 0
        @test readline(cout; keep=true) == "Hello2\n"
        @test readline(cout; keep=true) == "Hello3\n"
        # At end of transmission the partial line is returned:
        @test readline(cout; keep=true) == "Hel"
    end
end

@info "readline() from pseudoterminal non-canonlical mode."
UnixIO.ptopen(`cat`; opts...) do cin, cout
        
    UnixIO.tcsetattr(cout; lflag = 0) # not C.ICANON
    
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
        @test bytesavailable(cout.buffer) == 3
        # `CEOF` and sends a line with no "\n" (e.g. like the "bash$ " prompt)
        @test readline(cout; keep=true) == "Hello2\x04Hello3\n"
        # At end of transmission the partial line is returned:
        @test readline(cout; keep=true, timeout=1) == "Hel"
    end
end


hexdump_output = "00000000  48 65 6c 6c 6f 0a 48 65  6c 6c 6f 0a              |Hello.Hello.|\n0000000c\n"

@info "Short hexdump via socketpair."
@test UnixIO.open(`hexdump -C`; opts...) do cin, cout
    write(cin, "Hello\nHello\n")
    close(cin)
    read(cout, String)
end == (0, hexdump_output)

@info "Short hexdump via pseudoterminal."
@test UnixIO.ptopen(`hexdump -C`; opts...) do cin, cout
    println(cin, "Hello")
    println(cin, "Hello")
    close(cin)
    read(cout, String)
end == (0, hexdump_output)

@info "Short pseudoterminal hexdump, read before writet."
@test UnixIO.ptopen(`hexdump -C`; opts...) do cin, cout
    @sync begin
        @async begin
            println(cin, "Hello")
            println(cin, "Hello")
            close(cin)
        end
        read(cout, String)
    end
end == (0, hexdump_output)

@info "Short pseudoterminal hexdump, interleaved read/write."
@test UnixIO.ptopen(`hexdump -C`; opts...) do cin, cout
    @sync begin
        println(cin, "Hello")
        @async begin
            println(cin, "Hello")
            close(cin)
        end
        read(cout, String)
    end
end == (0, hexdump_output)


@info "Interactive bash script via pseudoterminal."
#env = merge(ENV, Dict("TERM" => "dumb"))
UnixIO.ptopen(`bash`; opts...) do cin, cout
    ptdump(`bash`, cin, cout) do fin, fout
        # Wait for "bash-3.2$" prompt.
        while !contains(fin(), r"\$") end

        fout(raw"""i=1""")                 ;
        @test contains(fin(), r"\$")
        fout(raw"""while [ $i -lt 11 ]""") ; @test fin() == "> "
        fout(raw"""do""")                  ; @test fin() == "> "
        fout(raw"""    sleep 0.2""")       ; @test fin() == "> "
        fout(raw"""    echo "COUNT$i" """) ; @test fin() == "> "
        fout(raw"""    i=$(($i+1))""")     ; @test fin() == "> "
        fout(raw"""done""")

        for i in 1:10
            @test fin(wait=true) == "COUNT$i\n"
        end
        @test contains(fin(), r"\$")
    end
end


@info "Interactive julia script via pseudoterminal."
env = merge(ENV, Dict("TERM" => "dumb"))

UnixIO.ptopen(`julia --color=yes`; env=env) do cin, cout

    ptdump(`julia`, cin, cout) do fin, fout

        # Wait for "julia>" prompt.
        while !contains(fin(), r"julia> ") end

        fout(raw"""ENV["TERM"]""")
        @test fin(wait=true) == "\"dumb\"\n"
        @test fin() == "\n"
        @test fin() == "julia> "

        fout(raw"""i=1""")
        @test fin(wait=true) == "1\n"
        @test fin(wait=true) == "\n"
        @test fin() == "julia> "

        fout(raw"""while i < 11""")
        fout(raw"""    sleep(0.2)""")
        fout(raw"""    println("COUNT$i")""")
        fout(raw"""    i += 1""")
        fout(raw"""end""")

        for i in 1:10
            @test fin(wait=true) == "COUNT$i\n"
        end
        @test fin(wait=true) == "\n"
        @test fin() == "julia> "
    end
end


end # @testset "Pseudoterminal Tests"
