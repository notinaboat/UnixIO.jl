using Clang.Generators
using Liburing_jll

cd(@__DIR__)

include_dir = normpath(Liburing_jll.artifact_dir, "include")

build!(Generators.create_context(
    [
        joinpath(include_dir, "liburing.h")
    ],
    [
        get_default_args();
        "-I$include_dir"
    ],
    Dict{String,Any}(
        "general" => Dict{String,Any}(
            "output_file_path" => "../src/generated.jl",
            "extract_c_comment_style" => "raw",
            "auto_mutability" => true,
            "library_name" => "liburing"
        ),
        "codegen" => Dict{String,Any}(
            "use_ccall_macro" => true
        ),
    )
))
