#!/bin/bash

set -e  # Detener en caso de error

# Validar dependencias
DEPENDENCIAS=(git kubectl minikube)
for cmd in "${DEPENDENCIAS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' no está instalado o no está en el PATH." >&2
        exit 1
    fi
done

# Variables
WORKDIR="TP-Cloud"
REPO_MANIFIESTOS="https://github.com/bzabalal/manifiestos.git"
REPO_HTML="https://github.com/bzabalal/static-website2.git"
HTML_DIR="static-website2"
MANIF_DIR="manifiestosTD5"
MOUNT_PATH="/mnt/web"
LOCAL_MOUNT="$(pwd)/../$HTML_DIR"

echo "Creando carpeta de trabajo '$WORKDIR' si no existe..."
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Clonar repositorios si no existen
[ ! -d "$MANIF_DIR" ] && git clone "$REPO_MANIFIESTOS" "$MANIF_DIR"
[ ! -d "$HTML_DIR" ] && git clone "$REPO_HTML" "$HTML_DIR"

cd "$MANIF_DIR"

# Crear carpeta de montaje local si no existe
mkdir -p "$LOCAL_MOUNT"

echo "Iniciando Minikube con montaje de $LOCAL_MOUNT en $MOUNT_PATH..."
minikube start --mount --mount-string="$LOCAL_MOUNT:$MOUNT_PATH"

echo "Aplicando manifiestos (volume, service, deployment)..."
for dir in volume service deployment; do
    if [ -d "$dir" ]; then
        echo "Aplicando manifiestos en $dir/"
        kubectl apply -f "$dir"
    else
        echo "Carpeta $dir no encontrada, se omite."
    fi
done

# Esperar a que el pod sea creado
while true; do
    POD_NAME=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep static-site | head -n 1)
    if [ -n "$POD_NAME" ]; then
        break
    fi
    echo "Esperando a que el pod 'static-site' sea creado..."
    sleep 3
done

# Esperar a que el pod esté Ready
kubectl wait --for=condition=Ready pod/"$POD_NAME" --timeout=400s

echo "Abriendo el servicio web en el navegador..."
minikube service static-site-service

# Habilitar Ingress
minikube addons enable ingress

# Esperar a que el controlador ingress esté listo
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

# Aplicar manifiestos de ingress
if [ -d "ingress" ]; then
    kubectl apply -f ingress
fi

# Obtener IP de Minikube y agregar a /etc/hosts
MINIKUBE_IP=$(minikube ip)
echo "$MINIKUBE_IP local.service" | sudo tee -a /etc/hosts > /dev/null

echo "El ingress y la URL ya están habilitados"
echo "Accedé a la página desde: http://local.service/"

xdg-open http://local.service/ 2>/dev/null || open http://local.service/

