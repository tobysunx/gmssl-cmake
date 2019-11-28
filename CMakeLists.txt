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

cmake_minimum_required(VERSION 3.2)
project(gmssl-cmake)

# allow including our modules
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")


# set up prefix

set(GMSSL_PREFIX ${CMAKE_CURRENT_BINARY_DIR})
set(GMSSL_LIBSSL_PATH ${GMSSL_PREFIX}/usr/local/lib/libssl.a)
set(GMSSL_LIBCRYPTO_PATH ${GMSSL_PREFIX}/usr/local/lib/libcrypto.a)

# mimic system ssl and crypto targets
add_library(gm_ssl INTERFACE)
add_library(gm_crypto INTERFACE)

# set up gmssl target
add_library(gm_ssl_lib STATIC IMPORTED GLOBAL)
add_library(gm_crypto_lib STATIC IMPORTED GLOBAL)

include(BuildGmSSL)



target_link_libraries(gm_ssl INTERFACE ssl_lib)
target_link_libraries(gm_crypto INTERFACE crypto_lib)

# set import locations
set_target_properties(gm_ssl_lib PROPERTIES IMPORTED_LOCATION ${GMSSL_LIBSSL_PATH})
set_target_properties(gm_crypto_lib PROPERTIES IMPORTED_LOCATION ${GMSSL_LIBCRYPTO_PATH})


# set include locations
target_include_directories(gm_ssl BEFORE INTERFACE ${GMSSL_PREFIX}/usr/local/include)
target_include_directories(gm_crypto BEFORE INTERFACE ${GMSSL_PREFIX}/usr/local/include)


# add fake targets to common target
add_dependencies(gm_ssl_lib gmsssl)
add_dependencies(gm_crypto_lib gmssl)

