# Elasticsearch and Kibana demo stack
This project runs a demo stack of Elasticsearch and Kibana on Kind-based Kubernetes.
It was originally developed on Mac OSX 11.5.1 and only tested on this OS.
Dependencies are listed below.

## TOC
* [Dependencies](#dependencies)
* [Run](#run)
* [Troubleshooting](#troubleshooting)

## Dependencies
* [Docker (tested with 20.10.5)](https://docs.docker.com/get-docker)
* [Kind v0.11.1](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
* [Kubectl v1.21.X](https://kubernetes.io/docs/tasks/tools/#kubectl)
* [Make](https://www.gnu.org/software/make/)

## Run
1. Make sure you have all [Dependencies](#dependencies) installed and Docker is running.
1. Run: `make`. This will:
  - Create Kind cluster
  - Create a local Docker registry
  - Lint, Build Docker Images and push them to local registry
  - Deploy manifests
  - Bootstrap Elasticsearch cluster
  - Forward ports to Kibana and provide access info

**Other commands:**
*cleanup*
To delete cluster and dependencies run: `make clean`

*help*
Show available commands: `make help`

*port forward*
Forward Kibana ports: `make port-forward`

*build image*
Build docker image: `make docker-build/<dir_with_Dockerfile>`

*push image*
Push docker image: `make docker-push/<dir_with_Dockerfile>`

## Troubleshooting
### Useful commands
**Check Kubernetes resources**
```
kubectl get all -n staging
```

**Check container logs**
```
kubectl get po -n staging
# ...
kubectl logs -n staging -f <pod_name>
```

**Restart containers**
```
kubectl rollout restart deployment -n staging staging-kibana
kubectl rollout restart statefulset -n staging staging-elasticsearch
```

### Known Issues
**Bootstrap is a draft**
Bootstrap logic is just a draft, it does not work in all scenarios and does not care about existing
data.

**No backup**
No backup is implemented. One possible scenario is to use scheduled CronJobs to trigger
Elasticsearch snapshots to some independent backend.

**Healthchecks are naive**
Current healthchecks just see that the ports are listening whithout checking if application is
healthy. This needs improvement in real scenarios.

**Elasticsearch logs complain about disk watermark %**
Faced this issue while running the setup on MacOS, Elasticsearch can see full disk space allocated
to Docker Desktop. Make sure that space allocated to Docker Desktop is not full.

```
{"type": "rolling", "timestamp": "2021-10-11T08:53:32,066Z", "level": "WARN", "component":
"o.e.c.r.a.DiskThresholdMonitor", "cluster.name": "elasticsearch-cluster", "node.name":
"staging-elasticsearch-0", "message": "flood stage disk watermark [95%] exceeded on
[DDU-VjFIShSr7kvn9_l4wA][staging-elasticsearch-0][/usr/share/elasticsearch/data/nodes/0] free:
2.8gb[4.9%], all indices on this node will be marked read-only", "cluster.uuid":
"eXW5ZhpxSFCShrucDIwJ8g", "node.id": "DDU-VjFIShSr7kvn9_l4wA" }
```
