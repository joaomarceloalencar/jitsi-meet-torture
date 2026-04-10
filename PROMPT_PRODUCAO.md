# Prompt para Configuração de Jitsi Meet em Produção

---

## Contexto

Você é um especialista em Kubernetes e Jitsi Meet. Sua tarefa é replicar em produção uma instalação validada localmente de Jitsi Meet com autenticação JWT e auto-scaling horizontal de JVBs (Videobridges). No diretório atual, existem vários manifestos de componentes já instalados no subdiretório conf. Você também pode acessar a máquina remota controladora (insightcluster12) via ssh sem senha, usando o comando `ssh insightcluster12`. O cluster Kubernetes de produção já tem um nginx-ingress-controller instalado e configurado, e o TLS está configurado com certificados Let's Encrypt. O objetivo é configurar o ambiente de produção para que seja acessível externamente via HTTPS, com autenticação JWT funcionando corretamente, e com auto-scaling dos JVBs baseado em métricas de CPU e memória.

## Resumo da Arquitetura Validada

**Ambiente local validado:**
- Jitsi Meet com autenticação JWT (HS256)
- WebSocket funcionando corretamente (porta 30443)
- HPA configurado para auto-scaling de JVBs (2-10 réplicas)
- nginx-ingress-controller existente no cluster
- TLS com certificados locais (CA própria)

**Componentes:**
- `jitsi-web`: Frontend (nginx + React), 1 replica
- `prosody`: XMPP server com JWT auth, 1 replica
- `jicofo`: Conference focus controller, 1 replica
- `jvb`: Videobridge (media), 2-10 replicas com HPA

**Configurações críticas validadas:**
- PUBLIC_URL deve incluir a porta: `https://domain:30443`
- XMPP_SERVER deve usar FQDN completo
- WebSocket requer hostAliases e resolver no nginx.conf
- Health probes do jicofo usam TCP socket (não HTTP)
- HTTP redirect desativado no jitsi-web

---

## Objetivo

Configurar Jitsi Meet em cluster Kubernetes de produção com:

