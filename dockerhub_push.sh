#!/bin/bash

DOCKERHUB_USER="tu_usuario"
GITLAB_CONT="gitlab"
JENKINS_CONT="jenkins"
IMAGE_TAG="latest"
GITLAB_IMAGE="$DOCKERHUB_USER/gitlab-ce"
JENKINS_IMAGE="$DOCKERHUB_USER/jenkins-lts"

if ! docker info &> /dev/null; then
  echo "Error: Docker no está disponible."
  exit 1
fi

read -s -p "Ingrese su contraseña de Docker Hub: " DOCKERHUB_PASS
echo ""

echo "Realizando commit de la imagen desde contenedor GitLab ($GITLAB_CONT)..."
docker commit "$GITLAB_CONT" "${GITLAB_IMAGE}:${IMAGE_TAG}" || {
  echo "Error: Falló al crear la imagen de GitLab."
  exit 1
}

echo "Realizando commit de la imagen desde contenedor Jenkins ($JENKINS_CONT)..."
docker commit "$JENKINS_CONT" "${JENKINS_IMAGE}:${IMAGE_TAG}" || {
  echo "Error: Falló al crear la imagen de Jenkins."
  exit 1
}

echo "Iniciando sesión en Docker Hub..."
echo "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin || {
  echo "Error: No se pudo autenticar en Docker Hub."
  exit 1
}

echo "Subiendo imágenes a Docker Hub..."
docker push "${GITLAB_IMAGE}:${IMAGE_TAG}" || {
  echo "Error: Falló al subir la imagen de GitLab."
  exit 1
}

docker push "${JENKINS_IMAGE}:${IMAGE_TAG}" || {
  echo "Error: Falló al subir la imagen de Jenkins."
  exit 1
}

unset DOCKERHUB_PASS

echo "Listado de imágenes locales filtrando por '$DOCKERHUB_USER':"
docker images | grep "$DOCKERHUB_USER"

echo "Proceso completado exitosamente."
