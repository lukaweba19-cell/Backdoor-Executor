/*
 * Copyright (c) 2000-2018 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_LICENSE_HEADER_END@
 */

#ifndef __TARGETCONDITIONALS__
#define __TARGETCONDITIONALS__

/*
 * TARGET_OS_MAC is set to 1 in all Apple OS variants.
 * TARGET_OS_UNIX is set to 1 for all Unix-like OSes.
 *
 * TARGET_OS_OSX: OS X
 * TARGET_OS_IPHONE: iOS, tvOS, or watchOS device
 * TARGET_OS_IOS: iOS
 * TARGET_OS_TV: tvOS
 * TARGET_OS_WATCH: watchOS
 *
 * TARGET_OS_SIMULATOR: running under a simulator
 * TARGET_OS_EMBEDDED: iOS, tvOS, or watchOS device
 *
 * TARGET_OS_MACCATALYST: Mac Catalyst (macOS with UIKit)
 * TARGET_OS_DRIVERKIT: DriverKit
 *
 * TARGET_CPU_PPC: PowerPC
 * TARGET_CPU_X86: Intel 32-bit
 * TARGET_CPU_X86_64: Intel 64-bit
 * TARGET_CPU_ARM: ARM 32-bit
 * TARGET_CPU_ARM64: ARM 64-bit
 */

#define TARGET_OS_MAC               1
#define TARGET_OS_UNIX              0

#define TARGET_OS_OSX               0
#define TARGET_OS_IPHONE            1
#define TARGET_OS_IOS               1
#define TARGET_OS_TV                0
#define TARGET_OS_WATCH             0

#define TARGET_OS_SIMULATOR         0
#define TARGET_OS_EMBEDDED          1

#define TARGET_OS_MACCATALYST       0
#define TARGET_OS_DRIVERKIT         0

#define TARGET_CPU_PPC              0
#define TARGET_CPU_X86              0
#define TARGET_CPU_X86_64           0
#define TARGET_CPU_ARM              0
#define TARGET_CPU_ARM64            1

#define TARGET_RT_64_BIT            1
#define TARGET_RT_LITTLE_ENDIAN     1
#define TARGET_RT_BIG_ENDIAN        0

#define __IPHONE_OS_VERSION_MIN_REQUIRED 150000

#endif /* __TARGETCONDITIONALS__ */