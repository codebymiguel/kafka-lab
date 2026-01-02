# =========================
# Kafka Lab - Makefile
# =========================
# Uso rápido:
#   make up
#   make topics-create
#   make consume-bli        (ouve bli.to.tro)
#   make consume-tro        (ouve tro.to.bli)
#   make send-bli MSG="ola do BLI"
#   make send-tro MSG="ola do TRO"
#   make run-bli
#   make run-tro
#   make down

SHELL := /bin/bash
TMUX_SESSION := kafka-dev

# Docker Compose (podes trocar para "docker-compose" se precisares)
DC := docker compose

# Nome do container do Kafka (como definiste no docker-compose.yml)
KAFKA_CONTAINER := kafka

# Scripts do Kafka dentro do container (apache/kafka)
KAFKA_BIN := /opt/kafka/bin
BOOTSTRAP := localhost:9092

TOPIC_BLI := bli.to.tro
TOPIC_TRO := tro.to.bli

# Mensagem default (podes sobrescrever: make send-bli MSG="...")
MSG ?= hello

.PHONY: help up down restart ps logs ui \
        topics-create topics-list topics-delete \
        consume-bli consume-tro \
        send-bli send-tro \
        run-bli run-tro

help:
	@echo ""
	@echo "Kafka Lab - targets:"
	@echo "  make up                  # sobe Kafka + UI"
	@echo "  make down                # desce tudo e remove volumes"
	@echo "  make restart             # reinicia stack"
	@echo "  make ps                  # lista containers"
	@echo "  make logs                # logs do Kafka (follow)"
	@echo "  make ui                  # mostra URL da UI"
	@echo ""
	@echo "  make topics-create       # cria topics bli.to.tro e tro.to.bli"
	@echo "  make topics-list         # lista topics"
	@echo ""
	@echo "  make consume-bli         # consumer no topic bli.to.tro"
	@echo "  make consume-tro         # consumer no topic tro.to.bli"
	@echo ""
	@echo "  make send-bli MSG='...'  # envia MSG para bli.to.tro"
	@echo "  make send-tro MSG='...'  # envia MSG para tro.to.bli"
	@echo ""
	@echo "  make run-bli             # corre app BLI (ts-node)"
	@echo "  make run-tro             # corre app TRO (ts-node)"
	@echo ""

# -------------------------
# Docker / Stack
# -------------------------
up:
	$(DC) up -d

down:
	$(DC) down -v

restart: down up

ps:
	$(DC) ps

logs:
	$(DC) logs -f kafka

ui:
	@echo "Kafka UI: http://localhost:8080"

# -------------------------
# Kafka topics
# -------------------------
topics-create:
	@echo "Creating topics: $(TOPIC_BLI), $(TOPIC_TRO)"
	@docker exec -it $(KAFKA_CONTAINER) bash -lc '\
		$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --create --topic $(TOPIC_BLI) --partitions 1 --replication-factor 1 || true; \
		$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --create --topic $(TOPIC_TRO) --partitions 1 --replication-factor 1 || true; \
	'
	@$(MAKE) topics-list

topics-list:
	@docker exec -it $(KAFKA_CONTAINER) bash -lc '\
		$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --list \
	'

# (Opcional) apagar topics (cuidado: remove tudo)
topics-delete:
	@echo "Deleting topics: $(TOPIC_BLI), $(TOPIC_TRO)"
	@docker exec -it $(KAFKA_CONTAINER) bash -lc '\
		$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --delete --topic $(TOPIC_BLI) || true; \
		$(KAFKA_BIN)/kafka-topics.sh --bootstrap-server $(BOOTSTRAP) --delete --topic $(TOPIC_TRO) || true; \
	'
	@$(MAKE) topics-list

# -------------------------
# Consumers (ficam a correr)
# -------------------------
consume-bli:
	@echo "Consuming from $(TOPIC_BLI) (CTRL+C para sair)"
	@docker exec -it $(KAFKA_CONTAINER) bash -lc '\
		$(KAFKA_BIN)/kafka-console-consumer.sh --bootstrap-server $(BOOTSTRAP) --topic $(TOPIC_BLI) --from-beginning \
	'

consume-tro:
	@echo "Consuming from $(TOPIC_TRO) (CTRL+C para sair)"
	@docker exec -it $(KAFKA_CONTAINER) bash -lc '\
		$(KAFKA_BIN)/kafka-console-consumer.sh --bootstrap-server $(BOOTSTRAP) --topic $(TOPIC_TRO) --from-beginning \
	'

# -------------------------
# Producers (envio 1 msg)
# -------------------------
send-bli:
	@echo "Sending to $(TOPIC_BLI): $(MSG)"
	@docker exec -it $(KAFKA_CONTAINER) bash -lc '\
		echo "$(MSG)" | $(KAFKA_BIN)/kafka-console-producer.sh --bootstrap-server $(BOOTSTRAP) --topic $(TOPIC_BLI) \
	'

send-tro:
	@echo "Sending to $(TOPIC_TRO): $(MSG)"
	@docker exec -it $(KAFKA_CONTAINER) bash -lc '\
		echo "$(MSG)" | $(KAFKA_BIN)/kafka-console-producer.sh --bootstrap-server $(BOOTSTRAP) --topic $(TOPIC_TRO) \
	'

# -------------------------
# Apps
# -------------------------
run-bli:
	@echo "Running BLI (CTRL+C para sair)"
	@cd bli && npx ts-node src/index.ts

run-tro:
	@echo "Running TRO (CTRL+C para sair)"
	@cd tro && npx ts-node src/index.ts

# -------------------------
# Dev mode (BLI + TRO)
# -------------------------
dev:
	@echo "Starting dev session (tmux: $(TMUX_SESSION))"
	@tmux has-session -t $(TMUX_SESSION) 2>/dev/null && \
		(echo "tmux session already running. Attach with: tmux attach -t $(TMUX_SESSION)" && exit 0) || true
	@tmux new-session -d -s $(TMUX_SESSION) "cd bli && npx ts-node src/index.ts"
	@tmux split-window -h "cd tro && npx ts-node src/index.ts"
	@tmux select-layout even-horizontal
	@tmux attach -t $(TMUX_SESSION)
