// Compatibility header for mach-related functions
#pragma once

#ifdef __APPLE__
#include <mach/mach.h>
#include <mach/mach_init.h>
#include <mach/mach_interface.h>
#include <mach/mach_port.h>
#include <mach/mach_time.h>
#include <mach/task.h>
#else
// Stubs for non-Apple platforms

// Basic mach types
typedef int mach_port_t;
typedef unsigned int vm_address_t;
typedef unsigned int vm_size_t;
typedef int kern_return_t;
typedef int vm_prot_t;

// Constants
#define KERN_SUCCESS 0
#define VM_PROT_READ 1
#define VM_PROT_WRITE 2
#define VM_PROT_EXECUTE 4

// Function declarations
kern_return_t task_for_pid(mach_port_t task, int pid, mach_port_t* target);
kern_return_t mach_port_deallocate(mach_port_t task, mach_port_t name);
kern_return_t vm_read(mach_port_t task, vm_address_t address, vm_size_t size, vm_address_t* data, vm_size_t* data_size);
kern_return_t vm_write(mach_port_t task, vm_address_t address, vm_address_t data, vm_size_t data_size);
kern_return_t vm_protect(mach_port_t task, vm_address_t address, vm_size_t size, int set_maximum, vm_prot_t new_protection);

#endif // __APPLE__
