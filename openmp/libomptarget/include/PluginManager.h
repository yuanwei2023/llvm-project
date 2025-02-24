//===-- PluginManager.h - Plugin loading and communication API --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Declarations for managing devices that are handled by RTL plugins.
//
//===----------------------------------------------------------------------===//

#ifndef OMPTARGET_PLUGIN_MANAGER_H
#define OMPTARGET_PLUGIN_MANAGER_H

#include "DeviceImage.h"
#include "Shared/APITypes.h"
#include "Shared/PluginAPI.h"
#include "Shared/Requirements.h"

#include "device.h"

#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/iterator.h"
#include "llvm/ADT/iterator_range.h"
#include "llvm/Support/DynamicLibrary.h"

#include <cstdint>
#include <list>
#include <memory>
#include <mutex>
#include <string>

struct PluginAdaptorTy {
  PluginAdaptorTy(const std::string &Name);

  bool isUsed() const { return DeviceOffset >= 0; }

  /// Return the number of devices available to this plugin.
  int32_t getNumDevices() const { return NumberOfDevices; }

  /// Add all offload entries described by \p DI to the devices managed by this
  /// plugin.
  void addOffloadEntries(DeviceImageTy &DI);

  /// RTL index, index is the number of devices of other RTLs that were
  /// registered before, i.e. the OpenMP index of the first device to be
  /// registered with this RTL.
  int32_t DeviceOffset = -1;

  /// Number of devices this RTL deals with.
  int32_t NumberOfDevices = -1;

  /// Name of the shared object file representing the plugin.
  std::string Name;

  /// Access to the shared object file representing the plugin.
  std::unique_ptr<llvm::sys::DynamicLibrary> LibraryHandler;

#define PLUGIN_API_HANDLE(NAME, MANDATORY)                                     \
  using NAME##_ty = decltype(__tgt_rtl_##NAME);                                \
  NAME##_ty *NAME = nullptr;

#include "Shared/PluginAPI.inc"
#undef PLUGIN_API_HANDLE

  llvm::DenseSet<const __tgt_device_image *> UsedImages;

  // Mutex for thread-safety when calling RTL interface functions.
  // It is easier to enforce thread-safety at the libomptarget level,
  // so that developers of new RTLs do not have to worry about it.
  std::mutex Mtx;
};

/// Struct for the data required to handle plugins
struct PluginManager {
  PluginManager() {}

  void init();

  // Register a shared library with all (compatible) RTLs.
  void registerLib(__tgt_bin_desc *Desc);

  // Unregister a shared library from all RTLs.
  void unregisterLib(__tgt_bin_desc *Desc);

  void addDeviceImage(__tgt_bin_desc &TgtBinDesc, __tgt_device_image &TgtDeviceImage) {
    DeviceImages.emplace_back(std::make_unique<DeviceImageTy>(TgtBinDesc, TgtDeviceImage));
  }

  /// Iterate over all device images registered with this plugin.
  auto deviceImages() { return llvm::make_pointee_range(DeviceImages); }

  /// Devices associated with RTLs
  std::vector<std::unique_ptr<DeviceTy>> Devices;
  std::mutex RTLsMtx; ///< For RTLs and Devices

  /// Translation table retreived from the binary
  HostEntriesBeginToTransTableTy HostEntriesBeginToTransTable;
  std::mutex TrlTblMtx; ///< For Translation Table
  /// Host offload entries in order of image registration
  std::vector<__tgt_offload_entry *> HostEntriesBeginRegistrationOrder;

  /// Map from ptrs on the host to an entry in the Translation Table
  HostPtrToTableMapTy HostPtrToTableMap;
  std::mutex TblMapMtx; ///< For HostPtrToTableMap

  // Work around for plugins that call dlopen on shared libraries that call
  // tgt_register_lib during their initialisation. Stash the pointers in a
  // vector until the plugins are all initialised and then register them.
  bool delayRegisterLib(__tgt_bin_desc *Desc) {
    if (RTLsLoaded)
      return false;
    DelayedBinDesc.push_back(Desc);
    return true;
  }

  void registerDelayedLibraries() {
    // Only called by libomptarget constructor
    RTLsLoaded = true;
    for (auto *Desc : DelayedBinDesc)
      __tgt_register_lib(Desc);
    DelayedBinDesc.clear();
  }

  int getNumDevices() {
    std::lock_guard<decltype(RTLsMtx)> Lock(RTLsMtx);
    return Devices.size();
  }

  int getNumUsedPlugins() const {
    int NCI = 0;
    for (auto &P : PluginAdaptors)
      NCI += P.isUsed();
    return NCI;
  }

  // Initialize \p Plugin if it has not been initialized.
  void initPlugin(PluginAdaptorTy &Plugin);

  // Initialize all plugins.
  void initAllPlugins();

  /// Iterator range for all plugin adaptors (in use or not, but always valid).
  auto pluginAdaptors() {
    return llvm::make_range(PluginAdaptors.begin(), PluginAdaptors.end());
  }

  /// Return the user provided requirements.
  int64_t getRequirements() const { return Requirements.getRequirements(); }

  /// Add \p Flags to the user provided requirements.
  void addRequirements(int64_t Flags) { Requirements.addRequirements(Flags); }

private:
  bool RTLsLoaded = false;
  llvm::SmallVector<__tgt_bin_desc *> DelayedBinDesc;

  // List of all plugin adaptors, in use or not.
  std::list<PluginAdaptorTy> PluginAdaptors;

  /// Executable images and information extracted from the input images passed
  /// to the runtime.
  llvm::SmallVector<std::unique_ptr<DeviceImageTy>> DeviceImages;

  /// The user provided requirements.
  RequirementCollection Requirements;
};

extern PluginManager *PM;

#endif // OMPTARGET_PLUGIN_MANAGER_H
