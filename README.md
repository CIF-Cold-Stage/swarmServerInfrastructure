# swarmServerInfrastructure

*Repository with scripts to deploy, log, and control a Docker swarm server hosting notebook based web applications*

# Problem Description
Web-based interactive computing platforms such as [Jupyter](https://jupyter.org/) or [Pluto](https://github.com/fonsp/Pluto.jl) notebooks are becoming increasingly popular tools for supporting instruction and research in the sciences. These notebooks are either executed locally or in the cloud via services such as [JupyterHub](https://jupyter.org/hub) or [BinderHub](https://binderhub.readthedocs.io/en/latest/). The cloud services are suitable to serve a contained computing environment to either a classroom or the general public. The general focus is typically to integrate programming in the classroom or openly communicate software to the science community. 

Another application of the notebook framework is to use it to serve web applications. Here the focus is less on the code itself, but on using the platform to create interactive content (e.g. Petters, 2021). For example, the notebook can be used as a web-front end to animate the output of computational models that run on the backend. Often these models are written in compiled languages.   Serving such content to students (and the public) can be challenging. Local installs of the entire software can become complex due to platform dependence and dependency management. Docker containers are a convenient way to bundle and serve such webapps. It is possible to serve these containers through either JuyterHub or BinderHub. However, in practice there are several drawbacks.

JupyterHub and BinderHub are designed to run on Kubernetes clusters in the cloud. On premise installation on bare metal is possible but not recommended. JupyterHub and kubernetes clusters have excellent resource management. Yet rapid scaling of the infrastructure at the beginning of a lecture is still slow, as new nodes will have to be spun up and pull the image. The base-cost of the minimum number of manager and worker nodes is expensive. Hosting multiple different apps might require complex hub management. Startup times using this infrastructure can be several minutes before the application is ready. This includes bottlenecks of provisioning nodes, authentication on the server, loading of the notebook, and execution of the notebook. The latter is exacerbated when using Julia as the notebook language, which has additional compile lag.  Overall this is a drain on classroom resources and annoying for users that are used to much faster load times.   

The desired behavior is to provide the user a URL which opens the app. The app should be immediately ready for use. Since the apps are intended to be stateless (i.e. the user gets a fresh instance each time they open a link), authentication barriers are not needed.

# This repository
This repository provides a solution to the above problem. Docker containers are served directly through the Docker swarm. Using Pluto notebooks allows the notebook to be executed when the container is created. A set number of containers is held open at a given time (e.g. 50 instances) which are ready for immediate consumption. The user is  served a deep link that opens the executed notebook. Once open, the application is ready for immediate use. A monitoring script detects used and abandoned container instances and destroys them after some timeout.

In addition to the advantages to the user, this infrastructure is in many ways less complex than the JuyterHub framework. It can readily be deployed on premises using a wide range of hardware, and is as easily scalable to large deployments. A regular workstation with 24 cores/64 GB of memory would be sufficient to serve 30+ students. The swarm can either be local or using cloud servers. Hosting multiple different applications residing in different containers with different architecture is trivial. Administration of this infrastructure is also straightforward.    

## Content
The ```swarm/docker-compose.yml``` contains the configuration of the swarm, including the number of provisioned replicas. Standard Docker commands ```docker swarm init …``` and ```docker stack deploy …``` are used to start the services. 

The ```monitor/monitor.jl``` script logs the state of the swarm and culls used and abandoned containers. 


# Acknowledgements 
Development of this infrastructure was supported by NSF grant AGS-2112978.
