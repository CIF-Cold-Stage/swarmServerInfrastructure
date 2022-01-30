include("monitor.jl")

containerID, containerStr, netIO = stats()

taintedFlag = map(containerID, containerStr) do x,y
	z = String.(split(y, '-'))
	println(z[1])
	hash = open(f->read(f, String), z[1])
	hashlog(x) != hash
end

