SHELL = bash

CLUSTER_NAME ?= pd-test
REGISTRY_NAME ?= kind-registry
KIND_CONFIG ?= kind.yaml
KIND_IMAGE ?= kindest/node:v1.21.1@sha256:69860bda5563ac81e3c0057d654b5253219618a22ec3a346306239bba8cfa1a6
CLUSTER_REGISTRY_CONFIG ?= registry-cm.yaml

DOCKER_IMAGES ?= elasticsearch kibana
CERTS ?= elasticsearch

ENV ?= staging

all: 										## (default) Create Kubernetes cluster, local registry, build docker images and deploy
all: cluster docker deploy bootstrap
	$(MAKE) port-forward

clean: 									## Delete Kind Cluster and dependencies
clean: delete-cluster delete-secrets

cluster:  							## Set up Kubernetes cluster with all dependencies
cluster: kind docker-registry cluster-config

delete-cluster:  				## Delete Kubernetes cluster and its dependencies
delete-cluster: delete-kind delete-docker-registry

cluster-config: 				## Configure Kubernetes cluster
	@echo "Configuring cluster..."; \
	{ docker network connect "kind" "$(REGISTRY_NAME)" || true; } &&\
		kubectl --context "kind-$(CLUSTER_NAME)" apply -f "$(CLUSTER_REGISTRY_CONFIG)" &&\
			echo OK

kind: 									## Create Kind Kubernetes cluster
	@kind create cluster --config "$(KIND_CONFIG)" --image "$(KIND_IMAGE)"

delete-kind: undeploy		## Delete Kind Kubernetes cluster
	@kind delete cluster --name "$(CLUSTER_NAME)"

docker-registry:				## Create local Docker Registry
	@echo "Creating Docker Registry..."; \
	running="$$(docker inspect -f '{{.State.Running}}' "$(REGISTRY_NAME)" 2>/dev/null || true)" &&\
		if [ "$$running" != 'true' ]; then \
			docker run \
				-d --restart=always -p "127.0.0.1:5000:5000" --name "$(REGISTRY_NAME)" \
				registry:2 &&\
					echo OK; \
		fi

delete-docker-registry: ## Delete local Docker Registry
	@echo "Deleting Docker Registry..."; \
	docker stop "$(REGISTRY_NAME)" &&\
		docker rm "$(REGISTRY_NAME)" &&\
			echo OK || true

port-forward:						## Forward Kibana port to localhost from Kubernetes service
	@echo -e "\nYou can access Kibana at http://localhost:5601\n\n\
Access credentials for user 'elastic': \n\
$$(cat kustomize/overlays/$(ENV)/secrets/elasticsearch/secret.env | grep ELASTIC_PASSWORD)\n\
\nRunning port-forward now... do not end this process if you need to access Kibana."; \
	kubectl port-forward -n $(ENV) svc/$(ENV)-kibana 5601:5601

docker: docker-registry docker-build docker-push

docker-build: docker-registry $(addprefix docker-build/,$(DOCKER_IMAGES))

docker-build/%: docker-lint/%
	@echo "Building Docker Image $*..."; \
	[[ -d "$*" ]] &&\
		docker build -t "localhost:5000/$*:$$(cat $*/VERSION)" -f "$*/Dockerfile" "$*"

docker-push: docker-build $(addprefix docker-push/,$(DOCKER_IMAGES))

docker-push/%: docker-registry
	@echo "Pushing Docker Image $*..."; \
	docker push "localhost:5000/$*:$$(cat $*/VERSION)"

docker-lint/%:
	@echo "Running Dockerfile linter for $(@F)..."; \
	docker run --rm -i hadolint/hadolint < "$(@F)/Dockerfile" &&\
		echo OK

deploy: kustomize/overlays/$(ENV)/secrets/elasticsearch kustomize/overlays/$(ENV)/secrets/elasticsearch certs
	@kubectl apply -k kustomize/overlays/$(ENV)

undeploy:
	@kubectl delete -k kustomize/overlays/$(ENV) || true

