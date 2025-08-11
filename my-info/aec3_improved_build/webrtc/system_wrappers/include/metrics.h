// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for system_wrappers/include/metrics.h

#ifndef SYSTEM_WRAPPERS_INCLUDE_METRICS_H_
#define SYSTEM_WRAPPERS_INCLUDE_METRICS_H_

#define RTC_HISTOGRAM_COUNTS(name, sample, min, max, bucket_count)
#define RTC_HISTOGRAM_COUNTS_100(name, sample) 
#define RTC_HISTOGRAM_COUNTS_1000(name, sample)
#define RTC_HISTOGRAM_COUNTS_10000(name, sample)
#define RTC_HISTOGRAM_BOOLEAN(name, sample)

namespace webrtc {
namespace metrics {

inline void HistogramCounts(const char* name, int sample, int min, int max, int bucket_count) {}
inline void HistogramCounts100(const char* name, int sample) {}
inline void HistogramCounts1000(const char* name, int sample) {}
inline void HistogramCounts10000(const char* name, int sample) {}
inline void HistogramBoolean(const char* name, bool sample) {}

} // namespace metrics
} // namespace webrtc

#endif // SYSTEM_WRAPPERS_INCLUDE_METRICS_H_
