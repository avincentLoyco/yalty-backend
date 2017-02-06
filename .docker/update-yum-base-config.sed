$ {
  H
  x
  /^\[base\]/ {
    s/\n\+$//
    a exclude=postgresql*
    x
  }
  x
  p
  d
}
/^\[base\]/,/^\[/ {
  x
  /^$/ !{ x; H }
  /^$/  { x; h }
  d
}
x
/^\[base\]/ {
  s/\(\n\+[^\n]*\)$/\nexclude=postgresql*\1/
  p
  x
  p
  x
  d
}
x
p
