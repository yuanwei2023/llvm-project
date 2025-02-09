; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -O3 < %s | FileCheck %s

target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-unknown"

; Check that we don't crash on handling of various types of constants
; (including non-integer constants)
define void @test_legal_constants() gc "statepoint-example" {
; CHECK-LABEL: test_legal_constants:
; CHECK:       # %bb.0:
; CHECK-NEXT:    pushq %rax
; CHECK-NEXT:    .cfi_def_cfa_offset 16
; CHECK-NEXT:    callq foo@PLT
; CHECK-NEXT:  .Ltmp0:
; CHECK-NEXT:    popq %rax
; CHECK-NEXT:    .cfi_def_cfa_offset 8
; CHECK-NEXT:    retq
  %statepoint_token = call token (i64, i32, void ()*, i32, i32, ...) @llvm.experimental.gc.statepoint.p0f_isVoidf(i64 2882400000, i32 0, void ()* elementtype(void ()) @foo, i32 0, i32 2, i32 0, i32 0) #0 [ "deopt" (float 2.0, double 3.0, i8 5, i16 22, i32 8, i64 9, i8 addrspace(1)* null) ]
  ret void
}

; Ensure we can allocate and assign values in registers for each type
define void @test_registers(float %v1, double %v2, i8 %v3, i16 %v4, i32 %v5, i64 %v6, i8 addrspace(1)* %v7) gc "statepoint-example" {
; CHECK-LABEL: test_registers:
; CHECK:       # %bb.0:
; CHECK-NEXT:    pushq %rax
; CHECK-NEXT:    .cfi_def_cfa_offset 16
; CHECK-NEXT:    movq %r8, (%rsp)
; CHECK-NEXT:    callq foo@PLT
; CHECK-NEXT:  .Ltmp1:
; CHECK-NEXT:    popq %rax
; CHECK-NEXT:    .cfi_def_cfa_offset 8
; CHECK-NEXT:    retq
  %statepoint_token = call token (i64, i32, void ()*, i32, i32, ...) @llvm.experimental.gc.statepoint.p0f_isVoidf(i64 2882400000, i32 0, void ()* elementtype(void ()) @foo, i32 0, i32 2, i32 0, i32 0) #0 [ "deopt" (float %v1, double %v2, i8 %v3, i16 %v4, i32 %v5, i64 %v6, i8 addrspace(1)* %v7) ]
  ret void
}

; For constants which definitely *don't* fit in registers, can we still
; encode them in the stackmap?
define void @test_illegal_constants() gc "statepoint-example" {
; CHECK-LABEL: test_illegal_constants:
; CHECK:       # %bb.0:
; CHECK-NEXT:    subq $248, %rsp
; CHECK-NEXT:    .cfi_def_cfa_offset 256
; CHECK-NEXT:    xorps %xmm0, %xmm0
; CHECK-NEXT:    movaps %xmm0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movq $0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movq $144, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movq $0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movq $144, (%rsp)
; CHECK-NEXT:    movq $0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movq $144, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movq $0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movq $144, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    callq foo@PLT
; CHECK-NEXT:  .Ltmp2:
; CHECK-NEXT:    addq $248, %rsp
; CHECK-NEXT:    .cfi_def_cfa_offset 8
; CHECK-NEXT:    retq
  %statepoint_token = call token (i64, i32, void ()*, i32, i32, ...) @llvm.experimental.gc.statepoint.p0f_isVoidf(i64 2882400000, i32 0, void ()* elementtype(void ()) @foo, i32 0, i32 2, i32 0, i32 0) #0 [ "deopt" (i128 144, i256 144, i512 144, i1024 144) ]
  ret void
}

; Ensure we don't crash w/a value which can't fit in a
; register, and must be spilled.
define void @test_illegal_values(i128 %v1, i256 %v2, i512 %v3, i1024 %v4) gc "statepoint-example" {
; CHECK-LABEL: test_illegal_values:
; CHECK:       # %bb.0:
; CHECK-NEXT:    subq $248, %rsp
; CHECK-NEXT:    .cfi_def_cfa_offset 256
; CHECK-NEXT:    movaps {{[0-9]+}}(%rsp), %xmm0
; CHECK-NEXT:    movaps {{[0-9]+}}(%rsp), %xmm1
; CHECK-NEXT:    movaps {{[0-9]+}}(%rsp), %xmm2
; CHECK-NEXT:    movaps {{[0-9]+}}(%rsp), %xmm3
; CHECK-NEXT:    movaps {{[0-9]+}}(%rsp), %xmm4
; CHECK-NEXT:    movaps {{[0-9]+}}(%rsp), %xmm5
; CHECK-NEXT:    movaps {{[0-9]+}}(%rsp), %xmm6
; CHECK-NEXT:    movaps {{[0-9]+}}(%rsp), %xmm7
; CHECK-NEXT:    movaps {{[0-9]+}}(%rsp), %xmm8
; CHECK-NEXT:    movaps {{[0-9]+}}(%rsp), %xmm9
; CHECK-NEXT:    movaps {{[0-9]+}}(%rsp), %xmm10
; CHECK-NEXT:    movaps {{[0-9]+}}(%rsp), %xmm11
; CHECK-NEXT:    movq %r9, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movq %r8, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movq %rcx, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movq %rdx, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movq %rsi, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movq %rdi, (%rsp)
; CHECK-NEXT:    movaps %xmm11, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm10, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm9, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm8, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm7, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm6, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm5, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm4, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm3, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm2, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm1, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    movaps %xmm0, {{[0-9]+}}(%rsp)
; CHECK-NEXT:    callq foo@PLT
; CHECK-NEXT:  .Ltmp3:
; CHECK-NEXT:    addq $248, %rsp
; CHECK-NEXT:    .cfi_def_cfa_offset 8
; CHECK-NEXT:    retq
  %statepoint_token = call token (i64, i32, void ()*, i32, i32, ...) @llvm.experimental.gc.statepoint.p0f_isVoidf(i64 2882400000, i32 0, void ()* elementtype(void ()) @foo, i32 0, i32 2, i32 0, i32 0) #0 [ "deopt" (i128 %v1, i256 %v2, i512 %v3, i1024 %v4) ]
  ret void
}


;; TODO: Add a test for illegal register values (i.e. spilling).  A
;; trivial one currently crashes.

declare void @foo()

declare token @llvm.experimental.gc.statepoint.p0f_isVoidf(i64 , i32 , void ()*, i32 , i32 , ...)

attributes #0 = { "deopt-lowering"="live-in" }
