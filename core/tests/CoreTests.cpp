#include "BuildInfo.hpp"

#include <cstdlib>
#include <iostream>
#include <string_view>

int main() {
    int failures = 0;
    const auto check = [&failures](bool condition, std::string_view message) {
        if (!condition) {
            std::cerr << "FAIL: " << message << '\n';
            ++failures;
        }
    };

    check(marky::internal::compiled_language_standard() >= 202002L,
          "linked production library must compile as C++20 or newer");

    // Exercise the same failure path under CTest, including Release/NDEBUG builds.
    const char* force_failure = std::getenv("MARKY_CORE_TEST_FORCE_FAILURE");
    if (force_failure != nullptr && std::string_view(force_failure) == "1") {
        check(false, "intentional harness failure");
    }

    if (failures != 0) {
        return EXIT_FAILURE;
    }
    std::cout << "PASS: linked core build smoke check\n";
    return EXIT_SUCCESS;
}
