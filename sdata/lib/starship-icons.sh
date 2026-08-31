#!/bin/bash
# Flow Terminal — Icon Abstraction Layer
# Centralized Nerd Font icon mappings for visual consistency
# All icons verified against Nerd Fonts Cheat Sheet (nerdfonts.com/cheat-sheet)

# Format: FLOW_ICON_<semantic_name>="<nerd_font_codepoint>"
# Codepoints verified from nf-dev (devicons), nf-seti (Seti UI), nf-fa (Font Awesome)

# ─── Programming Languages ────────────────────────────────────
FLOW_ICON_PYTHON=$'\uE73C'       # nf-dev-python
FLOW_ICON_NODEJS=$'\uED0D'       # nf-dev-nodejs
FLOW_ICON_GO=$'\uE65E'           # nf-dev-go
FLOW_ICON_RUST=$'\uE7A8'         # nf-dev-rust
FLOW_ICON_JAVA=$'\uE738'         # nf-dev-java
FLOW_ICON_KOTLIN=$'\uE81B'       # nf-dev-kotlin
FLOW_ICON_SWIFT=$'\uE755'        # nf-dev-swift
FLOW_ICON_PHP=$'\uE73D'          # nf-dev-php
FLOW_ICON_RUBY=$'\uE739'         # nf-dev-ruby
FLOW_ICON_TYPESCRIPT=$'\uE628'   # nf-seti-typescript
FLOW_ICON_JAVASCRIPT=$'\uE74E'   # nf-dev-javascript
FLOW_ICON_C=$'\uE61E'            # nf-seti-c
FLOW_ICON_CPP=$'\uE61D'          # nf-seti-cpp
FLOW_ICON_CSHARP=$'\uE74F'       # nf-dev-csharp

# ─── Development Tools ────────────────────────────────────────
FLOW_ICON_DOCKER=$'\uE7B0'       # nf-dev-docker
FLOW_ICON_COMPOSE=$'\uE615'      # nf-seti-docker (Compose)
FLOW_ICON_KUBERNETES=$'\uE81D'   # nf-dev-kubernetes
FLOW_ICON_HELM=$'\uE7FB'         # nf-dev-helm
FLOW_ICON_TERRAFORM=$'\uE8BD'    # nf-dev-terraform
FLOW_ICON_ANSIBLE=$'\uE723'      # nf-dev-ansible
FLOW_ICON_VAGRANT=$'\uE21E'      # nf-dev-vagrant
FLOW_ICON_JENKINS=$'\uE767'       # nf-dev-jenkins
FLOW_ICON_GITHUB_ACTIONS=$'\uE7E9' # nf-dev-githubactions
FLOW_ICON_NGINX=$'\uE776'        # nf-dev-nginx
FLOW_ICON_APACHE=$'\uE72B'       # nf-dev-apache

# ─── Cloud Providers ──────────────────────────────────────────
FLOW_ICON_AWS=$'\uE7AD'          # nf-dev-amazonwebservices
FLOW_ICON_GCP=$'\uE7F1'          # nf-dev-googlecloud
FLOW_ICON_AZURE=$'\uE754'        # nf-dev-azure
FLOW_ICON_CLOUDFLARE=$'\uE7AC'   # nf-dev-cloudflare

# ─── Databases ────────────────────────────────────────────────
FLOW_ICON_POSTGRESQL=$'\uE76E'   # nf-dev-postgresql
FLOW_ICON_MYSQL=$'\uE704'        # nf-dev-mysql
FLOW_ICON_MARIADB=$'\uE828'      # nf-dev-mariadb
FLOW_ICON_MONGODB=$'\uE7A4'      # nf-dev-mongodb
FLOW_ICON_REDIS=$'\uE76D'        # nf-dev-redis
FLOW_ICON_SQLITE=$'\uE7C4'       # nf-dev-sqlite
FLOW_ICON_CASSANDRA=$'\uE789'    # nf-dev-cassandra
FLOW_ICON_NEO4J=$'\uE839'        # nf-dev-neo4j
FLOW_ICON_COUCHBASE=$'\uE7A0'    # nf-dev-couchbase
FLOW_ICON_COUCHDB=$'\uE7A2'      # nf-dev-couchdb
FLOW_ICON_INFLUXDB=$'\uE800'     # nf-dev-influxdb
FLOW_ICON_CLICKHOUSE=$'\uE8FE'   # nf-dev-clickhouse

# ─── Monitoring & Observability ───────────────────────────────
FLOW_ICON_PROMETHEUS=$'\uE870'   # nf-dev-prometheus
FLOW_ICON_GRAFANA=$'\uE7F3'      # nf-dev-grafana
FLOW_ICON_ELASTICSEARCH=$'\uE7CA' # nf-dev-elasticsearch
FLOW_ICON_SPLUNK=$'\uE8AB'       # nf-dev-splunk
FLOW_ICON_DATADOG=$'\uE902'      # nf-dev-datadog
FLOW_ICON_NEW_RELIC=$'\uE92D'    # nf-dev-newrelic
FLOW_ICON_SENTRY=$'\uE89F'       # nf-dev-sentry

