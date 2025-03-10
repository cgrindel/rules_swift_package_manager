#include <string.h>
#include <stdio.h>
#include "MyClangLibrary/API.h"

static int g_initialized = 0;

MyclangStatus myclang_initialize(void) {
    if (g_initialized) {
        return MYCLANG_ERROR_INVALID_ARGUMENT;
    }
    g_initialized = 1;
    return MYCLANG_SUCCESS;
}

MyclangStatus myclang_cleanup(void) {
    if (!g_initialized) {
        return MYCLANG_ERROR_NOT_INITIALIZED;
    }
    g_initialized = 0;
    return MYCLANG_SUCCESS;
}

MyclangStatus myclang_create_object(MyclangObject* obj, 
                                  const char* name,
                                  unsigned int id,
                                  double value) {
    if (!g_initialized) {
        return MYCLANG_ERROR_NOT_INITIALIZED;
    }
    
    if (!obj || !name) {
        return MYCLANG_ERROR_INVALID_ARGUMENT;
    }
    
    if (strlen(name) >= MYCLANG_MAX_NAME_LENGTH) {
        return MYCLANG_ERROR_BUFFER_OVERFLOW;
    }
    
    strncpy(obj->name, name, MYCLANG_MAX_NAME_LENGTH - 1);
    obj->name[MYCLANG_MAX_NAME_LENGTH - 1] = '\0';
    obj->id = id;
    obj->value = value;
    
    return MYCLANG_SUCCESS;
}

MyclangStatus myclang_process_object(const MyclangObject* obj) {
    if (!g_initialized) {
        return MYCLANG_ERROR_NOT_INITIALIZED;
    }
    
    if (!obj) {
        return MYCLANG_ERROR_INVALID_ARGUMENT;
    }
    
    // Example processing - in real implementation, this would do something useful
    return MYCLANG_SUCCESS;
}

const char* myclang_get_version_string(void) {
    static char version[32];
    snprintf(version, sizeof(version), "%d.%d.%d", 
             MYCLANG_VERSION_MAJOR,
             MYCLANG_VERSION_MINOR,
             MYCLANG_VERSION_PATCH);
    return version;
}

const char* myclang_get_farewell_message(MyclangFarewellType type) {
    switch (type) {
        case MYCLANG_FAREWELL_GOODBYE:
            return "Goodbye";
        case MYCLANG_FAREWELL_PARTING:
            return "Parting";
        case MYCLANG_FAREWELL_SEE_YOU_LATER:
            return "See you later";
        case MYCLANG_FAREWELL_TAKE_CARE:
            return "Take care";
        case MYCLANG_FAREWELL_ADIEU:
            return "Adieu";
        case MYCLANG_FAREWELL_DEPARTURE:
            return "Departure";
        default:
            return "Goodbye";
    }
}
