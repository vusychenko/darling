project(darling)

cmake_minimum_required(VERSION 2.4.0)
if(COMMAND cmake_policy)
	cmake_policy(SET CMP0003 NEW)
endif(COMMAND cmake_policy)

ADD_DEFINITIONS(-ggdb -DDEBUG)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
include_directories(${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include/xnu)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include/xnu/bsd)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include/darwin)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/src/libmach-o)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/src/util)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++0x")

configure_file(config.h.in config.h)

set(util-SRCS
	src/util/log.cc
	src/util/trace.cpp
	src/util/IniConfig.cpp
)

add_library(util ${util-SRCS})
set_target_properties(util PROPERTIES COMPILE_FLAGS "-fPIC")

set(mach-o_SRCS
	src/libmach-o/MachO.cpp
	src/libmach-o/FatMachO.cpp
	src/libmach-o/RebaseState.cpp
	src/libmach-o/BindState.cpp
	src/libmach-o/leb.cpp
	src/libmach-o/MachOImpl.cpp
)

add_library(mach-o SHARED ${mach-o_SRCS})
set_target_properties(mach-o PROPERTIES VERSION 1.0.0 SOVERSION 1.0)
set_target_properties(mach-o PROPERTIES COMPILE_FLAGS "-fvisibility=hidden")
target_link_libraries(mach-o -ldl -lpthread util)

set(dyld_SRCS
	src/dyld/FileMap.cpp
	src/dyld/MachOLoader.cpp
	src/dyld/UndefinedFunction.cpp
	src/dyld/Trampoline.cpp
	src/dyld/ld.cpp
	src/dyld/dyld.cpp
)

add_executable(dyld ${dyld_SRCS})
target_link_libraries(dyld -ldl -lpthread mach-o util)

set(fatmacho-extract_SRCS
	src/dyld/extract.cpp
)

add_executable(fatmacho-extract ${fatmacho-extract_SRCS})
target_link_libraries(fatmacho-extract -ldl -lpthread mach-o -Wl,-export-dynamic)

set(motool_SRCS
	src/motool/motool.cpp
)

add_executable(motool ${motool_SRCS})
target_link_libraries(motool mach-o)

install(TARGETS dyld fatmacho-extract motool DESTINATION bin)
install(TARGETS mach-o DESTINATION lib)
install(FILES etc/dylib.conf DESTINATION /etc/darling)

add_subdirectory(src/libSystem)
add_subdirectory(src/libunwind-darwin)
#add_subdirectory(src/CoreServices)
