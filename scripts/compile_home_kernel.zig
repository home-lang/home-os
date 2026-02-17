// Compile Home kernel to assembly
// This script is called from the build process to compile main.home → main.s

const std = @import("std");

// Import Home compiler components
// We'll use relative paths to the Home compiler
const Lexer = @import("../../../home/packages/lexer/src/lexer.zig").Lexer;
const Parser = @import("../../../home/packages/parser/src/parser.zig").Parser;
const HomeKernelCodegen = @import("../../../home/packages/codegen/src/home_kernel_codegen.zig").HomeKernelCodegen;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    // Parse command line arguments
    var args_iter = std.process.Args.Iterator.init(init.minimal.args);
    const program_name = args_iter.next() orelse "compile_home_kernel";
    const input_file = args_iter.next() orelse {
        std.debug.print("Usage: {s} <input.home> <output.s>\n", .{program_name});
        std.process.exit(1);
    };
    const output_file = args_iter.next() orelse {
        std.debug.print("Usage: {s} <input.home> <output.s>\n", .{program_name});
        std.process.exit(1);
    };

    std.debug.print("Compiling Home kernel: {s} → {s}\n", .{ input_file, output_file });

    // Read input file
    const source = try std.Io.Dir.cwd().readFileAlloc(io, input_file, allocator, .limited(1024 * 1024));
    defer allocator.free(source);

    // Lex
    std.debug.print("  Lexing...\n", .{});
    var lexer = Lexer.init(allocator, source);
    const tokens = try lexer.tokenize();
    defer tokens.deinit(allocator);

    std.debug.print("  Parsed {} tokens\n", .{tokens.items.len});

    // Parse
    std.debug.print("  Parsing...\n", .{});
    var parser = try Parser.init(allocator, tokens.items);
    const program = try parser.parse();

    std.debug.print("  Parsed {} statements\n", .{program.statements.len});

    // Generate assembly
    std.debug.print("  Generating assembly...\n", .{});
    var codegen = HomeKernelCodegen.init(
        allocator,
        &parser.symbol_table,
        &parser.module_resolver,
    );
    defer codegen.deinit();

    const asm_code = try codegen.generate(program);

    std.debug.print("  Generated {} bytes of assembly\n", .{asm_code.len});

    // Write output
    try std.Io.Dir.cwd().writeFile(io, .{
        .sub_path = output_file,
        .data = asm_code,
    });

    std.debug.print("✓ Compilation successful!\n", .{});
}
