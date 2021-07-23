using Test
using UnixIO
using AsyncLog



opts = (check_status=false,)

for f in (
    () -> begin
        UnixIO.open(`hexdump`; opts...) do cin, cout
            write(cin, "Hello\nHello\n")
            close(cin)
            read(cout, String)
        end
    end,
    () -> begin()
        UnixIO.ptopen(`hexdump`; opts...) do cin, cout
            println(cin, "Hello")
            println(cin, "Hello")
            close(cin)
            read(cout, String)
        end
    end,
    () -> begin()
        UnixIO.ptopen(`hexdump`; opts...) do cin, cout
            @sync begin
                @async begin
                    println(cin, "Hello")
                    println(cin, "Hello")
                    close(cin)
                end
                read(cout, String)
            end
        end
    end,
    () -> begin()
        UnixIO.ptopen(`hexdump`; opts...) do cin, cout
            @sync begin
                println(cin, "Hello")
                @async begin
                    println(cin, "Hello")
                    close(cin)
                end
                read(cout, String)
            end
        end
    end)

    s, r = f()
    @test s == 0
    @test r == "0000000 48 65 6c 6c 6f 0a 48 65 6c 6c 6f 0a            \n000000c\n"
end

UnixIO.ptopen(`bash`; opts...) do cin, cout
    @sync begin
        # Wait for "bash-3.2$" prompt.
        next() = (x = readline(cout; timeout=0.1); println(x); x)
        while !contains(next(), r"bash.*\$") end

        println(cin, raw"""i=1""")                 ;
        @test contains(next(), r"bash.*\$")
        println(cin, raw"""while [ $i -lt 11 ]""") ; @test next() == "> "
        println(cin, raw"""do""")                  ; @test next() == "> "
        println(cin, raw"""    sleep 0.2""")       ; @test next() == "> "
        println(cin, raw"""    echo "COUNT$i" """) ; @test next() == "> "
        println(cin, raw"""    i=$(($i+1))""")     ; @test next() == "> "
        println(cin, raw"""done""")
        for i in 1:10
            @test (x = readline(cout); println(x); x) == "COUNT$i"
        end
        @test contains(next(), r"bash.*\$")
    end
end