1. **Autenticação JWT** para controle de acesso às salas
2. **Auto-scaling horizontal** dos JVBs baseado em CPU/memory
3. **TLS/HTTPS** com certificados válidos (Let's Encrypt ou certificados corporativos)
4. **High Availability** para todos os componentes críticos
5. **Monitoramento** e logging adequados

---

## Informações do Ambiente de Produção

**Substituir os valores abaixo conforme seu ambiente:**

```yaml
# Domínio e URL
JITSI_DOMAIN: "jitsi.ufcquixada.ia.br"
JITSI_PORT: "443"  # ou 30443 se usar nodePort
NAMESPACE: "jitsi"

# Cluster Kubernetes
KUBERNETES_VERSION: "1.x.x"
CLOUD_PROVIDER: "AWS/GCP/Azure/on-premise"
INGRESS_CONTROLLER: "nginx-ingress-controller (existente ou criar)"

# Certificados TLS
TLS_TYPE: "cert-manager/Let's Encrypt/corporativo"
TLS_ISSUER: "cluster-issuer name (se usar cert-manager)"

# Recursos (ajustar conforme capacidade do cluster)
JVB_CPU_REQUEST: "500m"
JVB_MEMORY_REQUEST: "512Mi"
JVB_CPU_LIMIT: "2000m"
JVB_MEMORY_LIMIT: "2Gi"

# Auto-scaling
JVB_MIN_REPLICAS: 2
JVB_MAX_REPLICAS: 10
JVB_TARGET_CPU: "70%"
JVB_TARGET_MEMORY: "80%"
JVB_SCALE_DOWN_STABILIZATION: "300s"

# JWT Configuration
JWT_ISSUER: "jitsi-meet"
JWT_AUDIENCE: "jitsi-meet"
JWT_TOKEN_LIFETIME: "86400"  # 24 horas em segundos

# Storage (se necessário para persistência)
PROSODY_STORAGE_TYPE: "persistent-volume/configmap"
```

---

## Requisitos Técnicos

### 1. Manifestos Kubernetes

Estou em dúvida sobre duas opções de configuração e preciso de sua ajuda para decidir a melhor abordagem. Análise a duas e me forneça recomendações.

#### 1.1 Gerar manifestos YAML separados por componente:

Gerar manifests YAML organizados por ordem de aplicação:

```
k8s/
├── 00-namespace.yaml
├── 01-network-policies.yaml      # Opcional, mas recomendado
├── 02-configmaps.yaml
├── 03-secrets.yaml               # TLS + JWT secrets
├── 04-deployments.yaml           # Todos os componentes
├── 05-services.yaml
├── 06-hpa.yaml                   # Auto-scaling dos JVBs
└── 07-ingress.yaml               # HTTPS routing
```

#### 1.2 Usar Helm Charts para cada componente.

A seguinte referência (Kubernetes Jitsi Scaling Guide for DevOps Engineers
)[(https://jitsi.support/scaling/kubernetes-jitsi-scaling-guide/) sugere usar Helm Charts para facilitar a configuração e manutenção. Isso pode ser especialmente útil para lidar com as complexidades de configuração do Jitsi Meet, como autenticação JWT e auto-scaling. No entanto, isso pode adicionar uma camada de complexidade para quem não está familiarizado com Helm. Por exemplo, não sei quais opções possíveis seriam para o values.yaml do Helm Chart, e como configurar corretamente os templates para atender aos requisitos específicos de produção.


### 2. Configurações Específicas

**nginx-ingress:**
- Usar ingress-controller.
- Se criar, usar Deployment com 2+ réplicas
- Configurar Service tipo LoadBalancer
- Portas: 80 e 443 

O objetivo é que https://jitsi.ufcquixada.ia.br seja acessível externamente, com TLS válido e redirecionamento automático de HTTP para HTTPS.

**Jitsi Web:**
- Adicionar hostAliases para resolução interna
- Configurar nginx.conf com resolver para WebSocket
- Desativar HTTP redirect se necessário

**Prosody:**
- Habilitar autenticação JWT
- Configurar modules: jitsi-videobridge, c2s_require_encryption
- Persistir registros de usuários se necessário

**Jicofo:**
- Health probes usando TCP socket (não HTTP)
- Configurar bridge selection algorithm
- Ajustar timeouts conforme escala

**JVB:**
- HPA configurado com CPU e memory metrics
- Pod disruption budget para disponibilidade
- Affinity/anti-affinity rules para distribuição
- Resources requests/limits adequados

### 3. Segurança

- Secrets Kubernetes para JWT secret e certificados TLS
- Network policies para isolamento de namespace
- Pod security standards/contexts
- RBAC apropriado (se necessário)

### 4. Monitoramento

- Health checks (liveness/readiness probes)
- Metrics endpoints expostos
- Logging estruturado
- Integração com Prometheus/Grafana (já existentes no cluster)

---

## Entregáveis Esperados

### 1. Manifestos Kubernetes Completos ou values.yaml para Helm Charts

Todos os YAMLs prontos para aplicar com `kubectl apply -f k8s/` ou `helm install jitsi ./jitsi-chart/` com as configurações adequadas para produção.

### 2. Scripts de Deployment

```bash
#!/bin/bash
# setup.sh
# - Valida pré-requisitos
# - Gera JWT secret
# - Aplica manifests em ordem
# - Verifica status dos pods
```

### 3. Scripts de Gerenciamento

```bash
# generate-jwt-token.sh <user> <moderator|user>
# - Gera token JWT para teste

# cleanup.sh
# - Remove todos os recursos do namespace
```

### 4. Documentação

- README com instruções de deployment
- Procedimento de geração de certificados TLS
- Como gerar tokens JWT
- Comandos de verificação e troubleshooting
- Configuração de DNS necessária

---

## Pré-requisitos do Cluster

O cluster de produção deve ter:

- [ ] Kubernetes 1.20+
- [ ] Metrics-server instalado e funcionando (para HPA)
- [ ] StorageClass (se necessário persistência)
- [ ] DNS configurado para o domínio Jitsi
- [ ] Cert-manager instalado (se usar Let's Encrypt)
- [ ] Ingress controller (nginx ou outro)
- [ ] Recursos disponíveis: mínimo 4 CPU, 8GB RAM para começar

---

## Validação Pós-Deployment

Após deployment, validar:

```bash
# Verificar todos os pods
kubectl get pods -n jitsi

# Verificar HPA
kubectl get hpa -n jitsi

# Verificar serviços
kubectl get svc -n jitsi

# Testar acesso
curl -k https://jitsi.ufcquixada.ia.br/ 

# Gerar token JWT
./scripts/generate-jwt-token.sh testuser moderator

```

---

## Considerações Especiais

### TLS Certificados

** Let's Encrypt (cert-manager)**
- Já tem infraestrutura para cert-manager configurada
- Configurar annotation no Ingress
- Certificados renovados automaticamente

### JWT Secret

- Gerar secret forte (256 bits mínimo)
- Armazenar em Kubernetes Secret
- **NUNCA** commit no git
- Rotacionar periodicamente

### Auto-scaling

- Metrics-server deve estar funcionando
- HPA requer CPU e memory requests definidos
- Scale-down tem estabilização de 5 minutos
- Testar com carga real para validar thresholds

### High Availability

- Prosody: considerar statefulset com persistência
- Jicofo: 2 réplicas com leader election
- JVB: 2+ réplicas com HPA
- PostgreSQL (se usado): external RDS ou statefulset

---

## Troubleshooting Comum

**HPA não escala:**
```bash
kubectl get --raw /apis/metrics.k8s.io/v1beta1
kubectl top pods -n jitsi
kubectl describe hpa jvb-hpa -n jitsi
```

**WebSocket falha (502):**
- Verificar hostAliases no jitsi-web
- Verificar resolver no nginx.conf
- Verificar PUBLIC_URL com porta correta

**Jicofo health check falha:**
- Usar TCP probe, não HTTP
- Verificar logs do jicofo
- Verificar conexão com prosody

**Certificado TLS invalido:**
- Verificar secret TLS
- Verificar annotation no Ingress
- Verificar cert-manager status (se aplicável)

---

## Formato de Resposta Esperado

Forneça:

1. **Todos os manifests YAML** completos e comentados
2. **Scripts bash** para deployment e gerenciamento
3. **README.md** com instruções passo-a-passo
4. **Checklist** de pré-requisitos e validação
5. **Explicações** sobre decisões de arquitetura importantes

Se houver decisões a serem tomadas (ex: tipo de certificado, storage), apresente as opções e recomendações.

---

## Referências

- [Jitsi Meet Kubernetes Documentation](https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-kubernetes)
- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [JWT Authentication in Jitsi](https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-quickstart#authentication)
