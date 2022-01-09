WORK_FOLDER=$(PWD)

#开ui的command是agent -server -ui -bootstrap -client=0.0.0.0
consul-create:
	@sudo docker service create \
	--name consul \
	--replicas 1 \
	--network host \
	--mount type=bind,source=$(WORK_FOLDER)/consul/volume/data,destination=/consul/data \
	--publish mode=host,target=8500,published=8500 \
	-e 'CONSUL_BIND_INTERFACE=eth0' \
	-e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true}' \
	--limit-cpu "0.05" \
	--limit-memory "200MB" \
	consul:1.10 agent -server -bootstrap -client=0.0.0.0

consul-shutdown:
	sudo docker service rm consul