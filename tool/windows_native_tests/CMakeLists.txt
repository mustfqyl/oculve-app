cmake_minimum_required(VERSION 3.20)
project(oculve_windows_native_tests LANGUAGES CXX)

if(NOT WIN32)
  message(FATAL_ERROR "These tests require the Windows SDK and a Windows host.")
endif()

include(CTest)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(WINDOWS_SOURCE "${REPO_ROOT}/vendor/flutter_vless/packages/flutter_vless_windows/windows")

function(oculve_native_test name)
  add_executable(${name} ${ARGN})
  target_include_directories(${name} PRIVATE "${WINDOWS_SOURCE}")
  target_compile_definitions(${name} PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  add_test(NAME ${name} COMMAND ${name})
endfunction()

oculve_native_test(traffic_protection_policy
  "${WINDOWS_SOURCE}/traffic_protection_test.cpp"
  "${WINDOWS_SOURCE}/traffic_protection.cpp")
target_link_libraries(traffic_protection_policy PRIVATE advapi32)

oculve_native_test(xray_config_regression
  "${WINDOWS_SOURCE}/xray_config_test.cpp")
oculve_native_test(desktop_security_regression
  "${WINDOWS_SOURCE}/desktop_security_test.cpp")
oculve_native_test(diagnostics_log_regression
  "${WINDOWS_SOURCE}/diagnostics_log_test.cpp"
  "${WINDOWS_SOURCE}/diagnostics_log.cpp")

oculve_native_test(native_runtime_regression
  "${WINDOWS_SOURCE}/native_runtime_test.cpp"
  "${WINDOWS_SOURCE}/native_runtime.cpp"
  "${WINDOWS_SOURCE}/protected_runtime.cpp"
  "${WINDOWS_SOURCE}/packet_path_probe.cpp")
target_link_libraries(native_runtime_regression PRIVATE
  ws2_32 wininet winhttp iphlpapi shlwapi version ole32 shell32 uuid advapi32 bcrypt fwpuclnt)
