find_library(SENSORS_LIBRARY NAMES sensors)
find_path(SENSORS_INCLUDE_DIR NAMES sensors/sensors.h)
if(SENSORS_LIBRARY AND SENSORS_INCLUDE_DIR)
    if(NOT TARGET Sensors::Sensors)
        add_library(Sensors::Sensors UNKNOWN IMPORTED)
        set_target_properties(Sensors::Sensors PROPERTIES
            IMPORTED_LOCATION "${SENSORS_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${SENSORS_INCLUDE_DIR}"
        )
    endif()
    set(Sensors_FOUND TRUE)
else()
    message(STATUS "lm_sensors not found - sensor features disabled")
    set(Sensors_FOUND FALSE)
    if(NOT TARGET Sensors::Sensors)
        add_library(Sensors::Sensors INTERFACE IMPORTED)
    endif()
endif()
