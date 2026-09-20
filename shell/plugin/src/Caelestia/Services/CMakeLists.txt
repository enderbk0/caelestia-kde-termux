find_package(KF6GlobalAccel QUIET)
find_package(KF6Config REQUIRED)
find_package(KF6NetworkManagerQt QUIET)
find_package(X11 QUIET)
# For QPlatformNativeInterface, the only way to reach a QWindow's wl_surface:
# Qt exposes no public native interface for it. Ships with qt6-base on Arch and
# with qt6-qtbase-private-devel on Fedora, both already installed by setup.
find_package(Qt6 REQUIRED COMPONENTS GuiPrivate)
# Cava audio visualizer — optional on systems where it's not packaged.
set(CAVA_SOURCES "")
set(CAVA_LIBRARIES "")
if(Cava_FOUND)
    list(APPEND CAVA_SOURCES cavaprovider.cpp cavaprovider.hpp)
    list(APPEND CAVA_LIBRARIES PkgConfig::Cava)
endif()
# Sensors — always compile sensorslib.cpp (it has a stub when lm_sensors is missing)
set(SENSORS_LIBRARIES "")
if(Sensors_FOUND)
    set(SENSORS_LIBRARIES Sensors::Sensors)
endif()
# Aubio — optional on systems where it's not packaged
# Always compile beattracker.cpp (it has a stub when aubio is missing)
set(AUBIO_LIBRARIES "")
if(Aubio_FOUND)
    set(AUBIO_LIBRARIES PkgConfig::Aubio)
endif()
# NetworkManagerQt — optional, but always compile NmQt (has stubs)
set(NETWORKMANAGER_LIBRARIES "")
if(KF6NetworkManagerQt_FOUND)
    set(NETWORKMANAGER_LIBRARIES KF6::NetworkManagerQt)
endif()
# PulseAudioQt — optional
set(PULSEAUDIO_LIBRARIES "")
if(KF6PulseAudioQt_FOUND)
    set(PULSEAUDIO_LIBRARIES KF6::PulseAudioQt)
endif()
# X11 — optional (not available in Termux)
set(X11_LIBRARIES "")
if(X11_FOUND)
    set(X11_LIBRARIES X11::X11)
endif()
# KGlobalAccel — optional
set(KGLOBALACCEL_LIBRARIES "")
if(KF6GlobalAccel_FOUND)
    set(KGLOBALACCEL_LIBRARIES KF6::GlobalAccel)
endif()

qml_module(caelestia-services
    URI Caelestia.Services
    SOURCES
        service.cpp
        serviceref.cpp
        beattracker.cpp
        beattracker.hpp
        audiocollector.cpp
        audioprovider.cpp
        audiodevicebackend.cpp
        audiodevicebackend.hpp
        ${CAVA_SOURCES}
        tickingservice.cpp
        sensorslib.cpp
        usagefmt.cpp
        networkusage.cpp
        networkusage.hpp
        cpu.cpp
        gpu.cpp
        memory.cpp
        diskinfo.cpp
        storage.cpp
        weather.cpp
        weather.hpp
        lyriccandidate.cpp
        lyrics.cpp
        sessionmanager.cpp
        sessionmanager.hpp
        discordipc.cpp
        discordipc.hpp
        hyprlandstate.cpp
        hyprlandstate.hpp
        hyprdevices.cpp
        hyprdevices.hpp
        hyprextras.cpp
        hyprextras.hpp
        keybindsmodel.cpp
        keybindsmodel.hpp
        emojidb.cpp
        emojidb.hpp
        brightnesswatcher.cpp
        brightnesswatcher.hpp
        clipboardmanager.cpp
        clipboardmanager.hpp
        schemeloader.cpp
        schemeloader.hpp
        palettemanager.cpp
        palettemanager.hpp
        dinogame.cpp
        dinogame.hpp
        kwinworkspacestate.cpp
        kwinworkspacestate.hpp
        kwinactivewindowbridge.cpp
        windowicon.cpp
        kwinactivewindowbridge.hpp
        nightcolorbridge.cpp
        nightcolorbridge.hpp
        globalshortcut.cpp
        globalshortcut.hpp
        krohnkiteconfig.cpp
        krohnkiteconfig.hpp
        windowscreencast.cpp
        windowscreencast.hpp
        windowstream.cpp
        windowstream.hpp
        windowicon.hpp
        minimizegeometry.cpp
        minimizegeometry.hpp
        plasmawindows.cpp
        plasmawindows.hpp
        plasmawindowicon.cpp
        plasmawindowicon.hpp
        screenedges.cpp
        screenedges.hpp
        NmQt.cpp
        NmQt.hpp
    LIBRARIES
        Qt::DBus
        Qt::Network
        Qt::Gui
        Qt::Quick
        Qt::GuiPrivate
        Qt::WaylandClient
        ${KGLOBALACCEL_LIBRARIES}
        KF6::ConfigCore
        ${X11_LIBRARIES}
        ${AUBIO_LIBRARIES}
        ${CAVA_LIBRARIES}
        ${SENSORS_LIBRARIES}
        ${PULSEAUDIO_LIBRARIES}
        ${NETWORKMANAGER_LIBRARIES}
        PkgConfig::Pipewire
        caelestia-core
        caelestia-config
)

