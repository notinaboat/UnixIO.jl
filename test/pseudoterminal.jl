using Test
using UnixIO
using AsyncLog
using LoggingTestSets

@testset LoggingTestSet "Pseudoterminal Tests" begin

opts = (check_status=false,)

@info "readline() from socket spanning packets."
UnixIO.open(`cat`; opts...) do cin, cout
    @sync begin
        @async begin
            write(cin, "Hello1\nHel")
            sleep(0.1)
            write(cin, "lo2")
            close(cin)
        end
        @test readline(cout) == "Hello1"
        # In socket mode, the partial line is in the fd buffer.
        @test String(take!(copy(cout.buffer))) == "Hel"
        @test readline(cout) == "Hello2"
    end
end

@info "readline() from pseudoterminal with fragmented writes."
UnixIO.ptopen(`cat`; opts...) do cin, cout
    @sync begin
        @async begin
            write(cin, "Hello0\nHello1\nHel")
            sleep(0.1)
            write(cin, "lo2")
            sleep(0.1)
            write(cin, UInt8(C.CEOF))
            sleep(0.1)
            write(cin, "Hello3\nHel")
            write(cin, UInt8(C.CEOF))
        end
        @test readline(cout; keep=true) == "Hello0\n"
        @test readline(cout; keep=true) == "Hello1\n"
        # In canonical mode, the partial line is buffered by the OS:
        @test bytesavailable(cout.buffer) == 0
        # `CEOF` and sends a line with no "\n" (e.g. like the "bash$ " prompt)
        @test readline(cout; keep=true) == "Hello2"
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


hexdump_output = "0000000 48 65 6c 6c 6f 0a 48 65 6c 6c 6f 0a            \n000000c\n"

@info "Short hexdump via socketpair."
@test UnixIO.open(`hexdump`; opts...) do cin, cout
    write(cin, "Hello\nHello\n")
    close(cin)
    read(cout, String)
end == (0, hexdump_output)

@info "Short hexdump via pseudoterminal."
@test UnixIO.ptopen(`hexdump`; opts...) do cin, cout
    println(cin, "Hello")
    println(cin, "Hello")
    close(cin)
    read(cout, String)
end == (0, hexdump_output)

@info "Short pseudoterminal hexdump, read before writet."
@test UnixIO.ptopen(`hexdump`; opts...) do cin, cout
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
@test UnixIO.ptopen(`hexdump`; opts...) do cin, cout
    @sync begin
        println(cin, "Hello")
        @async begin
            println(cin, "Hello")
            close(cin)
        end
        read(cout, String)
    end
end == (0, hexdump_output)

function ptdump(f, cin, cout)

    println("   ┌")
    pad =   "   │ "

    function next()
        x = readline(cout; keep=true)
        print(pad * x)
        x
    end

    function type(x)
        for c in x * "\n"
            write(cin, c)
            print(c)
            sleep(0.05 * rand())
        end
    end

    f(next, type)

    println("\n   └")
end

@info "Interactive bash script via pseudoterminal."
UnixIO.ptopen(`bash`; opts...) do cin, cout
    ptdump(cin, cout) do fin, fout
        # Wait for "bash-3.2$" prompt.
        while !contains(fin(), r"bash.*\$") end

        fout(raw"""i=1""")                 ;
        @test contains(fin(), r"bash.*\$")
        fout(raw"""while [ $i -lt 11 ]""") ; @test fin() == "> "
        fout(raw"""do""")                  ; @test fin() == "> "
        fout(raw"""    sleep 0.2""")       ; @test fin() == "> "
        fout(raw"""    echo "COUNT$i" """) ; @test fin() == "> "
        fout(raw"""    i=$(($i+1))""")     ; @test fin() == "> "
        fout(raw"""done""")

        for i in 1:10
            @test fin() == "COUNT$i\n"
        end
        @test contains(fin(), r"bash.*\$")
    end
end



end # @testset "Pseudoterminal Tests"
