// Fixed Luau bytecode definitions to enable successful compilation
#pragma once

#include <stdint.h>

// Ensure these don't conflict with existing definitions
#ifndef LUAU_BYTECODE_DEFINITIONS
#define LUAU_BYTECODE_DEFINITIONS

// Define opcode extraction macros
#define LUAU_INSN_OP(insn) ((insn) & 0xFF)
#define LUAU_INSN_A(insn) (((insn) >> 8) & 0xFF)
#define LUAU_INSN_B(insn) (((insn) >> 16) & 0xFF)
#define LUAU_INSN_C(insn) (((insn) >> 24) & 0xFF)
#define LUAU_INSN_D(insn) (((insn) >> 16) & 0xFFFF)
#define LUAU_INSN_E(insn) (((insn) >> 8) & 0xFFFFFF)

// Common auxiliary type constructors
#define LUAU_INSN_AD(op, a, d) (((d) << 16) | ((a) << 8) | (op))
#define LUAU_INSN_ABC(op, a, b, c) (((c) << 24) | ((b) << 16) | ((a) << 8) | (op))
#define LUAU_INSN_ABx(op, a, bx) (((bx) << 16) | ((a) << 8) | (op))
#define LUAU_INSN_AsBx(op, a, sbx) (((sbx) << 16) | ((a) << 8) | (op))
#define LUAU_INSN_AsBxC(op, a, sbx, c) (((c) << 24) | ((sbx) << 16) | ((a) << 8) | (op))
#define LUAU_INSN_A(insn) (((insn) >> 8) & 0xFF)
#define LUAU_INSN_A5(insn) (((insn) >> 8) & 0x1F)

// Define bytecode opcodes - we need these for the VM code
enum LuauOpcode
{
    LOP_NOP,
    LOP_BREAK,
    LOP_LOADNIL,
    LOP_LOADB,
    LOP_LOADN,
    LOP_LOADK,
    LOP_MOVE,
    LOP_GETGLOBAL,
    LOP_SETGLOBAL,
    LOP_GETUPVAL,
    LOP_SETUPVAL,
    LOP_CLOSEUPVALS,
    LOP_GETIMPORT,
    LOP_GETTABLE,
    LOP_SETTABLE,
    LOP_GETTABLEKS,
    LOP_SETTABLEKS,
    LOP_GETTABLEN,
    LOP_SETTABLEN,
    LOP_NEWCLOSURE,
    LOP_NAMECALL,
    LOP_CALL,
    LOP_RETURN,
    LOP_JUMP,
    LOP_JUMPBACK,
    LOP_JUMPIF,
    LOP_JUMPIFNOT,
    LOP_JUMPIFEQ,
    LOP_JUMPIFLE,
    LOP_JUMPIFLT,
    LOP_JUMPIFNOTEQ,
    LOP_JUMPIFNOTLE,
    LOP_JUMPIFNOTLT,
    LOP_ADD,
    LOP_SUB,
    LOP_MUL,
    LOP_DIV,
    LOP_MOD,
    LOP_POW,
    LOP_ADDK,
    LOP_SUBK,
    LOP_MULK,
    LOP_DIVK,
    LOP_MODK,
    LOP_POWK,
    LOP_AND,
    LOP_OR,
    LOP_ANDK,
    LOP_ORK,
    LOP_CONCAT,
    LOP_NOT,
    LOP_MINUS,
    LOP_LENGTH,
    LOP_NEWTABLE,
    LOP_DUPTABLE,
    LOP_SETLIST,
    LOP_FORNUMP,
    LOP_FORNUMLOOP,
    LOP_FORGLOOP,
    LOP_FORGPREP_NEXT,
    LOP_FORGPREP_INEXT,
    LOP_FORGPREP_NEXT_INPLACE,
    LOP_DEP_FORGLOOP_INPLACE,
    LOP_FORGPREP,
    LOP_JUMPX,
    LOP_JUMPXEQKNIL,
    LOP_JUMPXEQKB,
    LOP_DEP_JUMPXEQKN,
    LOP_JUMPXEQKS,
    LOP_FASTCALL,
    LOP_FASTCALL1,
    LOP_FASTCALL2,
    LOP_FASTCALL2K,
    LOP_COVERAGE,
    LOP_CAPTURE,
    LOP_DEP_JUMPIFEQK,
    LOP_DEP_JUMPIFNOTEQK,
    LOP_JUMPIFNOT_NEXT,
    LOP_JUMPIF_NEXT,
    LOP_JUMPIFEQ_NEXT,
    LOP_JUMPIFLE_NEXT,
    LOP_JUMPIFLT_NEXT,
    LOP_JUMPIFNOTEQ_NEXT,
    LOP_JUMPIFNOTLE_NEXT,
    LOP_JUMPIFNOTLT_NEXT,
    LOP_GETVARARGS,
    LOP_DUPCLOSURE,
    LOP_PREPVARARGS,
    LOP_LOADKX,
    LOP_JUMPX_NEXT,
    LOP_FASTCALL1K
};

#endif // LUAU_BYTECODE_DEFINITIONS
