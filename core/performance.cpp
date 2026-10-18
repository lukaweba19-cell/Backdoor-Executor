// performance.cpp - Implementation of performance monitoring system
#include "performance.hpp"

namespace Performance {

// Initialize static members of Profiler class
std::mutex Profiler::s_metricsMutex;
std::map<std::string, Metric> Profiler::s_metrics;
std::atomic<bool> Profiler::s_enabled(false);
std::atomic<bool> Profiler::s_autoLogEnabled(false);
std::atomic<uint64_t> Profiler::s_autoLogThreshold(100);
std::thread Profiler::s_backgroundThread;
std::atomic<bool> Profiler::s_shouldRun(false);
std::string Profiler::s_reportPath;

} // namespace Performance
