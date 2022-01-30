using Genie.Router
using Reactive
using DataStructures

route("/test") do
	"Hello World!"
end

function service_create(str, n)
	p = port_base[str]
	s = String.(split(str, "_"))
	read(`docker network create -d overlay $(s[1]) --attachable`)
	function instance(i)
		op = p + i
		read(`docker service create -d --name=$(str)-$(i) --publish $(op):1234 --network=$(s[1]) mdpetters/virtualdma:server`)
	end
	map(instance, 0:n-1)
end

IP = "0.0.0.0"

# Service virtualDMA: "swarm_vdma"
lab = "swarm_vdma"
n_clients = 5
vdma_ports = Stack{Int}()
resolve_ports = Dict(lab => vdma_ports)
port_base = Dict{String, Int}([lab => 1000])
map(i -> push!(resolve_ports[lab], i), 
	port_base[lab]:port_base[lab]+n_clients-1)
service_create(lab, n_clients)

sleep(60*15)

# Service 
route("virtualTDMA") do
	if isempty(vdma_ports)
		"Sorry, all containers are checked out. This resource is currently unavailable. Please check back again later. If this issue persists, please contact mdpetter@ncsu.edu"
	else
		p = pop!(resolve_ports[lab])
		Genie.Renderer.redirect("http://$(IP):$(p)/open?path=webapp.jl")
	end
end

include("monitor.jl")
containerActivity = Signal(Dict{String, Number}())
timer = fps(1.0/(15.0*60.0))
mylog = map(_ -> containerManager(), timer)
