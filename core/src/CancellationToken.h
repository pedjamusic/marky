#ifndef MARKY_CANCELLATION_TOKEN_H
#define MARKY_CANCELLATION_TOKEN_H

#include <atomic>

struct MarkyCancellationToken {
    std::atomic<bool> requested{false};
};

namespace marky {

inline bool cancellation_requested(const MarkyCancellationToken* token) noexcept {
    // The flag carries no other state. The caller manages token lifetime.
    return token != nullptr && token->requested.load(std::memory_order_relaxed);
}

}

#endif
