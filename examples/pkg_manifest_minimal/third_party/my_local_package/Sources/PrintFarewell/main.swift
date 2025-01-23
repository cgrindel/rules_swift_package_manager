import FarewellFramework

let message = FarewellFramework.myclang_get_farewell_message(MYCLANG_FAREWELL_SEE_YOU_LATER)

let swiftString = String(cString: message!)

print(swiftString)
