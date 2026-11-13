#ifndef MARKY_REFERENCE_LABEL_H
#define MARKY_REFERENCE_LABEL_H

#include <string>
#include <string_view>

namespace marky {

// Accepts validated UTF-8 and returns a key for bytewise comparison.
std::string normalize_reference_label(std::string_view source);

}

#endif
