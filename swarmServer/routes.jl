using Genie.Router
using Reactive
using DataStructures

route("/test") do
	"Hello World!"
end

function service_create(str, n, image)
	p = port_base[str]
	s = String.(split(str, "_"))
	function instance(i)
		op = p + i
		read(`docker service create -d --name=$(str)-$(i) --publish $(op):1234 --network=$(s[1]) $(image)`)
	end
	map(instance, 0:n-1)
end

IP = "207.154.231.171"

# Service virtualDMA: "swarm_vdma"
lab1 = "swarm_vdma"
n_clients1 = 2
vdma_ports = Stack{Int}()
image1 = "mdpetters/virtualdma:server"

lab2 = "swarm_htestbed"
testbed_ports = Stack{Int}()
n_clients2 = 2
image2 = "mdpetters/testbed:server"
 
resolve_ports = Dict(lab1 => vdma_ports, lab2 => testbed_ports)
port_base = Dict{String, Int}(lab1 => 1000, lab2 => 1050)

map(i -> push!(resolve_ports[lab1], i), port_base[lab1]:port_base[lab1]+n_clients1-1)
map(i -> push!(resolve_ports[lab2], i), port_base[lab1]:port_base[lab2]+n_clients2-1)

run(`docker network create -d overlay swarm --attachable`)
service_create(lab1, n_clients1, image1)
service_create(lab2, n_clients2, image2)

sleep(60*15)

# Service 
route("virtualTDMA") do
	if isempty(vdma_ports)
		"Sorry, all containers are checked out. This resource is currently unavailable. Please check back again later. If this issue persists, please contact mdpetter@ncsu.edu"
	else
		p = pop!(resolve_ports[lab1])
		Genie.Renderer.redirect("http://$(IP):$(p)/open?path=webapp.jl")
	end
end

route("hygroscopicityTestbed") do
	if isempty(testbed_ports)
		"Sorry, all containers are checked out. This resource is currently unavailable. Please check back again later. If this issue persists, please contact mdpetter@ncsu.edu"
	else
		p = pop!(resolve_ports[lab2])
		Genie.Renderer.redirect("http://$(IP):$(p)/open?path=webapp.jl")
	end
end


include("monitor.jl")
containerActivity = Signal(Dict{String, Number}())
timer = fps(1.0/(15.0*60.0))
mylog = map(_ -> containerManager(), timer)
