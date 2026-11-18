cmake_minimum_required(VERSION 3.20)
project(MarkyCore LANGUAGES CXX)

set(marky_core_sources
    src/Document.cpp
    src/InlineSyntax.cpp
    src/ProjectEntry.cpp
    src/ReferenceLabel.cpp
)
add_library(marky_core STATIC ${marky_core_sources})
target_include_directories(marky_core PUBLIC include)
target_compile_features(marky_core PUBLIC cxx_std_20)
set_target_properties(marky_core PROPERTIES
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED YES
    CXX_EXTENSIONS NO
)

include(CTest)
if(BUILD_TESTING)
    find_package(Threads REQUIRED)
    add_executable(marky_core_tests tests/CoreTests.cpp)
    target_link_libraries(marky_core_tests PRIVATE marky_core Threads::Threads)
    set_target_properties(marky_core_tests PROPERTIES
        CXX_STANDARD 20
        CXX_STANDARD_REQUIRED YES
        CXX_EXTENSIONS NO
    )
    add_test(NAME marky_core_tests COMMAND marky_core_tests)

    add_executable(marky_markdown_corpus tests/MarkdownCorpus.cpp)
    target_link_libraries(marky_markdown_corpus PRIVATE marky_core)
    set_target_properties(marky_markdown_corpus PROPERTIES CXX_EXTENSIONS NO)
    add_test(NAME marky_markdown_corpus COMMAND "${CMAKE_COMMAND}"
        "-DCORPUS=${CMAKE_CURRENT_SOURCE_DIR}/../MarkyTests/Fixtures/markdown-compatibility.json"
        "-DPROBE=$<TARGET_FILE:marky_markdown_corpus>"
        "-DINPUT_DIR=${CMAKE_CURRENT_BINARY_DIR}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/CheckMarkdownCorpus.cmake")

    # Compile the same implementation with private hooks into the fault test only.
    add_executable(marky_core_fault_tests tests/DocumentFaultTests.cpp ${marky_core_sources})
    target_include_directories(marky_core_fault_tests PRIVATE include tests)
    target_compile_definitions(marky_core_fault_tests PRIVATE MARKY_CORE_TEST_CHECKPOINTS)
    target_link_libraries(marky_core_fault_tests PRIVATE Threads::Threads)
    set_target_properties(marky_core_fault_tests PROPERTIES
        CXX_STANDARD 20
        CXX_STANDARD_REQUIRED YES
        CXX_EXTENSIONS NO
    )
    add_test(NAME marky_core_fault_tests COMMAND marky_core_fault_tests)
    set_tests_properties(marky_core_tests marky_core_fault_tests marky_markdown_corpus PROPERTIES TIMEOUT 60)
endif()
