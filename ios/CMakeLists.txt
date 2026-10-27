cmake_minimum_required(VERSION 3.20)
project(SonicForever LANGUAGES C CXX OBJC OBJCXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
set(DEPS "${CMAKE_CURRENT_LIST_DIR}/../.build-deps")
set(ENGINE "${DEPS}/engine")
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST OFF CACHE BOOL "" FORCE)
set(SDL_TESTS OFF CACHE BOOL "" FORCE)
set(SDL_HIDAPI OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
add_subdirectory("${DEPS}/SDL2" SDL2 EXCLUDE_FROM_ALL)
# Build codecs from pinned sources, avoiding host-library discovery in cross builds.
add_library(ogg STATIC "${DEPS}/ogg/src/bitwise.c" "${DEPS}/ogg/src/framing.c")
target_include_directories(ogg PUBLIC "${DEPS}/ogg/include")
set(VORBIS_NAMES mdct smallft block envelope window lsp lpc analysis synthesis psy info floor1 floor0 res0 mapping0 registry codebook sharedbook lookup bitrate vorbisfile)
set(VORBIS_SOURCES)
foreach(name IN LISTS VORBIS_NAMES)
  list(APPEND VORBIS_SOURCES "${DEPS}/vorbis/lib/${name}.c")
endforeach()
add_library(vorbis STATIC ${VORBIS_SOURCES})
target_include_directories(vorbis PUBLIC "${DEPS}/vorbis/include" PRIVATE "${DEPS}/vorbis/lib")
target_link_libraries(vorbis PUBLIC ogg)
file(GLOB ENGINE_SOURCES CONFIGURE_DEPENDS "${ENGINE}/RSDKv4/*.cpp" "${ENGINE}/RSDKv4/NativeObjects/*.cpp")
add_executable(SonicForever MACOSX_BUNDLE ${ENGINE_SOURCES}
  "${ENGINE}/RSDKv4/fcaseopen.c"
  "${ENGINE}/dependencies/all/tinyxml2/tinyxml2.cpp"
  Startup.mm)
target_include_directories(SonicForever PRIVATE "${ENGINE}/RSDKv4" "${ENGINE}/RSDKv4/NativeObjects" "${ENGINE}/dependencies/all/stb-image" "${ENGINE}/dependencies/all/tinyxml2")
target_compile_definitions(SonicForever PRIVATE RETRO_USE_SDL2=1 RETRO_USE_MOD_LOADER=1 RETRO_USE_NETWORKING=0 RETRO_USING_OPENGL=1 RETRO_USE_ORIGINAL_CODE=0 RSDK_REVISION=3 RSDK_AUTOBUILD=1 DECOMP_VERSION="1.3.3-ios" RETRO_DEV_EXTRA="iOS")
target_compile_options(SonicForever PRIVATE $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>)
target_link_libraries(SonicForever PRIVATE SDL2::SDL2main SDL2::SDL2-static vorbis "-framework UIKit" "-framework Foundation" "-framework OpenGLES")
set_target_properties(SonicForever PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_LIST_DIR}/Info.plist"
  XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.jentisalive.sonicforever"
  XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED NO
  XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
  XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0"
  XCODE_ATTRIBUTE_ENABLE_BITCODE NO)
