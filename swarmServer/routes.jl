using Genie.Router
using Reactive
using DataStructures

route("/") do

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
                `docker service create -d --name=$(str)-$(i) --publish $(op):$(internalport) --network=$(s[1]) $(image) jupyter notebook --NotebookApp.token= --NotebookApp.password=`,
            )
        else
            read(
                `docker service create -d --name=$(str)-$(i) --publish $(op):$(internalport) --network=$(s[1]) $(image)`,
            )
        end
    end
    map(instance, 0:n-1)
end

IP = "127.0.0.1"

# Service virtualDMA: "swarm_vdma"
lab1 = "swarm_vdma"
n_clients1 = 2
vdma_ports = Stack{Int}()
image1 = "mdpetters/virtualdma:server"

lab2 = "swarm_htestbed"
testbed_ports = Stack{Int}()
n_clients2 = 2
image2 = "mdpetters/testbed:server"

lab3 = "swarm_apn"
apn_ports = Stack{Int}()
n_clients3 = 2
image3 = "mdpetters/apn"

resolve_ports = Dict(lab1 => vdma_ports, lab2 => testbed_ports, lab3 => apn_ports)
port_base = Dict{String,Int}(lab1 => 1000, lab2 => 1050, lab3 => 2000)

map(i -> push!(resolve_ports[lab1], i), port_base[lab1]:port_base[lab1]+n_clients1-1)
map(i -> push!(resolve_ports[lab2], i), port_base[lab2]:port_base[lab2]+n_clients2-1)
map(i -> push!(resolve_ports[lab3], i), port_base[lab3]:port_base[lab3]+n_clients3-1)

run(`docker network create -d overlay swarm --attachable`)
#service_create(lab1, n_clients1, image1, 1234)
#service_create(lab2, n_clients2, image2, 1234)
service_create(lab3, n_clients3, image3, 8888)

sleep(60 * 15)

# Service 
route("virtualTDMA") do
    if isempty(vdma_ports)
        "Sorry, all containers are checked out. This resource is currently unavailable. Please check back again later. If this issue persists, please contact mdpetter@ncsu.edu"
    else
        p1 = pop!(resolve_ports[lab1])
        println("Checking out port $(p1)")
        println("Available ports")
        println(resolve_ports[lab1])
        Genie.Renderer.redirect("http://$(IP):$(p1)/open?path=webapp.jl")
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
        Genie.Renderer.redirect("http://$(IP):$(p2)/open?path=webapp.jl")
    end
end

route("apn") do
    if isempty(apn_ports)
        "Sorry, all containers are checked out. This resource is currently unavailable. Please check back again later. If this issue persists, please contact mdpetter@ncsu.edu"
    else
        p2 = pop!(resolve_ports[lab2])
        println("Checking out port $(p2)")
        println("Available ports")
        println(resolve_ports[lab2])
        Genie.Renderer.redirect("http://$(IP):$(p2)/tree?")
    end
end


include("monitor.jl")
containerActivity = Signal(Dict{String,Number}())
timer = fps(1.0 / (15.0 * 60.0))
mylog = map(_ -> containerManager(), timer)
