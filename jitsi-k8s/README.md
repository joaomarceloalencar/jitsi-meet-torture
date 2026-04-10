# Jitsi Meet on Kubernetes

A complete Kubernetes setup for deploying Jitsi Meet with JWT authentication, horizontal scalability, and TLS support for local development on macOS with Docker Desktop.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [JWT Authentication](#jwt-authentication)
- [Scaling](#scaling)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Production Deployment](#production-deployment)
- [Cleanup](#cleanup)

## 🎯 Overview

This project provides a production-ready Kubernetes configuration for Jitsi Meet, designed for learning and local development but adaptable for production clusters. It includes:

- Local Certificate Authority (CA) setup
- TLS certificates for secure HTTPS communication
- JWT authentication for user access control
- Horizontal Pod Autoscaling for JVB (Jitsi Videobridge)
- nginx-ingress-controller for routing
- Complete ConfigMaps and Secrets management
- Automated setup and helper scripts

## ✨ Features

- **🔐 JWT Authentication**: Secure access control with token-based authentication
- **📈 Auto-scaling**: JVB scales automatically based on CPU/memory usage (2-10 replicas)
- **🔒 TLS/HTTPS**: Self-signed certificates with local CA
- **🚀 Easy Setup**: One-command deployment with `setup.sh`
- **🧹 Easy Cleanup**: One-command cleanup with `cleanup.sh`
- **🔧 Production-Ready**: Manifests follow Kubernetes best practices
- **📊 Health Checks**: Liveness and readiness probes for all components
- **🎛️ Resource Management**: Defined resource requests and limits

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        nginx-ingress                         │
│                    (TLS Termination)                         │
│                   jitsi.macbookpro                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
         ┌───────────────────────────────┐
         │       jitsi-web               │
         │   (Web Interface)             │
         │   - JWT validation            │
         └───────────┬───────────────────┘
                     │
                     ▼
         ┌───────────────────────────────┐
         │       prosody                 │
         │   (XMPP Server)               │
         │   - JWT auth module           │
         └───────┬───────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌───────────────┐  ┌──────────────────┐
│    jicofo     │  │       jvb        │
│ (Focus/Ctrl)  │  │  (Videobridge)   │
│  - 1 replica  │  │  - 2-10 replicas │
└───────────────┘  │  - Auto-scaling  │
                   └──────────────────┘
```

### Components

1. **jitsi-web**: Web interface and frontend (nginx + React)
2. **prosody**: XMPP server for signaling with JWT authentication
3. **jicofo**: Jitsi Conference Focus - manages conferences
4. **jvb**: Jitsi Videobridge - handles media routing (scalable)

## 📦 Prerequisites

### Required Software

- **macOS** (Tahoe or later)
- **Docker Desktop** with Kubernetes enabled
- **kubectl** (included with Docker Desktop)
- **openssl** (pre-installed on macOS)
- **Python 3** (for JWT token generation)

### Verify Prerequisites

```bash
# Check Docker Desktop and Kubernetes
docker --version
kubectl version --client

# Check if Kubernetes is running
kubectl cluster-info

# Check openssl
openssl version

# Check Python
python3 --version
```

### Enable Kubernetes in Docker Desktop

1. Open Docker Desktop
2. Go to **Settings** → **Kubernetes**
3. Check **Enable Kubernetes**
4. Click **Apply & Restart**
5. Wait for Kubernetes to start (green indicator)

## 🚀 Quick Start

### Automated Setup

```bash
# Clone or navigate to the project directory
cd jitsi-k8s

# Run the automated setup script
./scripts/setup.sh

# Install CA certificate on macOS (you'll be prompted for password)
./scripts/install-ca-macos.sh

# Generate a JWT token for testing
./scripts/generate-jwt-token.sh myusername moderator

# Access Jitsi Meet
open https://jitsi.macbookpro
```

That's it! Jitsi Meet should now be running with JWT authentication.

## 📖 Detailed Setup

### Step 1: Generate Certificates

```bash
# Generate CA (Certificate Authority)
./scripts/generate-ca.sh

# Generate server certificates for jitsi.macbookpro
./scripts/generate-certs.sh
```

**What this does:**
- Creates a local CA with private key and certificate
- Generates TLS certificate signed by the CA
- Certificates are stored in `certs/` directory

### Step 2: Install CA Certificate on macOS

```bash
./scripts/install-ca-macos.sh
```

**What this does:**
- Adds the CA certificate to macOS System Keychain
- Marks it as trusted for SSL/TLS
- Prevents browser security warnings

**To verify installation:**
1. Open **Keychain Access** app
2. Select **System** keychain
3. Look for "Jitsi Local CA"

### Step 3: Configure /etc/hosts

The setup script will prompt you to add the domain to `/etc/hosts`. Alternatively, add it manually:

```bash
# Add entry to /etc/hosts (requires sudo)
echo "127.0.0.1 jitsi.macbookpro" | sudo tee -a /etc/hosts
```

**Verify:**
```bash
ping jitsi.macbookpro
# Should respond from 127.0.0.1
```

### Step 4: Deploy to Kubernetes

#### Option A: Automated (Recommended)

```bash
./scripts/setup.sh
```

#### Option B: Manual Deployment

```bash
# 1. Deploy nginx-ingress-controller
kubectl apply -f k8s/01-nginx-ingress-controller.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=ingress-nginx \
  --timeout=300s

# 2. Create namespace
kubectl apply -f k8s/00-namespace.yaml

# 3. Generate and create secrets
# (See setup.sh for secret generation logic)
# You'll need to manually generate passwords and populate the template

# 4. Create ConfigMaps
kubectl apply -f k8s/02-configmaps.yaml

# 5. Create Services
kubectl apply -f k8s/05-services.yaml

# 6. Create Deployments
kubectl apply -f k8s/04-deployments.yaml

# 7. Create HPA
kubectl apply -f k8s/06-hpa.yaml

# 8. Create Ingress
kubectl apply -f k8s/07-ingress.yaml
```

## 🔑 JWT Authentication

Jitsi Meet is configured with JWT authentication to restrict access to authorized users only.

### Generate JWT Token

```bash
# Generate token for a moderator
./scripts/generate-jwt-token.sh <username> moderator

# Generate token for a regular user
./scripts/generate-jwt-token.sh <username> user
```

**Example:**
```bash
./scripts/generate-jwt-token.sh alice moderator
```

**Output:**
```
============================================================
JWT Token for user: alice (role: moderator)
============================================================

Token:
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

============================================================

To use this token, append it to the Jitsi URL:
https://jitsi.macbookpro/<room-name>?jwt=<token>

Example:
https://jitsi.macbookpro/testroom?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

Token expires in 24 hours.
============================================================
```

### Using JWT Tokens

1. **Generate a token** using the script above
2. **Copy the token** from the output
3. **Access Jitsi** with the token in the URL:
   ```
   https://jitsi.macbookpro/<room-name>?jwt=<your-token>
   ```

### Token Permissions

- **Moderator**: Can create rooms, kick users, mute others
- **User**: Can join rooms, share audio/video

### Token Details

The JWT token contains:
- **User ID**: Username
- **User name**: Display name
- **Email**: Auto-generated (username@example.com)
- **Moderator flag**: true/false
- **Expiration**: 24 hours from generation
- **Room**: `*` (allows access to any room)

## 📊 Scaling

### Horizontal Pod Autoscaler (HPA)

JVB is configured with HPA for automatic scaling based on resource usage.

**Configuration:**
- **Min replicas**: 2
- **Max replicas**: 10
- **Target CPU**: 70%
- **Target Memory**: 80%

**Scale-up policy:**
- Add up to 100% more pods (double) every 30 seconds
- Or add up to 2 pods every 30 seconds
- Uses the maximum of the two policies

**Scale-down policy:**
- Remove up to 50% of pods every 60 seconds
- Or remove 1 pod every 60 seconds
- Uses the minimum of the two policies
- Stabilization window: 5 minutes (prevents flapping)

### View HPA Status

```bash
# Check HPA status
kubectl get hpa -n jitsi

# Watch HPA in real-time
kubectl get hpa -n jitsi --watch

# Detailed HPA information
kubectl describe hpa jvb-hpa -n jitsi
```

### Manual Scaling

You can also scale JVB manually:

```bash
# Scale to 5 replicas
kubectl scale deployment jvb -n jitsi --replicas=5

# Check current replicas
kubectl get deployment jvb -n jitsi
```

**Note:** Manual scaling is temporary. HPA will adjust replicas based on load.

### Disable HPA (for manual scaling)

```bash
# Delete HPA
kubectl delete hpa jvb-hpa -n jitsi

# Now you can manually scale without interference
kubectl scale deployment jvb -n jitsi --replicas=3
```

## ✅ Verification

### Check Deployment Status

```bash
# View all resources in jitsi namespace
kubectl get all -n jitsi

# Check pod status
kubectl get pods -n jitsi

# Check services
kubectl get svc -n jitsi

# Check ingress
kubectl get ingress -n jitsi
```

**Expected output:**
```
NAME                            READY   STATUS    RESTARTS   AGE
pod/jicofo-xxxxxxxxxx-xxxxx     1/1     Running   0          5m
pod/jitsi-web-xxxxxxxxx-xxxxx   1/1     Running   0          5m
pod/jvb-xxxxxxxxxx-xxxxx        1/1     Running   0          5m
pod/jvb-xxxxxxxxxx-yyyyy        1/1     Running   0          5m
pod/prosody-xxxxxxxxxx-xxxxx    1/1     Running   0          5m
```

### View Logs

```bash
# Jitsi Web logs
kubectl logs -n jitsi -l component=web

# Prosody logs
kubectl logs -n jitsi -l component=prosody

# Jicofo logs
kubectl logs -n jitsi -l component=jicofo

# JVB logs
kubectl logs -n jitsi -l component=jvb

# Follow logs in real-time
kubectl logs -n jitsi -l component=jvb -f
```

### Test Access

1. **Open browser**: `https://jitsi.macbookpro`
2. **Generate JWT token**: `./scripts/generate-jwt-token.sh testuser moderator`
3. **Access with token**: `https://jitsi.macbookpro/myroom?jwt=<token>`
4. **Create a meeting** and test audio/video

### Port Forwarding (Alternative Access)

If you want to test without ingress:

```bash
# Forward jitsi-web to localhost:8080
kubectl port-forward -n jitsi svc/jitsi-web 8080:80

# Access at http://localhost:8080
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Pods Not Starting

**Check pod status:**
```bash
kubectl get pods -n jitsi
```

**Check pod logs:**
```bash
kubectl logs -n jitsi <pod-name>
```

**Describe pod for events:**
```bash
kubectl describe pod -n jitsi <pod-name>
```

**Common causes:**
- Image pull errors (check internet connectivity)
- Resource constraints (check if cluster has enough resources)
- Configuration errors (check ConfigMaps and Secrets)

#### 2. Cannot Access https://jitsi.macbookpro

**Check /etc/hosts:**
```bash
grep jitsi.macbookpro /etc/hosts
# Should show: 127.0.0.1 jitsi.macbookpro
```

**Check ingress:**
```bash
kubectl get ingress -n jitsi
kubectl describe ingress jitsi-ingress -n jitsi
```

**Check ingress controller:**
```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

**Test ingress controller:**
```bash
curl -k https://jitsi.macbookpro
```

#### 3. SSL/TLS Certificate Errors

**Verify CA installation:**
1. Open **Keychain Access**
2. Select **System** keychain
3. Search for "Jitsi Local CA"
4. Double-click → Trust → "Always Trust" for SSL

**Regenerate certificates:**
```bash
rm -rf certs/*
./scripts/generate-ca.sh
./scripts/generate-certs.sh
./scripts/install-ca-macos.sh
./scripts/setup.sh  # Re-run to update secrets
```

#### 4. JWT Authentication Not Working

**Check JWT secret:**
```bash
kubectl get secret jitsi-jwt -n jitsi -o yaml
```

**Check prosody logs:**
```bash
kubectl logs -n jitsi -l component=prosody | grep -i jwt
```

**Verify token:**
```bash
# Decode token at https://jwt.io
# Check:
# - Issuer (iss) = "jitsi-meet"
# - Audience (aud) = "jitsi-meet"
# - Not expired (exp)
```

**Regenerate token:**
```bash
./scripts/generate-jwt-token.sh testuser moderator
```

#### 5. No Audio/Video

**Check JVB logs:**
```bash
kubectl logs -n jitsi -l component=jvb
```

**Check JVB UDP service:**
```bash
kubectl get svc jvb-udp -n jitsi
# Should show NodePort 30000
```

**Firewall issues:**
- Ensure UDP port 30000 is not blocked
- Check Docker Desktop network settings

#### 6. HPA Not Working

**Check metrics-server:**
```bash
kubectl get deployment metrics-server -n kube-system
```

**Install metrics-server if missing:**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**For Docker Desktop, patch metrics-server:**
```bash
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

### Debug Commands

```bash
# Get all events in jitsi namespace
kubectl get events -n jitsi --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods -n jitsi

# Restart a deployment
kubectl rollout restart deployment <deployment-name> -n jitsi

# Delete and recreate a pod
kubectl delete pod <pod-name> -n jitsi

# Execute commands in a pod
kubectl exec -it <pod-name> -n jitsi -- /bin/bash

# Check DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup jitsi-web.jitsi.svc.cluster.local
```

## 🏭 Production Deployment

This setup is designed for local development but can be adapted for production clusters. Here are the key changes needed:

### 1. Certificate Management

**Replace self-signed certificates with cert-manager + Let's Encrypt:**

```yaml
# Add cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

**Update Ingress annotations:**
```yaml
annotations:
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

### 2. Domain Configuration

- Replace `jitsi.macbookpro` with your actual domain
- Configure DNS A record pointing to your cluster's external IP
- Remove `/etc/hosts` configuration

### 3. Ingress Controller

**For cloud providers, use LoadBalancer type:**

```yaml
# In 01-nginx-ingress-controller.yaml
spec:
  type: LoadBalancer  # Already set
  # Cloud provider will assign external IP
```

### 4. Storage

**Add persistent storage for recordings (if needed):**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jitsi-recordings
  namespace: jitsi
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: standard  # Use your storage class
```

### 5. Resource Limits

**Adjust based on your expected load:**

```yaml
# For high-traffic production:
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### 6. JVB Configuration

**For production with many participants:**

- Increase JVB replicas: `minReplicas: 5`, `maxReplicas: 50`
- Configure STUN/TURN servers for NAT traversal
- Set up proper network policies
- Consider using OCTO for multi-region deployments

### 7. Security Enhancements

- Use NetworkPolicies to restrict traffic
- Enable Pod Security Standards
- Rotate JWT secrets regularly
- Use external secret management (e.g., HashiCorp Vault, AWS Secrets Manager)
- Enable audit logging
- Set up monitoring and alerting (Prometheus, Grafana)

### 8. High Availability

- Run multiple replicas of all components
- Use anti-affinity rules to spread pods across nodes
- Configure PodDisruptionBudgets
- Set up database for prosody (PostgreSQL, MySQL)

### 9. Monitoring

**Add Prometheus and Grafana:**

```bash
# Install Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

**Configure ServiceMonitors for Jitsi components.**

### 10. Backup and Disaster Recovery

- Backup certificates and secrets
- Document configuration
- Set up automated backups of persistent volumes
- Test disaster recovery procedures

## 🧹 Cleanup

### Remove Jitsi from Kubernetes

```bash
# Run cleanup script
./scripts/cleanup.sh
```

This will:
- Delete all Jitsi resources from Kubernetes
- Optionally delete nginx-ingress-controller
- Preserve certificates and secrets on disk

### Complete Cleanup

**Remove all files:**
```bash
# Remove certificates
rm -rf certs/

# Remove JWT secrets
rm -rf .secrets/

# Remove generated secrets manifest
rm -f k8s/03-secrets.yaml
```

**Remove CA from macOS:**
```bash
sudo security delete-certificate -c "Jitsi Local CA" /Library/Keychains/System.keychain
```

**Remove /etc/hosts entry:**
```bash
sudo sed -i '' '/jitsi.macbookpro/d' /etc/hosts
```

## 📁 Project Structure

```
jitsi-k8s/
├── README.md                           # This file
├── certs/                              # TLS certificates (generated)
│   ├── ca-cert.pem                     # CA certificate
│   ├── ca-key.pem                      # CA private key
│   ├── tls.crt                         # Server certificate
│   └── tls.key                         # Server private key
├── k8s/                                # Kubernetes manifests
│   ├── 00-namespace.yaml               # Jitsi namespace
│   ├── 01-nginx-ingress-controller.yaml # Ingress controller
│   ├── 02-configmaps.yaml              # ConfigMaps for all components
│   ├── 03-secrets.yaml.template        # Secrets template
│   ├── 03-secrets.yaml                 # Generated secrets (not in git)
│   ├── 04-deployments.yaml             # Deployments for all components
│   ├── 05-services.yaml                # Services for all components
│   ├── 06-hpa.yaml                     # HorizontalPodAutoscaler for JVB
│   └── 07-ingress.yaml                 # Ingress with TLS
├── scripts/                            # Helper scripts
│   ├── generate-ca.sh                  # Generate CA
│   ├── generate-certs.sh               # Generate TLS certificates
│   ├── install-ca-macos.sh             # Install CA on macOS
│   ├── setup.sh                        # Automated setup
│   ├── generate-jwt-token.sh           # Generate JWT tokens
│   └── cleanup.sh                      # Cleanup all resources
└── .secrets/                           # JWT secrets (generated, not in git)
    ├── jwt_app_secret                  # JWT signing secret
    └── jwt_app_key                     # JWT encryption key
```

## 📚 Additional Resources

- [Jitsi Meet Documentation](https://jitsi.github.io/handbook/docs/intro)
- [Jitsi JWT Authentication](https://jitsi.github.io/handbook/docs/devops-guide/secure-domain)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [nginx-ingress Documentation](https://kubernetes.github.io/ingress-nginx/)
- [Docker Desktop Kubernetes](https://docs.docker.com/desktop/kubernetes/)

## 🤝 Contributing

This is a learning project. Feel free to:
- Report issues
- Suggest improvements
- Share your production adaptations

## 📝 License

This project is provided as-is for educational purposes.

## 🎓 Learning Objectives

By working with this project, you'll learn:

- ✅ Kubernetes deployments and services
- ✅ ConfigMaps and Secrets management
- ✅ Ingress and TLS termination
- ✅ Horizontal Pod Autoscaling
- ✅ Health checks and resource management
- ✅ JWT authentication
- ✅ Certificate management
- ✅ Kubernetes best practices

---

**Happy video conferencing! 🎥**
