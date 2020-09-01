kb_from_struct = KeyBinding('c', KeyModifierState(ctrl=true))
kb_from_macro = key"ctrl+c"
@test kb_from_struct == kb_from_macro
@test string(kb_from_struct) == "ctrl+c"
@test KeyBinding("ctrl+c") == kb_from_struct