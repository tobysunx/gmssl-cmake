# MIT License
#
# Copyright (c) 2015-2018 The ViaDuck Project
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# build gmssl locally

# includes
include(ProcessorCount)
include(ExternalProject)

# find packages
find_package(Git REQUIRED)
find_package(PythonInterp 3 REQUIRED)

# # used to apply various patches to gmssl
find_program(PATCH_PROGRAM patch)
if (NOT PATCH_PROGRAM)
    message(FATAL_ERROR "Cannot find patch utility. This is only required for Android cross-compilation but due to script complexity "
                        "the requirement is always enforced")
endif()

# set variables
ProcessorCount(NUM_JOBS)
set(OS "UNIX")


# if already built, do not build again
if ((EXISTS ${GMSSL_LIBSSL_PATH}) AND (EXISTS ${GMSSL_LIBCRYPTO_PATH}))
    message(WARNING "Not building GMSSL again. Remove ${GMSSL_LIBSSL_PATH} and ${GMSSL_LIBCRYPTO_PATH} for rebuild")
else()

    if (WIN32 AND NOT CROSS)
        # yep, windows needs special treatment, but neither cygwin nor msys, since they provide an UNIX-like environment
        
        if (MINGW)
            set(OS "WIN32")
            message(WARNING "Building on windows is experimental")
            
            find_program(MSYS_BASH "bash.exe" PATHS "C:/Msys/" "C:/MinGW/msys/" PATH_SUFFIXES "/1.0/bin/" "/bin/"
                    DOC "Path to MSYS installation")
            if (NOT MSYS_BASH)
                message(FATAL_ERROR "Specify MSYS installation path")
            endif(NOT MSYS_BASH)
            
            set(MINGW_MAKE ${CMAKE_MAKE_PROGRAM})
            message(WARNING "Assuming your make program is a sibling of your compiler (resides in same directory)")
        elseif(NOT (CYGWIN OR MSYS))
            message(FATAL_ERROR "Unsupported compiler infrastructure")
        endif(MINGW)
        
        set(MAKE_PROGRAM ${CMAKE_MAKE_PROGRAM})
    elseif(NOT UNIX)
        message(FATAL_ERROR "Unsupported platform")
    else()
        # for GMSSL we can only use GNU make, no exotic things like Ninja (MSYS always uses GNU make)
        find_program(MAKE_PROGRAM make)
    endif()

    # save old git values for core.autocrlf and core.eol
    execute_process(COMMAND ${GIT_EXECUTABLE} config --global --get core.autocrlf OUTPUT_VARIABLE GIT_CORE_AUTOCRLF OUTPUT_STRIP_TRAILING_WHITESPACE)
    execute_process(COMMAND ${GIT_EXECUTABLE} config --global --get core.eol OUTPUT_VARIABLE GIT_CORE_EOL OUTPUT_STRIP_TRAILING_WHITESPACE)

    # on windows we need to replace path to perl since CreateProcess(..) cannot handle unix paths
    if (WIN32 AND NOT CROSS)
        set(PERL_PATH_FIX_INSTALL sed -i -- 's/\\/usr\\/bin\\/perl/perl/g' Makefile)
    else()
        set(PERL_PATH_FIX_INSTALL true)
    endif()

    # CROSS and CROSS_ANDROID cannot both be set (because of internal reasons)
    if (CROSS AND CROSS_ANDROID)
        # if user set CROSS_ANDROID and CROSS we assume he wants CROSS_ANDROID, so set CROSS to OFF
        set(CROSS OFF)
    endif()

    if (CROSS_ANDROID)
        set(OS "LINUX_CROSS_ANDROID")
    endif()

    # python helper script for corrent building environment
    set(BUILD_ENV_TOOL ${PYTHON_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/scripts/building_env.py ${OS} ${MSYS_BASH} ${MINGW_MAKE})

    # disable everything we dont need
    set(CONFIGURE_GMSSL_MODULES no-cast no-md2 no-md4 no-mdc2 no-rc4 no-rc5 no-engine no-idea no-mdc2 no-rc5 no-camellia no-ssl3 no-heartbeats no-gost no-deprecated no-capieng no-comp no-dtls no-psk no-srp no-dso no-dsa no-rc2 no-des)

    # additional configure script parameters
    set(CONFIGURE_GMSSL_PARAMS --libdir=lib)
    
    # set install command depending of choice on man page generation
    if (GMSSL_INSTALL_MAN)
        set(INSTALL_GMSSL_MAN "install_docs")
    endif()
    
    # disable building tests
    if (NOT GMSSL_ENABLE_TESTS)
        set(CONFIGURE_GMSSL_MODULES ${CONFIGURE_GMSSL_MODULES} no-tests)
        set(COMMAND_TEST "true")
    endif()

    # cross-compiling
    if (CROSS)
        set(COMMAND_CONFIGURE ./Configure ${CONFIGURE_GMSSL_PARAMS} --cross-compile-prefix=${CROSS_PREFIX} ${CROSS_TARGET} ${CONFIGURE_GMSSL_MODULES} --prefix=/usr/local/)
        set(COMMAND_TEST "true")
    elseif(CROSS_ANDROID)
        
        # Android specific configuration options
        set(CONFIGURE_GMSSL_MODULES ${CONFIGURE_GMSSL_MODULES} no-hw)
                
        # silence warnings about unused arguments (Clang specific)
        set(CFLAGS "${CMAKE_C_FLAGS} -Qunused-arguments")
        set(CXXFLAGS "${CMAKE_CXX_FLAGS} -Qunused-arguments")
    
        # required environment configuration is already set (by e.g. ndk) so no need to fiddle around with all the OpenSSL options ...
        if (NOT ANDROID)
            message(FATAL_ERROR "Use NDK cmake toolchain or cmake android autoconfig")
        endif()
        
        if (ARMEABI_V7A)
            set(GMSSL_PLATFORM "arm")
            set(CONFIGURE_GMSSL_PARAMS ${CONFIGURE_GMSSL_PARAMS} "-march=armv7-a")
        else()
            if (CMAKE_ANDROID_ARCH_ABI MATCHES "arm64-v8a")
                set(GMSSL_PLATFORM "arm64")
            else()
                set(GMSSL_PLATFORM ${CMAKE_ANDROID_ARCH_ABI})
            endif()
        endif()
                
        # ... but we have to convert all the CMake options to environment variables!
        set(PATH "${ANDROID_TOOLCHAIN_ROOT}/bin/:${ANDROID_TOOLCHAIN_ROOT}/${ANDROID_TOOLCHAIN_NAME}/bin/")
        set(LDFLAGS ${CMAKE_MODULE_LINKER_FLAGS})
        
        set(COMMAND_CONFIGURE ./Configure android-${OPENSSL_PLATFORM} ${CONFIGURE_GMSSL_PARAMS} ${CONFIGURE_OPENSSL_MODULES})
        set(COMMAND_TEST "true")
    else()                   # detect host system automatically
        set(COMMAND_CONFIGURE ./config ${CONFIGURE_GMSSL_PARAMS} ${CONFIGURE_OPENSSL_MODULES})
        
        if (NOT COMMAND_TEST)
            set(COMMAND_TEST ${BUILD_ENV_TOOL} <SOURCE_DIR> ${MAKE_PROGRAM} test)
        endif()
    endif()
    
    # add gmssl target
    ExternalProject_Add(gmssl
        URL https://github.com/guanzhi/GmSSL/archive/gmbrowser-v0.1.tar.gz
        ${GMSSL_CHECK_HASH}
        UPDATE_COMMAND ""

        CONFIGURE_COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ${COMMAND_CONFIGURE}

        BUILD_COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ${MAKE_PROGRAM} -j ${NUM_JOBS}
        BUILD_BYPRODUCTS ${GMSSL_LIBSSL_PATH} ${GMSSL_LIBCRYPTO_PATH}

        TEST_BEFORE_INSTALL 1
        TEST_COMMAND ${COMMAND_TEST}

        INSTALL_COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ${PERL_PATH_FIX_INSTALL}
        COMMAND ${BUILD_ENV_TOOL} <SOURCE_DIR> ${MAKE_PROGRAM} DESTDIR=${CMAKE_CURRENT_BINARY_DIR} install_sw ${INSTALL_OPENSSL_MAN}
        COMMAND ${CMAKE_COMMAND} -G ${CMAKE_GENERATOR} ${CMAKE_BINARY_DIR}                    # force CMake-reload

        LOG_INSTALL 1
    )

    # set git config values to gmssl requirements (no impact on linux though)
    ExternalProject_Add_Step(gmssl setGitConfig
        COMMAND ${GIT_EXECUTABLE} config --global core.autocrlf false
        COMMAND ${GIT_EXECUTABLE} config --global core.eol lf
        DEPENDEES
        DEPENDERS download
        ALWAYS ON
    )

    # set, don't abort if it fails (due to variables being empty). To realize this we must only call git if the configs
    # are set globally, otherwise do a no-op command ("echo 1", since "true" is not available everywhere)
    if (GIT_CORE_AUTOCRLF)
        set (GIT_CORE_AUTOCRLF_CMD ${GIT_EXECUTABLE} config --global core.autocrlf ${GIT_CORE_AUTOCRLF})
    else()
        set (GIT_CORE_AUTOCRLF_CMD echo)
    endif()
    if (GIT_CORE_EOL)
        set (GIT_CORE_EOL_CMD ${GIT_EXECUTABLE} config --global core.eol ${GIT_CORE_EOL})
    else()
        set (GIT_CORE_EOL_CMD echo)
    endif()
    ##

    # set git config values to previous values
    ExternalProject_Add_Step(gmssl restoreGitConfig
    # unset first (is required, since old value could be omitted, which wouldn't take any effect in "set"
        COMMAND ${GIT_EXECUTABLE} config --global --unset core.autocrlf
        COMMAND ${GIT_EXECUTABLE} config --global --unset core.eol

        COMMAND ${GIT_CORE_AUTOCRLF_CMD}
        COMMAND ${GIT_CORE_EOL_CMD}

        DEPENDEES download
        DEPENDERS configure
        ALWAYS ON
    )

    # write environment to file, is picked up by python script
    get_cmake_property(_variableNames VARIABLES)
    foreach (_variableName ${_variableNames})
        if (NOT _variableName MATCHES "lines")
            set(OUT_FILE "${OUT_FILE}${_variableName}=\"${${_variableName}}\"\n")
        endif()
    endforeach()
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/buildenv.txt ${OUT_FILE})
endif()
