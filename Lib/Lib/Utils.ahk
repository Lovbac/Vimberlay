; ==============================================================================
; A bunch of unclassified generic utilities
; ==============================================================================

GenerateUUID() => SubStr(ComObject("Scriptlet.TypeLib").Guid, 2, 36)

JsonType := {
    String: "String",
    Bool: "Bool",
    Number: "Number",
    Raw: "Raw",
}

ToJson(properties*) {
    json := "{ "
    for index, prop in properties {
        if (prop) {
            json .= _ToJsonProperty(prop.Key, prop.Value, prop.Type)
            json .= ", "
        }
    }
    json := SubStr(json, 1, -2) ; Remove trailing comma and space
    return json . " }"

    _ToJsonProperty(key, value, type) {
        jsonProperty := "`"" . key . "`": "

        if (type == JsonType.String) {
            jsonProperty := jsonProperty . "`"" . value . "`""
        } else if (type == JsonType.Bool) {
            jsonProperty := jsonProperty . (value ? "true" : "false")
        } else if (type == JsonType.Number) {
            jsonProperty := jsonProperty . value
        } else if (type == JsonType.Raw) {
            jsonProperty := jsonProperty . value
        } else {
            throw Error("Unhandled Json type: " . type)
        }

        return jsonProperty
    }
}

ApplyMap(enumerable, callback) {
    result := []
    if (callback.MaxParams >= 2 || callback.IsVariadic) {
        for k, v in enumerable
            result.Push(callback(v, k))
    } else {
        for k, v in enumerable
            result.Push(callback(v))
    }
    return result
}

; This does not return keys for any non-Map enumerable.
; To get key-value pairs, convert to a Map before calling.
; E.g. Map(enumerable*)
ApplyFilter(enumerable, callback) {
    if (Type(enumerable) = "Map") {
        return _ApplyMapFilter(enumerable, callback)
    } else {
        return _ApplyFilter(enumerable, callback)
    }

    _ApplyMapFilter(enumerable, callback) {
        result := Map()
        for k, v in enumerable
            if (callback(v, k)) {
                result[k] := v
            }
        return result
    }

    _ApplyFilter(enumerable, callback) {
        result := []
        if (callback.MaxParams >= 2 || callback.IsVariadic) {
            for k, v in enumerable {
                if (callback(v, k)) {
                    result.Push(v)
                }
            }
        } else {
            for k, v in enumerable {
                if (callback(v)) {
                    result.Push(v)
                }
            }
        }
        return result
    }
}

GetPublicProps(obj) {
    props := Map()
    for k, v in obj.OwnProps() {
        if (k != "Prototype" && SubStr(k, 1, 1) != "_")
            props[k] := v
    }
    return props
}

StrLowerFirst(str) {
    if (str = "")
        return ""
    return StrLower(SubStr(str, 1, 1)) . SubStr(str, 2)
}
