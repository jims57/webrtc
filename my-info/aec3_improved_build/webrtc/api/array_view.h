// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for api/array_view.h

#ifndef API_ARRAY_VIEW_H_
#define API_ARRAY_VIEW_H_

#include <cstddef>
#include <vector>

namespace rtc {
template<typename T>
class ArrayView {
public:
    ArrayView() : data_(nullptr), size_(0) {}
    ArrayView(T* data, size_t size) : data_(data), size_(size) {}
    ArrayView(std::vector<T>& vec) : data_(vec.data()), size_(vec.size()) {}
    
    T* data() const { return data_; }
    size_t size() const { return size_; }
    bool empty() const { return size_ == 0; }
    
    T& operator[](size_t index) { return data_[index]; }
    const T& operator[](size_t index) const { return data_[index]; }
    
private:
    T* data_;
    size_t size_;
};
} // namespace rtc

#endif // API_ARRAY_VIEW_H_
