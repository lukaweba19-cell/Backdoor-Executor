#include <iostream>

// This is a dummy main function to satisfy the linker
// It will never be called since we're building a dylib
int main() {
    std::cout << "This is a dummy main function that should never be called." << std::endl;
    return 0;
}