// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for absl/types/optional.h

#ifndef ABSL_TYPES_OPTIONAL_H_
#define ABSL_TYPES_OPTIONAL_H_

#include <memory>

namespace absl {
template<typename T>
class optional {
public:
    optional() : has_value_(false) {}
    optional(const T& value) : has_value_(true) { new(&storage_) T(value); }
    optional(T&& value) : has_value_(true) { new(&storage_) T(std::move(value)); }
    
    ~optional() { if (has_value_) reinterpret_cast<T*>(&storage_)->~T(); }
    
    bool has_value() const { return has_value_; }
    operator bool() const { return has_value_; }
    
    const T& value() const { return *reinterpret_cast<const T*>(&storage_); }
    T& value() { return *reinterpret_cast<T*>(&storage_); }
    
    const T& value_or(const T& default_value) const {
        return has_value_ ? value() : default_value;
    }
    
private:
    bool has_value_;
    alignas(T) char storage_[sizeof(T)];
};
} // namespace absl

#endif // ABSL_TYPES_OPTIONAL_H_
