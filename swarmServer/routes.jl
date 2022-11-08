using Genie.Router
using Reactive
using DataStructures
using CSV
using DataFrames

route("/") do 
    Genie.Renderer.redirect("https://cif-cold-stage.github.io/server")
end

route("/test") do
    "Hello World!"
end

function service_create(str, n, image, internalport)
    p = port_base[str]
    s = String.(split(str, "_"))
    function instance(i)
        op = p + i
        if image == "mdpetters/apn"
            read(
                `docker service create -d --name=$(str)-$(i) --publish $(op):$(internalport) --network=$(s[1]) $(image)` # jupyter notebook --NotebookApp.token= --NotebookApp.password=`,
            )
        else
            read(
                `docker service create -d --name=$(str)-$(i) --publish $(op):$(internalport) --network=$(s[1]) $(image)`,
            )
        end
    end
    map(instance, 0:n-1)
end

IP = "152.1.109.64"

# Service virtualDMA: "swarm_vdma"
lab1 = "swarm_vdma"
n_clients1 = 25
vdma_ports = Stack{Int}()
image1 = "mdpetters/virtualdma:server"

lab2 = "swarm_htestbed"
testbed_ports = Stack{Int}()
n_clients2 = 25
image2 = "mdpetters/testbed:server"

lab3 = "swarm_apn"
apn_ports = Stack{Int}()
n_clients3 = 50
image3 = "mdpetters/apn"

lab4 = "swarm_tutorial"
tutorial_ports = Stack{Int}()
n_clients4 = 25
image4 = "mdpetters/data-inversion-tutorial:v2009"

lab5 = "swarm_invert"
invert_ports = Stack{Int}()
n_clients5 = 10
image5 = "mdpetters/inverttdma:server"

resolve_ports = Dict(lab1 => vdma_ports, lab2 => testbed_ports, lab3 => apn_ports, lab4 => tutorial_ports, lab5 => invert_ports)
port_base = Dict{String,Int}(lab1 => 1000, lab2 => 1030, lab3 => 1070, lab4 => 1140, lab5 => 1260)

map(i -> push!(resolve_ports[lab1], i), port_base[lab1]:port_base[lab1]+n_clients1-1)
map(i -> push!(resolve_ports[lab2], i), port_base[lab2]:port_base[lab2]+n_clients2-1)
map(i -> push!(resolve_ports[lab3], i), port_base[lab3]:port_base[lab3]+n_clients3-1)
map(i -> push!(resolve_ports[lab4], i), port_base[lab4]:port_base[lab4]+n_clients4-1)
map(i -> push!(resolve_ports[lab5], i), port_base[lab5]:port_base[lab5]+n_clients4-1)

run(`docker network create -d overlay swarm --attachable`)
service_create(lab1, n_clients1, image1, 1234)
service_create(lab2, n_clients2, image2, 1234)
service_create(lab3, n_clients3, image3, 8888)
service_create(lab4, n_clients4, image4, 8888)
service_create(lab5, n_clients5, image5, 1234)

sleep(60 * 5)

stack = DataFrame(checkout = now(), str = "", ID = "", port = 0000)

function communicate(cmd::Cmd, input)
    inp = Pipe()
    out = Pipe()
    err = Pipe()

    process = run(pipeline(cmd, stdin=inp, stdout=out, stderr=err), wait=false)
    close(out.in)
    close(err.in)

    stdout = @async String(read(out))
    stderr = @async String(read(err))
    write(process, input)
    close(inp)
    wait(process)
    return (
        stdout = fetch(stdout),
        stderr = fetch(stderr),
        code = process.exitcode
    )
end

# Service 
route("virtualTDMA") do
    if isempty(vdma_ports)
        "Sorry, all containers are checked out. This resource is currently unavailable. Please check back again later. If this issue persists, please contact mdpetter@ncsu.edu"
    else
        p1 = pop!(resolve_ports[lab1])
        println("Checking out port $(p1)")
        println("Available ports")
        println(resolve_ports[lab1])
        containerID, containerStr, netIO, ports = stats()
        df = DataFrame(checkout = now(), str = containerStr, ID = containerID, port = ports)
        IDf = filter(:port => x -> x == p1, df)
        global stack = vcat(stack, IDf)
        df = DataFrame(t = now(), app = "virtualTDMA")
        df |> CSV.write("request.txt", append = true)
        Genie.Renderer.redirect("http://notebooks.meas.ncsu.edu:$(p1)/open?path=webapp.jl")
    end