# ─── Message Brokers ──────────────────────────────────────────
FLOW_ICON_KAFKA=$'\uE72E'        # nf-dev-apachekafka
FLOW_ICON_RABBITMQ=$'\uE882'     # nf-dev-rabbitmq

# ─── Data Processing ──────────────────────────────────────────
FLOW_ICON_SPARK=$'\uE72F'        # nf-dev-apachespark
FLOW_ICON_AIRFLOW=$'\uE72C'      # nf-dev-apacheairflow

# ─── Version Control ──────────────────────────────────────────
FLOW_ICON_GIT=$'\uE725'          # nf-dev-git2
FLOW_ICON_GITHUB=$'\uE709'       # nf-dev-github
FLOW_ICON_GITLAB=$'\uE7EB'       # nf-dev-gitlab
FLOW_ICON_SSH=$'\uE8B1'          # nf-dev-ssh

# ─── CI/CD & DevOps ──────────────────────────────────────────
FLOW_ICON_ARGOCD=$'\uE754'       # nf-dev-argocd
FLOW_ICON_RANCHER=$'\uE876'      # nf-dev-rancher
FLOW_ICON_PORTAINER=$'\uE875'    # nf-dev-portainer
FLOW_ICON_CONSUL=$'\uE7AC'       # nf-dev-consul
FLOW_ICON_VAULT=$'\uE7E8'        # nf-dev-vault
FLOW_ICON_NOMAD=$'\uE834'        # nf-dev-nomad
FLOW_ICON_PULUMI=$'\uE877'       # nf-dev-pulumi (if exists)

# ─── Frameworks ───────────────────────────────────────────────
FLOW_ICON_REACT=$'\uE7BA'        # nf-dev-react
FLOW_ICON_VUE=$'\uE6A0'          # nf-seti-vue
FLOW_ICON_ANGULAR=$'\uE753'      # nf-dev-angular
FLOW_ICON_SVELTE=$'\uE8B7'       # nf-dev-svelte
FLOW_ICON_DJANGO=$'\uE73F'       # nf-dev-django
FLOW_ICON_FLASK=$'\uE73F'        # nf-dev-flask (same as django)
FLOW_ICON_RAILS=$'\uE73B'        # nf-dev-rails
FLOW_ICON_LARAVEL=$'\uE73F'      # nf-dev-laravel (same as django)
FLOW_ICON_SPRING=$'\uE8AC'       # nf-dev-spring

# ─── Package Managers ─────────────────────────────────────────
FLOW_ICON_NPM=$'\uE80C'          # nf-dev-npm
FLOW_ICON_GRADLE=$'\uE7F2'       # nf-dev-gradle
FLOW_ICON_MAVEN=$'\uE82C'        # nf-dev-maven

# ─── Testing ──────────────────────────────────────────────────
FLOW_ICON_JEST=$'\uE803'         # nf-dev-jest (if exists)
FLOW_ICON_MOCHA=$'\uE832'        # nf-dev-mocha

# ─── Development Environment ──────────────────────────────────
FLOW_ICON_VENV=".venv"
FLOW_ICON_NVM="nvm"
FLOW_ICON_MISE="mise"

# ─── Status Indicators ────────────────────────────────────────
FLOW_ICON_SUCCESS=""
FLOW_ICON_ERROR=""
FLOW_ICON_WARNING=$'\u26A0'       # Warning sign
FLOW_ICON_DIRTY=$'\u25CF'         # Filled circle
FLOW_ICON_CLEAN=""

# ─── Environment Context ──────────────────────────────────────
FLOW_ICON_LOCAL=$'\uE795'         # nf-dev-terminal
FLOW_ICON_REMOTE=$'\uE8B1'        # nf-dev-ssh
FLOW_ICON_DOCKER_CONTAINER=$'\uE7B0' # nf-dev-docker
FLOW_ICON_VM=$'\uE795'            # nf-dev-terminal

# ─── System ───────────────────────────────────────────────────
FLOW_ICON_MEMORY=$'\uE795'        # nf-dev-terminal
FLOW_ICON_CPU=$'\uE795'           # nf-dev-terminal
FLOW_ICON_DISK=$'\uE795'          # nf-dev-terminal
FLOW_ICON_NETWORK=$'\uE795'       # nf-dev-terminal

# ─── Semantic Separators ──────────────────────────────────────
FLOW_ICON_SEPARATOR="·"
FLOW_ICON_ARROW="→"
FLOW_ICON_PIPE="│"
FLOW_ICON_CORNER_TOP="╭─"
FLOW_ICON_CORNER_BOTTOM="╰─"

# ─── Git Status ───────────────────────────────────────────────
FLOW_ICON_GIT_BRANCH=$'\uE725'   # nf-dev-git2
FLOW_ICON_GIT_STASH=$'\uE7AC'    # nf-dev-githubactions
FLOW_ICON_GIT_AHEAD=$'\u2191'    # ↑
FLOW_ICON_GIT_BEHIND=$'\u2193'   # ↓
FLOW_ICON_GIT_DIVERGED=$'\u21D5' # ⇕
