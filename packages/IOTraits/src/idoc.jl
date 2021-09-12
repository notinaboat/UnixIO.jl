"""
    idoc"abc..."

Hide method implementation doc strings from online help.
Useful for doc strings that preceede methods of Base functions.
"""
macro idoc_str(s)
    :(($s; nothing))
end


