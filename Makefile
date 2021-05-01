SHELL := /bin/bash
TARGET := awslambdaproxy
VERSION := $(shell cat VERSION)
OS := linux
ARCH := amd64
PACKAGE := github.com/dan-v/$(TARGET)

.PHONY: \
	clean \
	tools \
	test \
	coverage \
	vet \
	lint \
	fmt \
	build \
	lambda-build \
	server-build-linux \
	server-build-osx \
	doc \
	release \
	docker-build \
	docker-release \

all: tools fmt build lint vet test release

print-%:
	@echo $* = $($*)

clean:
	rm -Rf artifacts
	rm -vf $(CURDIR)/coverage.*

tools:
	go get golang.org/x/lint/golint
	go get github.com/axw/gocov/gocov
	go get github.com/matm/gocov-html

test:
	go test -v ./...

coverage:
	gocov test ./... > $(CURDIR)/coverage.out 2>/dev/null
	gocov report $(CURDIR)/coverage.out
	if test -z "$$CI"; then \
	  gocov-html $(CURDIR)/coverage.out > $(CURDIR)/coverage.html; \
	  if which open &>/dev/null; then \
	    open $(CURDIR)/coverage.html; \
	  fi; \
	fi

vet:
	go vet -v ./...

lint:
	golint $(go list ./... | grep -v /vendor/)

fmt:
	go fmt ./...

lambda-build:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o artifacts/lambda/main ./pkg/lambda
	zip -jr artifacts/lambda artifacts/lambda
	go-bindata -nocompress -pkg server -o pkg/server/bindata.go artifacts/lambda.zip
	cp artifacts/lambda.zip artifacts/lambda-$(VERSION).zip

server-build-linux:
	CGO_ENABLED=0 GOOS=$(OS) GOARCH=$(ARCH) go build -ldflags \
	    "-X $(PACKAGE)/cmd/awslambdaproxy.version=$(VERSION)" \
	    -v -o $(CURDIR)/artifacts/server/$(OS)/$(TARGET) ./cmd/main.go

server-build-osx:
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -ldflags \
	    "-X $(PACKAGE)/cmd/awslambdaproxy.version=$(VERSION)" \
	    -v -o $(CURDIR)/artifacts/server/darwin/$(TARGET) ./cmd/main.go

build: lambda-build server-build-linux

build-osx: lambda-build server-build-osx

doc:
	godoc -http=:8080 -index

release:
	mkdir -p ./artifacts
	zip -jr ./artifacts/$(TARGET)-$(OS)-$(VERSION).zip ./artifacts/server/$(OS)/$(TARGET)

docker:
	docker build . -t timbru31/awslambdaproxy:$(VERSION) -t timbru31/awslambdaproxy:latest

docker-release:
	docker push timbru31/awslambdaproxy:$(VERSION)
	docker push timbru31/awslambdaproxy:latest