end

route("hygroscopicityTestbed") do
    if isempty(testbed_ports)
        "Sorry, all containers are checked out. This resource is currently unavailable. Please check back again later. If this issue persists, please contact mdpetter@ncsu.edu"
    else
        p2 = pop!(resolve_ports[lab2])
        println("Checking out port $(p2)")
        println("Available ports")
        println(resolve_ports[lab2])
        containerID, containerStr, netIO, ports = stats()
        df = DataFrame(checkout = now(), str = containerStr, ID = containerID, port = ports)
        IDf = filter(:port => x -> x == p2, df)
        global stack = vcat(stack, IDf)
        df = DataFrame(t = now(), app = "hygroscopityTestbed")
        df |> CSV.write("request.txt", append = true)
        Genie.Renderer.redirect("http://notebooks.meas.ncsu.edu:$(p2)/open?path=webapp.jl")
    end
end

route("apn") do
    if isempty(apn_ports)
        "Sorry, all containers are checked out. This resource is currently unavailable. Please check back again later. If this issue persists, please contact mdpetter@ncsu.edu"
    else
        p3 = pop!(resolve_ports[lab3])
        println("Checking out port $(p3)")
        println("Available ports")
        println(resolve_ports[lab3])
        containerID, containerStr, netIO, ports = stats()
        df = DataFrame(checkout = now(), str = containerStr, ID = containerID, port = ports)
        IDf = filter(:port => x -> x == p3, df)
        global stack = vcat(stack, IDf)
        ID = IDf[1,:ID]
        logs = communicate(`docker logs $(ID)`, "") 
        token = split(split(logs.stderr, "token=")[2], "\n")[1]
        df = DataFrame(t = now(), app = "apn")
        df |> CSV.write("request.txt", append = true)
        Genie.Renderer.redirect("http://notebooks.meas.ncsu.edu:$(p3)/?token=$(token)")
    end
end

route("invertHTDMA") do
	if isempty(testbed_ports)
		"Sorry, all containers are checked out. This resource is currently unavailable. Please check back again later. If this issue persists, please contact mdpetter@ncsu.edu"
	else
		p4 = pop!(resolve_ports[lab4])
		println("Checking out port $(p5)")
		println("Available ports")
		println(resolve_ports[lab5])
        containerID, containerStr, netIO, ports = stats()
        df = DataFrame(checkout = now(), str = containerStr, ID = containerID, port = ports)
        IDf = filter(:port => x -> x == p5, df)
        global stack = vcat(stack, IDf)
        df = DataFrame(t = now(), app = "invertTDMA")
        df |> CSV.write("request.txt", append = true)
		Genie.Renderer.redirect("http://notebooks.meas.ncsu.edu:$(p5)/open?path=webapp.jl")
	end
end

route("inversionTutorial") do
    if isempty(apn_ports)
        "Sorry, all containers are checked out. This resource is currently unavailable. Please check back again later. If this issue persists, please contact mdpetter@ncsu.edu"
    else
        p4 = pop!(resolve_ports[lab4])
        println("Checking out port $(p4)")
        println("Available ports")
        println(resolve_ports[lab4])
        containerID, containerStr, netIO, ports = stats()
        df = DataFrame(checkout = now(), str = containerStr, ID = containerID, port = ports)
        IDf = filter(:port => x -> x == p4, df)
        global stack = vcat(stack, IDf)
        ID = IDf[1,:ID]
        logs = communicate(`docker logs $(ID)`, "") 
        token = split(split(logs.stderr, "token=")[2], "\n")[1]
        df = DataFrame(t = now(), app = "tutorial")
        df |> CSV.write("request.txt", append = true)
        Genie.Renderer.redirect("http://notebooks.meas.ncsu.edu:$(p4)/?token=$(token)")
    end
end

include("monitor.jl")
containerActivity = Signal(Dict{String,Number}())
timer = fps(1.0 / (10.0 * 60.0))
mylog = map(_ -> containerManager(), timer)