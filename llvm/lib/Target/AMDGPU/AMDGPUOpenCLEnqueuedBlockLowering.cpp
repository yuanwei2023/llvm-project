//===- AMDGPUOpenCLEnqueuedBlockLowering.cpp - Lower enqueued block -------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// \file
// This post-linking pass replaces the function pointer of enqueued
// block kernel with a global variable (runtime handle) and adds
// "runtime-handle" attribute to the enqueued block kernel.
//
// In LLVM CodeGen the runtime-handle metadata will be translated to
// RuntimeHandle metadata in code object. Runtime allocates a global buffer
// for each kernel with RuntimeHandle metadata and saves the kernel address
// required for the AQL packet into the buffer. __enqueue_kernel function
// in device library knows that the invoke function pointer in the block
// literal is actually runtime handle and loads the kernel address from it
// and put it into AQL packet for dispatching.
//
// This cannot be done in FE since FE cannot create a unique global variable
// with external linkage across LLVM modules. The global variable with internal
// linkage does not work since optimization passes will try to replace loads
// of the global variable with its initialization value.
//
// It also identifies the kernels directly or indirectly enqueues kernels
// and adds "calls-enqueue-kernel" function attribute to them, which will
// be used to determine whether to emit runtime metadata for the kernel
// enqueue related hidden kernel arguments.
//
//===----------------------------------------------------------------------===//

#include "AMDGPU.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Mangler.h"
#include "llvm/IR/Module.h"
#include "llvm/Pass.h"
#include "llvm/Support/Debug.h"

#define DEBUG_TYPE "amdgpu-lower-enqueued-block"

using namespace llvm;

namespace {

/// Lower enqueued blocks.
class AMDGPUOpenCLEnqueuedBlockLowering : public ModulePass {
public:
  static char ID;

  explicit AMDGPUOpenCLEnqueuedBlockLowering() : ModulePass(ID) {}

private:
  bool runOnModule(Module &M) override;
};

} // end anonymous namespace

char AMDGPUOpenCLEnqueuedBlockLowering::ID = 0;

char &llvm::AMDGPUOpenCLEnqueuedBlockLoweringID =
    AMDGPUOpenCLEnqueuedBlockLowering::ID;

INITIALIZE_PASS(AMDGPUOpenCLEnqueuedBlockLowering, DEBUG_TYPE,
                "Lower OpenCL enqueued blocks", false, false)

ModulePass* llvm::createAMDGPUOpenCLEnqueuedBlockLoweringPass() {
  return new AMDGPUOpenCLEnqueuedBlockLowering();
}

/// Collect direct or indirect callers of \p F and save them
/// to \p Callers.
static void collectCallers(Function *F, DenseSet<Function *> &Callers) {
  for (auto *U : F->users()) {
    if (auto *CI = dyn_cast<CallInst>(&*U)) {
      auto *Caller = CI->getParent()->getParent();
      if (Callers.insert(Caller).second)
        collectCallers(Caller, Callers);
    }
  }
}

/// If \p U is instruction or constant, collect functions which directly or
/// indirectly use it.
static void collectFunctionUsers(User *U, DenseSet<Function *> &Funcs) {
  if (auto *I = dyn_cast<Instruction>(U)) {
    auto *F = I->getParent()->getParent();
    if (Funcs.insert(F).second)
      collectCallers(F, Funcs);
    return;
  }
  for (User *U : U->users())
    collectFunctionUsers(U, Funcs);
}

bool AMDGPUOpenCLEnqueuedBlockLowering::runOnModule(Module &M) {
  DenseSet<Function *> Callers;
  auto &C = M.getContext();
  bool Changed = false;

  // ptr kernel_object, i32 private_segment_size, i32 group_segment_size
  StructType *HandleTy = nullptr;

  for (auto &F : M.functions()) {
    if (F.hasFnAttribute("enqueued-block")) {
      if (!F.hasName()) {
        SmallString<64> Name;
        Mangler::getNameWithPrefix(Name, "__amdgpu_enqueued_kernel",
                                   M.getDataLayout());
        F.setName(Name);
      }
      LLVM_DEBUG(dbgs() << "found enqueued kernel: " << F.getName() << '\n');
      auto RuntimeHandle = (F.getName() + ".runtime_handle").str();
      if (!HandleTy) {
        Type *Int32 = Type::getInt32Ty(C);
        HandleTy =
            StructType::create(C, {PointerType::getUnqual(C), Int32, Int32},
                               "block.runtime.handle.t");
      }

      auto *GV = new GlobalVariable(
          M, HandleTy,
          /*isConstant=*/true, GlobalValue::ExternalLinkage,
          /*Initializer=*/Constant::getNullValue(HandleTy), RuntimeHandle,
          /*InsertBefore=*/nullptr, GlobalValue::NotThreadLocal,
          AMDGPUAS::GLOBAL_ADDRESS,
          /*isExternallyInitialized=*/true);
      LLVM_DEBUG(dbgs() << "runtime handle created: " << *GV << '\n');

      for (User *U : F.users())
        collectFunctionUsers(U, Callers);

      F.replaceAllUsesWith(ConstantExpr::getAddrSpaceCast(GV, F.getType()));
      F.addFnAttr("runtime-handle", RuntimeHandle);
      F.setLinkage(GlobalValue::ExternalLinkage);
      Changed = true;
    }
  }

  // FIXME: This call graph analysis is broken and should be
  // removed. AMDGPUAttributor infers the individual implicit argument fields
  // are needed or not, but the runtime crashes in cases where we fail to
  // optimize these out at -O0.
  for (auto *F : Callers) {
    if (F->getCallingConv() != CallingConv::AMDGPU_KERNEL)
      continue;
    F->addFnAttr("calls-enqueue-kernel");
    LLVM_DEBUG(dbgs() << "mark enqueue_kernel caller:" << F->getName() << '\n');
  }
  return Changed;
}
