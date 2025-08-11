// Author: Jimmy Gan
// Date: 2025-01-28
// Stub implementation for rtc_base/checks.h

#ifndef RTC_BASE_CHECKS_H_
#define RTC_BASE_CHECKS_H_

#include <cassert>
#include <cstdlib>

#define RTC_DCHECK(condition) assert(condition)
#define RTC_DCHECK_EQ(a, b) assert((a) == (b))
#define RTC_DCHECK_NE(a, b) assert((a) != (b))
#define RTC_DCHECK_LT(a, b) assert((a) < (b))
#define RTC_DCHECK_LE(a, b) assert((a) <= (b))
#define RTC_DCHECK_GT(a, b) assert((a) > (b))
#define RTC_DCHECK_GE(a, b) assert((a) >= (b))

#define RTC_CHECK(condition) do { if (!(condition)) { abort(); } } while(0)
#define RTC_CHECK_EQ(a, b) RTC_CHECK((a) == (b))
#define RTC_CHECK_NE(a, b) RTC_CHECK((a) != (b))
#define RTC_CHECK_LT(a, b) RTC_CHECK((a) < (b))
#define RTC_CHECK_LE(a, b) RTC_CHECK((a) <= (b))
#define RTC_CHECK_GT(a, b) RTC_CHECK((a) > (b))
#define RTC_CHECK_GE(a, b) RTC_CHECK((a) >= (b))

#define RTC_NOTREACHED() abort()

namespace rtc {
// Stub implementation
} // namespace rtc

#endif // RTC_BASE_CHECKS_H_
