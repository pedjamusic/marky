cmake_minimum_required(VERSION 3.20)
project(MarkyCore LANGUAGES CXX)

add_library(marky_core STATIC
    src/Document.cpp
)
target_include_directories(marky_core PUBLIC include)
target_compile_features(marky_core PUBLIC cxx_std_20)
set_target_properties(marky_core PROPERTIES
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS NO
)

include(CTest)
if(BUILD_TESTING)
    add_executable(marky_core_tests tests/CoreTests.cpp)
    target_link_libraries(marky_core_tests PRIVATE marky_core)
    set_target_properties(marky_core_tests PROPERTIES
        CXX_STANDARD 20
        CXX_STANDARD_REQUIRED YES
        CXX_EXTENSIONS NO
    )
    add_test(NAME marky_core_tests COMMAND marky_core_tests)
endif()
