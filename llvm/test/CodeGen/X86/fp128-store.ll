; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -O2 -mtriple=x86_64-linux-android -mattr=+mmx | FileCheck %s
; RUN: llc < %s -O2 -mtriple=x86_64-linux-gnu -mattr=+mmx | FileCheck %s

; __float128 myFP128 = 1.0L;  // x86_64-linux-android
@myFP128 = dso_local global fp128 0xL00000000000000003FFF000000000000, align 16

define dso_local void @set_FP128(fp128 %x) {
; CHECK-LABEL: set_FP128:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    movaps %xmm0, myFP128(%rip)
; CHECK-NEXT:    retq
entry:
  store fp128 %x, fp128* @myFP128, align 16
  ret void
}