# Termux/limited-environment compatibility definitions
# These are passed as -D flags so every translation unit sees them
target_compile_definitions(caelestia-services PRIVATE
    $<$<NOT:$<BOOL:${Sensors_FOUND}>>:CAELESTIA_HAS_SENSORS=0>
    $<$<BOOL:${Sensors_FOUND}>:CAELESTIA_HAS_SENSORS=1>
    $<$<NOT:$<BOOL:${Aubio_FOUND}>>:CAELESTIA_HAS_AUBIO=0>
    $<$<BOOL:${Aubio_FOUND}>:CAELESTIA_HAS_AUBIO=1>
    $<$<NOT:$<BOOL:${Cava_FOUND}>>:CAELESTIA_HAS_CAVA=0>
    $<$<BOOL:${Cava_FOUND}>:CAELESTIA_HAS_CAVA=1>
    $<$<NOT:$<BOOL:${KF6GlobalAccel_FOUND}>>:CAELESTIA_HAS_KGLOBALACCEL=0>
    $<$<BOOL:${KF6GlobalAccel_FOUND}>:CAELESTIA_HAS_KGLOBALACCEL=1>
    $<$<NOT:$<BOOL:${X11_FOUND}>>:CAELESTIA_HAS_X11=0>
    $<$<BOOL:${X11_FOUND}>:CAELESTIA_HAS_X11=1>
    $<$<NOT:$<BOOL:${KF6PulseAudioQt_FOUND}>>:CAELESTIA_HAS_PULSEAUDIO=0>
    $<$<BOOL:${KF6PulseAudioQt_FOUND}>:CAELESTIA_HAS_PULSEAUDIO=1>
    $<$<NOT:$<BOOL:${KF6NetworkManagerQt_FOUND}>>:CAELESTIA_HAS_NETWORKMANAGER=0>
    $<$<BOOL:${KF6NetworkManagerQt_FOUND}>:CAELESTIA_HAS_NETWORKMANAGER=1>
    CAELESTIA_HAS_KWIN_WAYLAND=1
)



qt6_generate_wayland_protocol_client_sources(caelestia-services FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/../protocols/zkde-screencast-unstable-v1.xml
    ${CMAKE_CURRENT_SOURCE_DIR}/../protocols/plasma-window-management.xml
    ${CMAKE_CURRENT_SOURCE_DIR}/../protocols/kde-output-device-v2.xml
    ${CMAKE_CURRENT_SOURCE_DIR}/../protocols/kde-output-management-v2.xml
)
set_source_files_properties(
    ${CMAKE_CURRENT_BINARY_DIR}/wayland-zkde-screencast-unstable-v1-protocol.c
    ${CMAKE_CURRENT_BINARY_DIR}/wayland-plasma-window-management-protocol.c
    ${CMAKE_CURRENT_BINARY_DIR}/wayland-kde-output-device-v2-protocol.c
    ${CMAKE_CURRENT_BINARY_DIR}/wayland-kde-output-management-v2-protocol.c
    PROPERTIES SKIP_PRECOMPILE_HEADERS ON
)
