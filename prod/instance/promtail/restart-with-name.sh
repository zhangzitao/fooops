#!/bin/bash

# ------------------
# why:
#   不想把所有的container的log都收集，只收集当前实例中的某几个container
# how:
#   container的日志位置可以根据名字列出，生成对应的docker-compose文件和promatil的配置文件
#   之后compose down,最后启动
# usage:
#   # 容器名称支持正则，这样就支持多副本的服务
#   sh restart-with-name.sh -n ^pg12_pg_.+$,redis5_redis_1 -a lokiIpAddress 
# tip:
#   promtail-config.yml里的__path__支持多值: var/log/**/{loki,promtail,grafana}.log
# ------------------

function join_by { local d=${1-} f=${2-}; if shift 2; then printf %s "$f" "${@/#/$d}"; fi; }

cat <<EOF > ./docker-compose.yml
version: "3"
services:

  promtail:
    image: grafana/promtail:2.3.0
    command: -config.file=/etc/promtail/config.yml
    deploy:
      replicas: 1
      restart_policy:
        condition: on-failure
        delay: 10s
        max_attempts: 3
    volumes:
      - "./promtail-config.yml:/etc/promtail/config.yml"
EOF

while getopts "n:a:" flag; do
    case "${flag}" in
        n ) 
            IFS=','
            name_list+=("$OPTARG") ;;
        a )
            loki_addr=$OPTARG ;;
        * ) 
            echo "not support $OPTARG"
            exit 1
    esac
done
for name in $name_list; do
    OLDIFS="$IFS"
    IFS=$'\n'
    for shortid in $(docker ps -qf "name=$name" ); do
        echo "container id: $shortid name: $name"
        for dir in $(docker inspect --format="{{.Id}}" $shortid); do
            echo "      - \"/var/lib/docker/containers/$dir:/var/lib/docker/containers/$dir\"" >> ./docker-compose.yml
        done
    done
    IFS="$OLDIFS"
done

echo "loki address: $loki_addr"

cat <<EOF > ./promtail-config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0
  # log_level: "debug"

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://$loki_addr:3100/loki/api/v1/push
    batchsize: 102400 # <int> | default = 102400]
    batchwait: 5s # <duration> | default = 1s

scrape_configs:
  - job_name: application
    pipeline_stages:
    - json:
        expressions:
          log: log
          stream: stream
          timestamp: time
    - json:
        expressions:
          level:
          app:
        source: log
    - labels:
        level:
        app:
    static_configs:
EOF

for name in $name_list; do
    OLDIFS="$IFS"
    IFS=$'\n'
    for shortid in $(docker ps -qf "name=$name" ); do
        echo "      - targets:
        - localhost"  >> ./promtail-config.yml
        echo "        labels:" >> ./promtail-config.yml
        echo "          job: \"$name\"" >> ./promtail-config.yml
        ids=()
        for dir in $(docker inspect --format="{{.Id}}" $shortid); do
            ids+=($dir)
        done
        idsjoin=$(IFS=, ; echo "${ids[*]}")
        echo "          __path__: /var/lib/docker/containers/{$idsjoin}/*.log" >> ./promtail-config.yml
        IFS=$'\n'
    done
    IFS="$OLDIFS"
done

docker-compose down --remove-orphans
docker-compose up --force-recreate -d