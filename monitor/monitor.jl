using Dates
using SHA
using DataFrames
using CSV

hashlog(ID) = (read(`docker logs $(ID)`) |> sha256 |> bytes2hex)
containerDestroyByID(ID) = read(`docker rm -f $(ID)`)

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
		netIO - containerActivity[ID]
	catch
		netIO
	end
end

function containerManager(containerActivity)
	containerID, containerStr, netIO = stats()
	age = map(containerAgeByID, containerID)
	activity = map((x,y) -> updateActivity(containerActivity,x,y), containerID, netIO)
	map((x,y) -> containerActivity[x] = y, containerID, netIO)

	taintedFlag = map(containerID, containerStr) do x,y
		hash = open(f->read(f, String), y)
		hashlog(x) != hash
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

	function destroyContainer(containerID, age, taintedFlag, activity)
		if (age > Minute(30)) && taintedFlag && (activity < 1.0)
			println("Destroy $(containerID)")
			containerDestroyByID(containerID)
		end
		return nothing
	end

	map(destroyContainer, containerID, age, taintedFlag, activity)
	return containerActivity, log
end

function main()
	containerActivity = Dict{String, Number}()		
	
	while true
		containerActivity, log = containerManager(containerActivity)
		show(log)
		println()
		log |> CSV.write("logfile.csv", append = true)
		sleep(30*60)
	end
end
