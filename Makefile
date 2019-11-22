NS ?= tomreeb
VERSION ?= latest
IMAGE_NAME ?= concourse-dgossind
CONTAINER_NAME ?= concourse-dgossind
CONTAINER_INSTANCE ?= default

.PHONY: build push shell run start stop rm release

build: Dockerfile
	docker build -t $(NS)/$(IMAGE_NAME)\:$(VERSION) -f Dockerfile .

push:
	docker push $(NS)/$(IMAGE_NAME)\:$(VERSION)

lint:
	docker run -it --rm --privileged -v `pwd`:/root/ projectatomic/dockerfile-lint dockerfile_lint

test:
	dgoss run -d --name $(CONTAINER_NAME)-$(CONTAINER_INSTANCE) $(PORTS) $(VOLUMES) $(NS)/$(IMAGE_NAME)\:$(VERSION)

shell:
	docker run --rm --name $(CONTAINER_NAME)-$(CONTAINER_INSTANCE) -i -t $(PORTS) $(VOLUMES) $(NS)/$(IMAGE_NAME)\:$(VERSION) /bin/ash

run:
	docker run --rm --name $(CONTAINER_NAME)-$(CONTAINER_INSTANCE) $(PORTS) $(VOLUMES) $(NS)/$(IMAGE_NAME)\:$(VERSION)

start:
	docker run -d --name $(CONTAINER_NAME)-$(CONTAINER_INSTANCE) $(PORTS) $(VOLUMES) $(NS)/$(IMAGE_NAME)\:$(VERSION)

stop:
	docker stop $(CONTAINER_NAME)-$(CONTAINER_INSTANCE)
	
rm:
	docker rm $(CONTAINER_NAME)-$(CONTAINER_INSTANCE)

release: lint build test
	make push -e VERSION=$(VERSION)
    
default: build