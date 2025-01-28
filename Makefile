include base.mk

check-dependencies:
	@$(call check-dependency,go)

test: check-dependencies
	go test -v ./...

build: check-dependencies
	go generate ./...
	go build .

build-docker:
	@docker build -t kongair/flights:latest .

run: check-dependencies build
	./flights ${KONG_AIR_FLIGHTS_PORT}

docker: build-docker
	@docker run -d --name kongair-flights -p ${KONG_AIR_FLIGHTS_PORT}:${KONG_AIR_FLIGHTS_PORT} kongair/flights:latest

kill-docker:
	-@docker stop kong-air-flights-svc
	-@docker rm kong-air-flights-svc
	@if [ $$? -ne 0 ]; then $(call echo_fail,Failed to kill the docker containers); exit 1; else $(call echo_pass,Killed the docker container); fi
