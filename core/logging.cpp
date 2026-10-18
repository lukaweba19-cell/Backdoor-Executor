// logging.cpp - Implementation of logging system
#include "logging.hpp"

namespace Logging {

// Initialize static members
std::unique_ptr<Logger> Logger::s_instance = nullptr;
std::mutex Logger::s_instanceMutex;

} // namespace Logging
