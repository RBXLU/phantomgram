# Bundles a prebuilt libtdjson.so with the Linux app.
# Build it with scripts/build_tdlib_linux.sh (or let CI do it).
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "tdjson_native")
project(${PROJECT_NAME} LANGUAGES CXX)

set(TDJSON_PREBUILT "${CMAKE_CURRENT_SOURCE_DIR}/../prebuilt/linux/libtdjson.so")
if(NOT EXISTS "${TDJSON_PREBUILT}")
  message(FATAL_ERROR
    "libtdjson.so not found at ${TDJSON_PREBUILT}.\n"
    "Run scripts/build_tdlib_linux.sh from the repository root first.")
endif()

set(tdjson_native_bundled_libraries
  "${TDJSON_PREBUILT}"
  PARENT_SCOPE
)
