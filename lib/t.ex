a = 1
f = fn -> a end
a = 2
IO.puts("a: #{a}")
IO.puts("f(): #{f.()}")
