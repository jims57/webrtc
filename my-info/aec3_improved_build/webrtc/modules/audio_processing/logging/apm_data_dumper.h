// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for logging/apm_data_dumper.h

#ifndef MODULES_AUDIO_PROCESSING_LOGGING_APM_DATA_DUMPER_H_
#define MODULES_AUDIO_PROCESSING_LOGGING_APM_DATA_DUMPER_H_

namespace webrtc {

class ApmDataDumper {
public:
    ApmDataDumper(int instance_id) {}
    ~ApmDataDumper() {}
    
    void DumpRaw(const char* name, double value) {}
    void DumpRaw(const char* name, const float* data, size_t length) {}
    void DumpWav(const char* name, const float* data, size_t length, int sample_rate, int num_channels) {}
};

} // namespace webrtc

#endif // MODULES_AUDIO_PROCESSING_LOGGING_APM_DATA_DUMPER_H_
