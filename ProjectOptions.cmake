include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(cppcmake_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(cppcmake_setup_options)
  option(cppcmake_ENABLE_HARDENING "Enable hardening" ON)
  option(cppcmake_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    cppcmake_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    cppcmake_ENABLE_HARDENING
    OFF)

  cppcmake_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR cppcmake_PACKAGING_MAINTAINER_MODE)
    option(cppcmake_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(cppcmake_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(cppcmake_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cppcmake_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(cppcmake_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cppcmake_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(cppcmake_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cppcmake_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cppcmake_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cppcmake_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(cppcmake_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(cppcmake_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cppcmake_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(cppcmake_ENABLE_IPO "Enable IPO/LTO" ON)
    option(cppcmake_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(cppcmake_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cppcmake_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(cppcmake_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cppcmake_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(cppcmake_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cppcmake_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cppcmake_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cppcmake_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(cppcmake_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(cppcmake_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cppcmake_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      cppcmake_ENABLE_IPO
      cppcmake_WARNINGS_AS_ERRORS
      cppcmake_ENABLE_USER_LINKER
      cppcmake_ENABLE_SANITIZER_ADDRESS
      cppcmake_ENABLE_SANITIZER_LEAK
      cppcmake_ENABLE_SANITIZER_UNDEFINED
      cppcmake_ENABLE_SANITIZER_THREAD
      cppcmake_ENABLE_SANITIZER_MEMORY
      cppcmake_ENABLE_UNITY_BUILD
      cppcmake_ENABLE_CLANG_TIDY
      cppcmake_ENABLE_CPPCHECK
      cppcmake_ENABLE_COVERAGE
      cppcmake_ENABLE_PCH
      cppcmake_ENABLE_CACHE)
  endif()

  cppcmake_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (cppcmake_ENABLE_SANITIZER_ADDRESS OR cppcmake_ENABLE_SANITIZER_THREAD OR cppcmake_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(cppcmake_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(cppcmake_global_options)
  if(cppcmake_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    cppcmake_enable_ipo()
  endif()

  cppcmake_supports_sanitizers()

  if(cppcmake_ENABLE_HARDENING AND cppcmake_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cppcmake_ENABLE_SANITIZER_UNDEFINED
       OR cppcmake_ENABLE_SANITIZER_ADDRESS
       OR cppcmake_ENABLE_SANITIZER_THREAD
       OR cppcmake_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${cppcmake_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${cppcmake_ENABLE_SANITIZER_UNDEFINED}")
    cppcmake_enable_hardening(cppcmake_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(cppcmake_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(cppcmake_warnings INTERFACE)
  add_library(cppcmake_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  cppcmake_set_project_warnings(
    cppcmake_warnings
    ${cppcmake_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(cppcmake_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(cppcmake_options)
  endif()

  include(cmake/Sanitizers.cmake)
  cppcmake_enable_sanitizers(
    cppcmake_options
    ${cppcmake_ENABLE_SANITIZER_ADDRESS}
    ${cppcmake_ENABLE_SANITIZER_LEAK}
    ${cppcmake_ENABLE_SANITIZER_UNDEFINED}
    ${cppcmake_ENABLE_SANITIZER_THREAD}
    ${cppcmake_ENABLE_SANITIZER_MEMORY})

  set_target_properties(cppcmake_options PROPERTIES UNITY_BUILD ${cppcmake_ENABLE_UNITY_BUILD})

  if(cppcmake_ENABLE_PCH)
    target_precompile_headers(
      cppcmake_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(cppcmake_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    cppcmake_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(cppcmake_ENABLE_CLANG_TIDY)
    cppcmake_enable_clang_tidy(cppcmake_options ${cppcmake_WARNINGS_AS_ERRORS})
  endif()

  if(cppcmake_ENABLE_CPPCHECK)
    cppcmake_enable_cppcheck(${cppcmake_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(cppcmake_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    cppcmake_enable_coverage(cppcmake_options)
  endif()

  if(cppcmake_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(cppcmake_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(cppcmake_ENABLE_HARDENING AND NOT cppcmake_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cppcmake_ENABLE_SANITIZER_UNDEFINED
       OR cppcmake_ENABLE_SANITIZER_ADDRESS
       OR cppcmake_ENABLE_SANITIZER_THREAD
       OR cppcmake_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    cppcmake_enable_hardening(cppcmake_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
