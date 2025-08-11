// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for absl/strings/string_view.h

#ifndef ABSL_STRINGS_STRING_VIEW_H_
#define ABSL_STRINGS_STRING_VIEW_H_

#include <string>
#include <cstring>

namespace absl {
class string_view {
public:
    string_view() : data_(nullptr), size_(0) {}
    string_view(const char* str) : data_(str), size_(str ? strlen(str) : 0) {}
    string_view(const std::string& str) : data_(str.data()), size_(str.size()) {}
    string_view(const char* data, size_t size) : data_(data), size_(size) {}
    
    const char* data() const { return data_; }
    size_t size() const { return size_; }
    bool empty() const { return size_ == 0; }
    
private:
    const char* data_;
    size_t size_;
};
} // namespace absl

#endif // ABSL_STRINGS_STRING_VIEW_H_
