; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -O0 -mcpu=gfx1030 < %s | FileCheck %s

target triple = "amdgcn-amd-amdhsa"

; Unknown functions are conservatively passed all implicit parameters
declare void @unknown_call()
; Use the same constant as a sgpr parameter (for the kernel id) and for a vector operation
define protected amdgpu_kernel void @kern(ptr %addr) !llvm.amdgcn.lds.kernel.id !0 {
; CHECK-LABEL: kern:
; CHECK:       ; %bb.0:
; CHECK-NEXT:    s_mov_b32 s32, 0
; CHECK-NEXT:    s_add_u32 s10, s10, s15
; CHECK-NEXT:    s_addc_u32 s11, s11, 0
; CHECK-NEXT:    s_setreg_b32 hwreg(HW_REG_FLAT_SCR_LO), s10
; CHECK-NEXT:    s_setreg_b32 hwreg(HW_REG_FLAT_SCR_HI), s11
; CHECK-NEXT:    s_add_u32 s0, s0, s15
; CHECK-NEXT:    s_addc_u32 s1, s1, 0
; CHECK-NEXT:    s_mov_b64 s[10:11], s[8:9]
; CHECK-NEXT:    s_load_dwordx2 s[8:9], s[6:7], 0x0
; CHECK-NEXT:    v_mov_b32_e32 v5, 42
; CHECK-NEXT:    s_waitcnt lgkmcnt(0)
; CHECK-NEXT:    v_mov_b32_e32 v3, s8
; CHECK-NEXT:    v_mov_b32_e32 v4, s9
; CHECK-NEXT:    flat_store_dword v[3:4], v5
; CHECK-NEXT:    s_mov_b64 s[16:17], 8
; CHECK-NEXT:    s_mov_b32 s8, s6
; CHECK-NEXT:    s_mov_b32 s6, s7
; CHECK-NEXT:    s_mov_b32 s9, s16
; CHECK-NEXT:    s_mov_b32 s7, s17
; CHECK-NEXT:    s_add_u32 s8, s8, s9
; CHECK-NEXT:    s_addc_u32 s6, s6, s7
; CHECK-NEXT:    ; kill: def $sgpr8 killed $sgpr8 def $sgpr8_sgpr9
; CHECK-NEXT:    s_mov_b32 s9, s6
; CHECK-NEXT:    s_getpc_b64 s[6:7]
; CHECK-NEXT:    s_add_u32 s6, s6, unknown_call@gotpcrel32@lo+4
; CHECK-NEXT:    s_addc_u32 s7, s7, unknown_call@gotpcrel32@hi+12
; CHECK-NEXT:    s_load_dwordx2 s[16:17], s[6:7], 0x0
; CHECK-NEXT:    s_mov_b64 s[22:23], s[2:3]
; CHECK-NEXT:    s_mov_b64 s[20:21], s[0:1]
; CHECK-NEXT:    s_mov_b32 s6, 20
; CHECK-NEXT:    v_lshlrev_b32_e64 v2, s6, v2
; CHECK-NEXT:    s_mov_b32 s6, 10
; CHECK-NEXT:    v_lshlrev_b32_e64 v1, s6, v1
; CHECK-NEXT:    v_or3_b32 v31, v0, v1, v2
; CHECK-NEXT:    ; implicit-def: $sgpr6_sgpr7
; CHECK-NEXT:    s_mov_b32 s15, 42
; CHECK-NEXT:    s_mov_b64 s[0:1], s[20:21]
; CHECK-NEXT:    s_mov_b64 s[2:3], s[22:23]
; CHECK-NEXT:    s_waitcnt lgkmcnt(0)
; CHECK-NEXT:    s_swappc_b64 s[30:31], s[16:17]
; CHECK-NEXT:    s_endpgm
  store i32 42, ptr %addr
  call fastcc void @unknown_call()
  ret void
}

!0 = !{i32 42}
