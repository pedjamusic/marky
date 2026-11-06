#include "BuildInfo.hpp"

namespace marky::internal {

long compiled_language_standard() noexcept {
#if defined(_MSVC_LANG)
    return _MSVC_LANG;
#else
    return __cplusplus;
#endif
}

}
