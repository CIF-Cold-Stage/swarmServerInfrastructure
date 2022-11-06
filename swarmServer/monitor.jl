using Dates
using SHA
using DataFrames
using CSV
using JSON

hashlog(ID) = (read(`docker logs $(ID)`) |> sha256 |> bytes2hex)
containerDestroyByID(ID) = read(`docker rm -f $(ID)`)

function servicePort(str)
	a = read(`docker service inspect $(str)`, String) |> JSON.parse
	return a[1]["Spec"]["EndpointSpec"]["Ports"][1]["PublishedPort"]
end

function stats()
	a = read(`docker stats --no-stream`, String)

	b = split(a, '\n')
	c = map(x -> split(x), b)
	containerID = map(x -> String(x[1]), c[2:end-1])
	containerStr = map(x -> String(x[2] |> x -> split(x, '.')[1]), c[2:end-1]) 
	NetIO = map(x -> x[10], c[2:end-1])

	function mparse(x)
		N = try 
			parse(Float64, x)
		catch
			nothing
		end
	end

	function parseIO(x)
		testunit(x, unit) = split(x, unit)[1] |> mparse

		testunit(x, "MB")
		if ~isnothing(testunit(x,"MB"))
			return (testunit(x, "MB"), "MB")
		elseif ~isnothing(testunit(x,"kB"))
			return (testunit(x, "kB"), "kB")
		elseif ~isnothing(testunit(x,"B"))
			return (testunit(x, "B"), "B")
		else
			return (0, "unknown")
		end
	end

	function netIOtoBytes(val)
		if (val[2] == "B")  
			return val[1]
		elseif (val[2] == "kB") 
			return val[1] * 1024 
		elseif (val[2] == "MB") 
			return val[1] * 1024 * 1024 
		elseif (val[2] == "GiB") 
			return val[1] * 1024 * 1024 * 1024
		else
			return 0
		end
	end

	parsedNetIO = map(parseIO, NetIO)
	cleanNetIO = map(netIOtoBytes, parsedNetIO)
	return containerID, containerStr, cleanNetIO
end

function containerAgeByID(ID)
	c = read(`docker ps -f "ID=$(ID)" --format "{{.CreatedAt}}"`, String)
	if c == ""
		return nothing
	end
	d = split(c) |> x -> String.(x)
	t = Date(d[1], dateformat"YYYY-mm-dd") + Time(d[2], dateformat"HH:MM:SS")
	age = round(now() - t, Minute)
end

function updateActivity(containerActivity, ID, netIO)
	try
		netIO - containerActivity.value[ID]
	catch
		netIO
	end
end

function regenerate_service(containerStr::String, port::Int, delay::Int)
	sleep(delay)
	z = String.(split(containerStr, '-'))
    thisPort = servicePort(containerStr)
	if thisPort ∉ resolve_ports[z[1]]
		println("Port was checked out, regenerate")
		push!(resolve_ports[z[1]], port)
	else
		println("Container regenerated, but container was not checked out")
	end
end

function containerManager()
	containerID, containerStr, netIO = stats()
	age = map(containerAgeByID, containerID)
	activity = map((x,y) -> updateActivity(containerActivity,x,y), containerID, netIO)
	map((x,y) -> containerActivity.value[x] = y, containerID, netIO)

	taintedFlag = map(containerID, containerStr) do x,y
		z = String.(split(y, '-'))
		# hash = open(f->read(f, String), z[1])
        thisPort = servicePort(y)
		println(y, "  ", thisPort, "  ", resolve_ports[z[1]])
		# (hashlog(x) != hash) || (thisPort ∉ resolve_ports[z[1]])
		thisPort ∉ resolve_ports[z[1]]
	end

	log = DataFrame(
		t = now(), 
		containerID = containerID, 
		containerStr = containerStr, 
		age = age, 
		netIO = netIO, 
		activity = activity, 
		taintedFlag = taintedFlag
	)

	function destroyContainer(containerID, containerStr, age, taintedFlag, activity)
		if (age > Minute(100)) && tainted
			z = String.(split(containerStr, '-'))
			port = port_base[z[1]] + parse(Int, z[2])
			println("Destroy $(containerID)")
			println("Restore Service port: $(port)")
			containerDestroyByID(containerID)          
			@async regenerate_service(containerStr, port, 300) # restore to pool w/300s delay 
		end

		return nothing
	end

	map(destroyContainer, containerID, containerStr, age, taintedFlag, activity)
	log |> CSV.write("logfile.csv", append = true)
	show(log)
	println()

	return log
end

