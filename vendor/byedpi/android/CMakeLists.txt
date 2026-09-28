cmake_minimum_required(VERSION 3.22.1)
project(byedpi_engine C)

set(BYEDPI_ROOT "${CMAKE_CURRENT_LIST_DIR}/..")
set(BYEDPI_UPSTREAM "${BYEDPI_ROOT}/upstream")
add_library(byedpi_engine SHARED
  ${BYEDPI_UPSTREAM}/library_main.c
  ${BYEDPI_UPSTREAM}/conev.c
  ${BYEDPI_UPSTREAM}/proxy.c
  ${BYEDPI_UPSTREAM}/desync.c
  ${BYEDPI_UPSTREAM}/mpool.c
  ${BYEDPI_UPSTREAM}/extend.c
  ${BYEDPI_UPSTREAM}/packets.c
  ${BYEDPI_UPSTREAM}/engine.c
  jni_bridge.c
)
target_include_directories(byedpi_engine PRIVATE
  ${BYEDPI_UPSTREAM}/include
  ${BYEDPI_UPSTREAM}
)
target_compile_features(byedpi_engine PRIVATE c_std_99)
target_compile_definitions(byedpi_engine PRIVATE BYEDPI_LIBRARY ANDROID_APP)
target_compile_options(byedpi_engine PRIVATE -Wall -Wextra -Wno-unused-parameter)
find_library(android_log log REQUIRED)
target_link_libraries(byedpi_engine PRIVATE ${android_log})
