up:
	@cd fooops_server ;\
	docker-compose -p fooops-dev up --force-recreate

down:
	@cd fooops_server ;\
	docker-compose -p fooops-dev down --remove-orphans

up-promtail:
	@cd instance ;\
	docker-compose -p fooops-dev up --force-recreate