# GmSSL-CMake
CMake script supplying `GmSSL` libraries conveniently, encapsulating the
`GmSSL` build system on various platforms.

## Features
* Allows usage of system GmSSL
* Allows trivial and complex building of GmSSL

## Usage
1. Add `GmSSL-CMake` as a submodule to your Git project using `git submodule 
add <https://github.com/guanzhi/GmSSL/archive/gmbrowser-v0.1.tar.gz> external/gmssl-cmake`
2. Initialize the submodule using `git submodule update --init`
3. In your `CMakeLists.txt` include the directory using 
`add_subdirectory(external/gmssl-cmake)`
4. Link against `ssl` and `crypto` targets, which will also include the headers

## Licensing
These scripts, unless otherwise stated, are subject to the MIT license.
