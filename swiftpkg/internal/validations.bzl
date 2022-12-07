"""Module for validating argument values."""

def _in_list(valid_values, value, err_msg = None):
    is_valid = False
    for valid_value in valid_values:
        if value == valid_value:
            is_valid = True
            break
    if not is_valid and err_msg != None:
        fail(err_msg, value)
    return is_valid

validations = struct(
    in_list = _in_list,
)
