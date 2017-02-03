$ {
  H
  x
  /^\[updates\]/ {
    s/\n\+$//
    a exclude=postgresql*
    x
  }
  x
  p
  d
}
/^\[updates\]/,/^\[/ {
  x
  /^$/ !{ x; H }
  /^$/  { x; h }
  d
}
x
/^\[updates\]/ {
  s/\(\n\+[^\n]*\)$/\nexclude=postgresql*\1/
  p
  x
  p
  x
  d
}
x
p
