# Copyright (C) 2012 Dominik Picheta
# MIT License - Look at license.txt for details.
import parseutils, strtabs, strutils, tables
from cgi import urlDecode

type
  TMultiData = TTable[string, tuple[fields: PStringTable, body: string]]

proc parseUrlQuery*(query: string, result: var PStringTable) =
  var i = 0
  i = query.skip("?")
  while i < query.len()-1:
    var key = ""
    var val = ""
    i += query.parseUntil(key, '=', i)
    if query[i] != '=':
      raise newException(EInvalidValue, "Expected '=' at " & $i &
                         " but got: " & $query[i])
    inc(i) # Skip =
    i += query.parseUntil(val, '&', i)
    inc(i) # Skip &
    result[urlDecode(key)] = urlDecode(val)

template parseContentDisposition(): stmt =
  var hCount = 0
  while hCount < hValue.len()-1:
    var key = ""
    hCount += hValue.parseUntil(key, {';', '='}, hCount)
    if hValue[hCount] == '=':
      var value = hvalue.captureBetween('"', start = hCount)
      hCount += value.len+2
      inc(hCount) # Skip ;
      hCount += hValue.skipWhitespace(hCount)
      if key == "name": name = value
      newPart[0][key] = value
    else:
      inc(hCount)
      hCount += hValue.skipWhitespace(hCount)

proc parseMultiPart*(body: string, boundary: string): TMultiData =
  result = initTable[string, tuple[fields: PStringTable, body: string]]()
  var mboundary = "--" & boundary
  
  var i = 0
  var partsLeft = true
  while partsLeft:
    var firstBoundary = body.skip(mboundary, i)
    if firstBoundary == 0:
      raise newException(EInvalidValue, "Expected boundary. Got: " & body.substr(i, i+25))
    i += firstBoundary
    i += body.skipWhitespace(i)
    
    # Headers
    var newPart: tuple[fields: PStringTable, body: string] = ({:}.newStringTable, "")
    var name = ""
    while true:
      if body[i] == '\c':
        inc(i, 2) # Skip \c\L
        break
      var hName = ""
      i += body.parseUntil(hName, ':', i)
      if body[i] != ':':
        raise newException(EInvalidValue, "Expected : in headers.")
      inc(i) # Skip :
      i += body.skipWhitespace(i)
      var hValue = ""
      i += body.parseUntil(hValue, {'\c', '\L'}, i)
      if hName.toLower == "content-disposition":
        parseContentDisposition()
      newPart[0][hName] = hValue
      i += body.skip("\c\L", i) # Skip *one* \c\L
    
    # Parse body.
    while true:
      if body[i] == '\c' and body[i+1] == '\L':
        if body.skip(mboundary, i+2) != 0:
          if body.skip("--", i+2+mboundary.len) != 0:
            partsLeft = false
            break
          break
      else:
        newPart[1].add(body[i])
      inc(i)
    i += body.skipWhitespace(i)
    
    result[name] = newPart
    
proc parseMPFD*(contentType: string, body: string): TMultiData =
  var boundaryEqIndex = contentType.find("boundary=")+9
  var boundary = contentType.substr(boundaryEqIndex, contentType.len()-1)
  return parseMultiPart(body, boundary)

when isMainModule:
  var r = {:}.newStringTable
  parseUrlQuery("FirstName=Mickey", r)
  echo r
  