# This is naive implementation of bootstrap logic just for demo purposes
# It is destructive and does not care about existing data.
# kubectl delete cm -n $(ENV) -l "app.kubernetes.io/name=elasticsearch-env" 
bootstrap:							## Bootstrap Elasticsearch cluster
	@echo "Bootstrapping cluster..."; \
		BOOTSTRAP_CLUSTER=true \
			kubectl apply -k kustomize/overlays/$(ENV) &&\
				kubectl rollout status -n $(ENV) sts/$(ENV)-elasticsearch &&\
					kubectl exec -n $(ENV) -it $(ENV)-elasticsearch-0 -- \
						timeout 300 bash -c '. /var/run/secrets/elasticsearch/secret.env && \
							while :;do \
								echo "Waiting for healthy state..."; \
								curl -s -u "elastic:$$ELASTIC_PASSWORD" \
									--cacert /etc/elasticsearch/certs/ca.crt -I -XGET \
									https://$(ENV)-elasticsearch.staging.svc.cluster.local:9200/_cluster/health |\
										grep HTTP |\
										grep 200 &&\
											break; \
								sleep 5; \
							done' &&\
								$(MAKE) deploy &&\
									kubectl rollout status -n $(ENV) sts/$(ENV)-elasticsearch &&\
										echo OK

kustomize/overlays/$(ENV)/secrets/certs/cacert:
	@echo "Generating CA Cert in $@..."; \
	mkdir -p "$@" &&\
		openssl genrsa -out "$@/ca.key" 2048 &&\
			openssl req -x509 -new -nodes -key "$@/ca.key" -subj "/CN=$(ENV).svc.cluster.local" -days 365 -out "$@/ca.crt" &&\
				echo OK

certs: $(addprefix kustomize/overlays/$(ENV)/secrets/certs/,$(CERTS))

kustomize/overlays/$(ENV)/secrets/certs/%: kustomize/overlays/$(ENV)/secrets/certs/cacert
	@echo "Generating $(@F) Cert in $@..."; \
	NAME="$@/tls"; \
		mkdir -p "$@" &&\
			ENV="$(ENV)" envsubst < "kustomize/overlays/$(ENV)/config/$(@F).csr.conf.tpl" > "$${NAME}.csr.conf" &&\
				openssl genrsa -out "$${NAME}.key" 2048 &&\
				openssl req -new -key "$${NAME}.key" -out "$${NAME}.csr" -config "$${NAME}.csr.conf" &&\
				openssl x509 -req -in "$${NAME}.csr" -CA "kustomize/overlays/$(ENV)/secrets/certs/cacert/ca.crt" -CAkey "kustomize/overlays/$(ENV)/secrets/certs/cacert/ca.key" \
					-CAcreateserial -out "$${NAME}.crt" -days 365 \
					-extensions v3_ext -extfile "$${NAME}.csr.conf" &&\
					openssl req  -noout -text -in "$${NAME}.csr" &&\
						openssl x509  -noout -text -in "$${NAME}.crt" &&\
							echo OK

delete-secrets:					## Cleanup temporary files with secrets
	@echo "Removing secrets..."; \
	rm -rfv kustomize/overlays/$(ENV)/secrets &&\
		echo OK

kustomize/overlays/$(ENV)/secrets/elasticsearch:
	@mkdir -p "$@"; \
	rnd() { LC_ALL=C tr -dc 'A-Za-z0-9!#&()*+,-./:;?@^_~' </dev/urandom | head -c 20; }; \
	printf "%s=%s\n" KEYSTORE_PASSWORD $$(rnd) > "$@/secret.env"; \
	printf "%s=%s\n" ELASTIC_PASSWORD $$(rnd) >> "$@/secret.env"; \
	printf "%s=%s\n" KIBANA_PASSWORD $$(rnd) > "$@/kibana.env"; \
	printf "%s=%s\n" KIBANA_USER kibana_file_user >> "$@/kibana.env"


help: 									## Show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[$$()% 0-9a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
