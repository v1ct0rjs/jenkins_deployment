# Despliegue de Imágenes a DockerHub

### *Guía de Despliegue de GitLab CE y Jenkins LTS con Docker Compose en Fedora 41*

Esta documentación detalla paso a paso cómo instalar Docker en Fedora 41, desplegar GitLab Community Edition (CE) y Jenkins LTS en contenedores Docker usando **Docker Compose**, e integrar ambos servicios. También se explica cómo configurar un pipeline en Jenkins para construir imágenes Docker y publicarlas en Docker Hub, incluyendo un **script Bash** (`dockerhub_push.sh`) y un **Jenkinsfile** de ejemplo. La guía está estructurada en secciones, como una documentación tipo `README.md`, para su fácil consulta.



---

### Índice

- Introducción

#### [Parte 1: Instalación de Docker y Preparación del Entorno](#Parte-1:-Instalación-de-Docker-y-Preparación-del-Entorno)

- Instalar Docker Engine y Docker Compose
- Habilitar y arrancar Docker
- Verificar Docker Compose
- Definir archivo docker-compose.yml

#### [Parte 2: Configuración Inicial de GitLab](#Parte-2:-Configuración-Inicial-de-GitLab)

- Obtener la contraseña inicial de root
- Acceder a la interfaz de GitLab
- Crear un nuevo repositorio en GitLab
- Crear un token de acceso personal (PAT) en GitLab

#### [Parte 3: Script dockerhub_push.sh](#Parte-3:-Script-dockerhub-push.sh)

- Funcionalidad del script

#### [Parte 4: Jenkinsfile (Pipeline de Jenkins)](#Parte-4:-Jenkinsfile-(Pipeline de Jenkins))

- Estructura del pipeline

#### [Parte 5: Configuración del Contenedor Jenkins para Docker](#Parte-5:-Configuración-del-Contenedor-Jenkins-para-Docker)

- Configurar Docker dentro de Jenkins

#### [Parte 6: Integración GitLab – Jenkins](#Parte-6:-Integración-GitLab-–-Jenkins)

- Obtener contraseña inicial de Jenkins
- Instalar plugins necesarios en Jenkins
- Configurar la conexión Jenkins ↔ GitLab
- Configurar el job de Jenkins para integrarlo con GitLab

#### Pruebas de funcionamiento

#### Conclusiones

### 📌[ANEXO Implementación con SonarQube](https://github.com/v1ct0rjs/jenkins_deployment/tree/main/SonarQube)📌
 ---





### Parte 1: Instalación de Docker y Preparación del Entorno

**1. Instalar Docker Engine y Docker Compose:** En Fedora 41, Docker no viene por defecto, así que debemos instalarlo desde los repositorios oficiales de Docker. 

```bash
# Instalar utilidades DNF y agregar el repositorio oficial de Docker
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

# Instalar Docker Engine, CLI y Docker Compose (plugin v2) desde el repo de Docker
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

```

Estos comandos agregarán el repositorio de Docker y luego instalarán Docker Engine, el CLI de Docker, Containerd y los complementos de Buildx y Compose.

Tras la instalación, se crea el grupo de sistema `docker`, añade tu usuario al grupo de docker.

```bash
sudo usermod -aG docker $USER
```

Para que tu sesión reconozca inmediatamente la nueva pertenencia al grupo usa

```bash
newgrp docker
```

**2. Habilitar y arrancar Docker:** Una vez instalado, habilite el servicio de Docker para que inicie automáticamente:

```bash
sudo systemctl enable --now docker
sudo systemctl start docker
```

Verificamos que Docker funciona correctamente ejecutando el contenedor de prueba de docker

```bash
sudo docker run hello-world
```

**3. Verificamos Docker Compose:** Puedes comprobarlo con:

```bash
docker compose version
```

[![image-20250403203850089](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250403203850089.png)

**4. Definir `docker-compose.yml` con GitLab CE y Jenkins:** Creamo un archivo llamado **`docker-compose.yml`** en el directorio del proyecto con el siguiente contenido:

```dockerfile
version: "3.8"

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab
    hostname: gitlab
    restart: always
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://localhost'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
    ports:
      - "80:80"
      - "443:443"
      - "2222:22"
    volumes:
      - gitlab-config:/etc/gitlab
      - gitlab-logs:/var/log/gitlab
      - gitlab-data:/var/opt/gitlab

  jenkins:
    image: jenkins/jenkins:lts
    container_name: jenkins
    hostname: jenkins
    restart: always
    user: root
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
      - /usr/bin/docker:/usr/bin/docker  

networks:
  default:
    name: ci-network

volumes:
  gitlab-config:
  gitlab-logs:
  gitlab-data:
  jenkins_home:
```

Este archivo de configuración en Docker Compose define dos servicios principales para nuestra infraestructura:

##### **GitLab**

- Utiliza la imagen oficial `gitlab/gitlab-ce:latest` para montar un servidor GitLab Community Edition.
- Escucha en los puertos estándar HTTP (80), HTTPS (443), y personaliza el puerto SSH en `2222` (para evitar conflictos con SSH del host).
- Se establece la URL externa como `http://localhost`.
- Utiliza tres volúmenes para conservar persistencia:
  - Configuración (`/etc/gitlab`)
  - Logs (`/var/log/gitlab`)
  - Datos del repositorio y aplicaciones (`/var/opt/gitlab`).

#####  **Jenkins**

- Utiliza la imagen estable oficial de Jenkins (`jenkins/jenkins:lts`) para un servidor de integración continua.
- Se ejecuta como `root` para simplificar acceso a Docker (aunque esto debería manejarse con cuidado en producción por razones de seguridad).
- Escucha en dos puertos:
  - `8080`: interfaz web para administrar Jenkins.
  - `50000`: utilizado para agentes Jenkins externos.
- Monta volúmenes para persistencia:
  - `jenkins_home`: para almacenar la configuración y trabajos de Jenkins.
- Se monta el socket Docker (`docker.sock`) y binario de Docker directamente en el contenedor Jenkins, permitiendo así ejecutar comandos Docker desde dentro de Jenkins (para tareas como construir y lanzar imágenes).

##### Redes y volúmenes

- Ambos servicios se encuentran en la misma red Docker llamada `ci-network` para facilitar la comunicación entre ellos.
- Los volúmenes se gestionan directamente desde Docker Compose para persistencia a largo plazo.

Guardamos el archivo `docker-compose.yml`. Luego, inicié ambos contenedores con:

```bash
docker compose up -d
```

![image-20250403205217546](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250403205217546.png)

Esto descargará las imágenes (si no se tienen ya) y levantará los contenedores en segundo plano (`-d`). Puede verificar que estén corriendo con `docker compose ps` o `docker ps`. La primera vez, **GitLab CE** puede tardar varios minutos en inicializar completamente (configurar la base de datos interna, etc.).



### Parte 2: Configuración Inicial de GitLab

Con los contenedores en marcha, procedemos a configurar GitLab CE para su primer uso.

**1. Obtener la contraseña inicial de root:** GitLab crea un usuario administrador `root` por defecto en el contenedor. En instalaciones Docker, se genera una contraseña aleatoria para `root` y se almacena en el contenedor (archivo `/etc/gitlab/initial_root_password`). Tenemos que recuperar esa contraseña desde el contenedor:

```bash
docker exec gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

Deberías obtener una salida similar a:

```
Password: AbCdEfG123456789
```

**2. Acceder a la interfaz de GitLab:** Abra un navegador web y acceda a la URL de GitLab. Si está en la misma máquina Linux, puede usar `http://localhost` (o `http://<IP-o-hostname>` si es remoto). Debería cargar la pantalla de inicio de GitLab. Haga clic en **"Sign in"** (Iniciar sesión). Ingrese **Username:** `root` y como **Password** utilice la contraseña obtenida en el paso anterior.

![image-20250403221201732](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250403221201732.png)

Al iniciar sesión por primera vez, GitLab puede pedirte que cambie la contraseña de root por una nueva. Es recomendable hacerlo por seguridad. Alternativamente, podría crear un nuevo usuario administrador distinto, pero para simplificar usaremos `root` en esta guía.


![image-20250403221900817](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250403221900817.png)

**3. Crear un nuevo repositorio en GitLab:** Una vez dentro de GitLab, cree un proyecto nuevo donde alojaremos nuestro código.

- En la página de inicio (dashboard) o en el menú superior, haz clic en **"New Project"** (Nuevo proyecto).
- Selecciona **"Create blank project"** (Proyecto en blanco).
- Asigna un nombre al proyecto (Puede dejarlo como proyecto **Privado** por ahora).
- Opcionalmente agregua una descripción y marque la casilla de inicializar con un README.
- Pulse **"Create project"**.

![image-20250403222354031](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250403222354031.png)

GitLab creará el repositorio vacío. En la siguiente pantalla verá las instrucciones para agregar archivos. Puedes optar por clonar el repositorio localmente y añadir archivos, o bien usar la interfaz web para subirlos posteriormente. 

**4. Crear un token de acceso personal (PAT) en GitLab**
Para que Jenkins pueda hablar con GitLab (por ejemplo, para hacer checkout del código o configurar webhooks), hace falta un token de acceso personal. Este token es la credencial que Jenkins usará para conectarse a la API de GitLab y a los repositorios. Vamos a crearlo:

- En GitLab, haz clic en el ícono de tu usuario (arriba a la derecha, donde sale tu inicial o foto) y elige “Edit profile” o “Preferences”.
- En el menú lateral, busca “Access Tokens”.
- En “Personal Access Tokens”, ponle un nombre que describa su uso, por ejemplo, “jenkins-token”.
- En “Scopes”, marca **api**, **read_repository** y **write_repository**. Con esto, Jenkins podrá hacer llamadas a la API, leer repositorios y, si alguna vez hace falta, escribir o actualizar cosas (como pipelines).
- Luego, haz clic en “Create personal access token”. GitLab generará un token único (una cadena de letras y números) y solo lo verás esta vez, así que cópialo y guárdalo en un lugar seguro.

Ya tienes tu proyecto en GitLab y un token para que Jenkins se conecte. En el siguiente paso prepararemos el script y el `Jenkinsfile` en tu repositorio, y luego configuraremos Jenkins para usar este token.

Necesitaremos agregar el `Jenkinsfile` y el script `dockerhub_push.sh` al repositorio.

![image-20250404003355650](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250404003355650.png)

## Parte 3: Script `dockerhub_push.sh`

Crearemos un script Bash que Jenkins utilizará para construir imágenes Docker a partir de contenedores en ejecución y subirlas a Docker Hub. Este script realiza los siguientes pasos de forma automatizada:

1. **Crear la imagen Docker desde el contenedor en ejecución.** Para ello usaremos el comando `docker commit`, que guarda el estado actual de un contenedor como una nueva imagen. En este caso, vamos a *capturar* la imagen de GitLab y Jenkins tal como están en el momento.
2. **Etiquetar la imagen con el repositorio de Docker Hub del usuario.** Por convención, para poder subir una imagen a Docker Hub, la imagen debe estar etiquetada con el nombre de usuario de Docker Hub y el nombre del repositorio destino.
3. **Hacer push de la imagen al Docker Hub.** Usaremos `docker push` para enviar la imagen al registro Docker Hub. Esto requiere autenticarse (`docker login`) con las credenciales de Docker Hub. Supongo que ya tienes una cuenta en Docker Hub y que se proporcionará el usuario y contraseña.

```bash
#!/bin/bash

if ! docker info &> /dev/null; then
  echo "Error: Docker no está disponible."
  exit 1
fi

GITLAB_CONT="gitlab"
JENKINS_CONT="jenkins"
IMAGE_TAG="latest"
GITLAB_IMAGE="$DOCKERHUB_USER/gitlab-ce"
JENKINS_IMAGE="$DOCKERHUB_USER/jenkins-lts"

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

```

#### **¿Que hace este script?**:

1. **Verifica que Docker esté funcionando:**

   - `docker info &> /dev/null`: comprueba si Docker está disponible.
   - Si Docker no está activo o accesible, muestra un error y termina.

2. **Define variables necesarias**:

   - Nombres de contenedores:
     - `gitlab`
     - `jenkins`
   - Nombre de usuario de Docker Hub (`$DOCKERHUB_USER`) y la etiqueta de las imágenes (`latest`).

3. **Crea imágenes Docker desde contenedores existentes**:

   - Usa el comando `docker commit` para guardar el estado actual de cada contenedor como una imagen nueva:
     - Imagen GitLab: `docker commit gitlab usuario/gitlab-ce:latest`
     - Imagen Jenkins: `docker commit jenkins usuario/jenkins-lts:latest`
   - Si ocurre algún error durante el commit, el script se detiene mostrando un mensaje de error.

4. **Inicio de sesión en Docker Hub automáticamente**:

   - Utiliza la contraseña almacenada en la variable de entorno `$DOCKERHUB_PASS` para iniciar sesión en Docker Hub automáticamente sin necesidad de interacción manual.
   - Si la autenticación falla, el script se detiene.

5. **Sube las imágenes al repositorio Docker Hub**:

   - Ejecuta `docker push` para subir las imágenes creadas previamente:
     - `docker push usuario/gitlab-ce:latest`
     - `docker push usuario/jenkins-lts:latest`
   - Si alguna subida falla, el script se detiene mostrando un error.

6. **Seguridad**:

   - Después del uso, la variable que contiene la contraseña (`DOCKERHUB_PASS`) es eliminada de la memoria (`unset`) por seguridad.

7. **Muestra un listado final de las imágenes locales**:

   - Ejecuta `docker images` filtrando por tu usuario de Docker Hub para confirmar visualmente que las imágenes se han creado correctamente.

   

## Parte 4: Jenkinsfile (Pipeline de Jenkins)

El siguiente paso es crear un **pipeline** de Jenkins definido como archivo, es decir, un **Jenkinsfile** que residirá en el repositorio.

Este Jenkinsfile ordenara al contenedor Jenkins cómo realizar el proceso de construcción y despliegue cuando se dispare el pipeline. 

Las etapas principales serán: **Checkout** del código desde GitLab, **Construcción y Push** de las imágenes mediante el script, y una etapa de **Verificación** final.

```Jenkinsfile
pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'gitlab-pat'
        DOCKER_CREDS = credentials('dockerhub-creds')
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'http://gitlab/root/demo_project.git',
                    credentialsId: "${GIT_CREDENTIALS}"
            }
        }

        stage('Build & Push Docker Images') {
            steps {
                sh '''
                    chmod +x dockerhub_push.sh
                    # Usamos las variables expuestas por 'credentials(...)':
                    #   $DOCKER_CREDS_USR = usuario de DockerHub
                    #   $DOCKER_CREDS_PSW = contraseña de DockerHub
                    DOCKERHUB_USER="$DOCKER_CREDS_USR" \
                    DOCKERHUB_PASS="$DOCKER_CREDS_PSW" \
                    ./dockerhub_push.sh
                '''
            }
        }

        stage('Verify Images') {
            steps {
                // Verifica que las imágenes se hayan creado localmente
                sh "docker images | grep '${env.DOCKER_CREDS_USR}'"
            }
        }
    }
}
```

------

#### **¿Qué hace este Jenkinsfile?**

Este Jenkinsfile define un pipeline de Jenkins para automatizar:

- **Descarga de código** desde un repositorio GitLab privado.
- **Construcción y subida de imágenes Docker** personalizadas hacia Docker Hub.
- **Verificación** de que las imágenes Docker están disponibles localmente tras el proceso.

------

##### **Estructura del Pipeline**:

**Agente:** Se ejecuta en cualquier agente disponible (`agent any`).

**Variables de entorno:**

- `GIT_CREDENTIALS`: Credencial de Jenkins (Personal Access Token o PAT) para autenticarse con GitLab.
- `DOCKER_CREDS`: Credenciales almacenadas en Jenkins para autenticarse con Docker Hub.

------

#### 🔹 Etapas del pipeline

##### 1️⃣ **Checkout**:

- Clona el repositorio GitLab usando la rama `main`.
- Usa credenciales almacenadas (`gitlab-pat`).

##### 2️⃣ **Build & Push Docker Images**:

- Ejecuta un script llamado `dockerhub_push.sh`.
- Usa credenciales de Docker Hub (usuario y contraseña) almacenadas en Jenkins (`dockerhub-creds`) para autenticar y subir las imágenes Docker automáticamente.

##### 3️⃣ **Verify Images**:

- Verifica mediante un comando `docker images` filtrado por tu usuario Docker Hub, que las imágenes Docker se hayan creado y estén disponibles en la máquina local.

------

## Parte 5: Configuración del Contenedor Jenkins para Docker

Para que el pipeline funcione, el contenedor de Jenkins necesita poder ejecutar comandos Docker.

Habiamos definido en el archivo Docker-compose.yml varios volumenes con el host para permitir al contenedor de Jenkins poder utilizar docker para automatizar el push de los contenedores a Dockerhub.

```
      - /var/run/docker.sock:/var/run/docker.sock
      - /usr/bin/docker:/usr/bin/docker  
```

Esos dos mapeos suelen hacerse para que, desde dentro de un contenedor, se pueda acceder al daemon Docker del **host** (la máquina que corre Docker) y así ejecutar comandos Docker como si estuvieras directamente en la máquina host:

- `- /var/run/docker.sock:/var/run/docker.sock`:
   Monta el *socket* de Docker del host dentro del contenedor. Este *socket* es la vía principal de comunicación con el daemon de Docker. Al montarlo dentro del contenedor, los procesos dentro del contenedor pueden emitir órdenes al Docker daemon del host (por ejemplo, crear contenedores, construir imágenes, etc.).
- `- /usr/bin/docker:/usr/bin/docker`:
   Monta el binario de Docker (`docker`) del host dentro del contenedor, de modo que dentro del contenedor puedas ejecutar el comando `docker` como si estuviera instalado ahí. Junto con el socket, te permite correr `docker build`, `docker run`, etc., desde dentro del contenedor, pero en realidad controlas el Docker del host.

Para que funcionen correctamente estos dentro del contenedor de jenkins se debe crear un grupo `docker` con el mismo GID que el grupo `docker` del host que ejecuta docker para ello tenemos que realizar ciertas acciones dentrod el contenedor de Jenkins:

1. Debemos comprobar el GID del grupo docker en el host para ello realizamos 

   ```bash
   getent group docker
   ```

   ![image-20250403232233998](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250403232233998.png)

   Esto devolverá el GID del grupo docker el cual tendremos que usar al crear el grupo docker dentro del contenedor de Jenkins en nuestro caso es el GID 975

   *Nota. cuando ejecutas el comado `getent group docker`tu GID puede ser distinto a 975, ten esto en cuenta a la hora de realizar los siguientes pasos*

2. Accedemos al contenedor de docker con

   ```bash
   docker exec -it -u root jenkins bash
   ```

   Una vez dentro podremos ejecutar acciones dentro del contenedor

3. Creamos el grupo docker dentro del contenedor

   ```bash
   groupadd -g 975 docker
   ```

4. Una vez creado el grupo añadimos al usuario `jenkins` dentro del grupo

   ```bash
   usermod -aG docker jenkins
   ```

Con estos pasos ya podemos usar docker desde el contenedor de Jenkins.

Podemos comprobar que todo ha salido bien si desde la shell del host ejecutamos esto.

```bash
docker exec -u jenkins jenkins docker ps
```

![image-20250403233232369](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250403233232369.png)

## Parte 6: Integración GitLab – Jenkins

Ahora integraremos GitLab y Jenkins, de modo que Jenkins pueda ser notificado cuando haya cambios en GitLab y reportar resultados de vuelta. Los pasos incluyen: acceder a Jenkins y configurarlo, instalar plugins, añadir las credenciales y URL de GitLab en Jenkins, y configurar el job de pipeline para escuchar a GitLab.

**1. Obtener contraseña inicial de Jenkins:** Al igual que GitLab, una nueva instancia de Jenkins requiere un paso inicial. Cuando se creó el contenedor Jenkins por primera vez, generó una contraseña aleatoria para el usuario `admin`

En el caso de Jenkins, se guarda en `/var/jenkins_home/secrets/initialAdminPassword`. Recuperémosla ejecutando en la máquina host:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Esto mostrará una cadena alfanumérica. Copia esa contraseña

Ahora abre un navegador y vamos a **Jenkins** en `http://localhost:8080` 

![image-20250403234359069](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250403234359069.png)

Jenkins te preguntará qué plugins instalar. Puedes elegir **"Install suggested plugins"** (Instalar plugins sugeridos) para que instale una lista básica recomendada. Esto tomará unos minutos. 

![image-20250403234611732](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250403234611732.png)

Luego te pedirá crear un usuario administrador. Puede crear un usuario nuevo (recomendado) o continuar con el usuario `admin` estableciendo una contraseña. 

![image-20250403234819709](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250403234819709.png)

Completa estos pasos hasta llegar al panel principal "Jenkins is ready".

![image-20250403235123896](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250403235123896.png)

**2. Instalar plugins necesarios en Jenkins:** Vamos a instalar dos plugins específicos:

- **GitLab Plugin** (también conocido como **GitLab Jenkins** plugin). Este plugin permite la integración entre Jenkins y GitLab (autenticación de webhook, notificación de estado, etc).
- **OWASP Dependency-Check Plugin** (opcional, mencionado en el requerimiento). Este plugin se utiliza para análisis de dependencias en busca de vulnerabilidades. No lo configuraremos en detalle aquí, pero instalémoslo por completitud.

Para instalar plugins: en Jenkins, ve a **Manage Jenkins** > **Manage Plugins** > pestaña **Available**. 

Usa la barra de búsqueda para encontrar **"GitLab"**. 

Selecciónelo y marque "Install without restart". 

Haz lo mismo con **"OWASP Dependency-Check"** .

Luego haga clic en **"Apply Changes"** o **"Install"**, y Jenkins descargará e instalará estos plugins.

![image-20250403235658744](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250403235658744.png)

![image-20250403235734046](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250403235734046.png)

**3. Configurar la conexión Jenkins ↔ GitLab:** Una vez instalado el GitLab Plugin, configureremos Jenkins para que pueda comunicarse con GitLab:

En Jenkins, vaya a **Manage Jenkins > Configure System**. Desplácese hasta encontrar la sección **"GitLab"** agregada por el plugin.

Marqua la casilla **"Enable authentication for '/project' end-point"** 

![image-20250404001729536](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250404001729536.png)

Esto asegura que Jenkins espere un token para triggers entrantes desde GitLab.

Ahora tenemos que añadir las credenciales de GitLab (el token personal que creamos). En la sección **"Credentials"**, haz clic en **"Add"**, luego en **"Jenkins"**, y selecciona **"GitLab API token"** como tipo de credencial.

Pega el **Personal Access Token** de GitLab en el campo que corresponda (Token de API) y asígnale un **ID** que puedas identificar fácilmente, por ejemplo `gitlab-token-creds`.

En **"GitLab host URL"**, especifica la dirección donde tu instancia de GitLab es accesible **desde el contenedor de Jenkins**. Dado que configuramos la red interna de Docker, podrías usar una dirección como `http://gitlab`.

En la sección **"Credentials"** de la configuración (GitLab host credentials), elige el token que acabas de agregar (por ejemplo, `gitlab-token-creds`).

Por último, haz clic en **"Test Connection"**. Debería aparecer un mensaje de **"Success"**, indicando que Jenkins se conectó correctamente a GitLab usando ese token.
 Si ves un error, revisa que la URL sea válida y accesible desde el contenedor de Jenkins. Por ejemplo, si Jenkins no puede resolver el nombre `gitlab`, puede que la red no esté configurada correctamente o que debas usar la dirección IP interna del contenedor de GitLab. En la mayoría de los casos, si estás usando Docker Compose con una red personalizada, el nombre de host debería funcionar sin problemas.

![image-20250404001645868](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250404001645868.png)

Ahora es el momento de generar unas credenciales en Jenkins para poder para que el pipeline funcione correctamente pueda realizar una conexión a a Gitlab y también debe almacenar las credenciales de acceso a Dockerhub, de esta forma evitamos crear un archivo de variables de entorno y tenerlo que ignorar cuando realizamos un push a nuestro repositorio Gitlab.

Para ello debemos almacenar el usuario y la contraseña para el acceso en este caso como `root` de Gitlab con su contraseña y el usuario + password de DockerHub. Vamos a Administrar **Jenkins > Credenciales**.

Una vez añadimos dos credenciales de tipo global, una para GitLab, en **Kind** sleccionamos *Username whit password* añadimos nuestro usuario root de GitLab y la contraseña. como ID usaremos `gitlab-pat`

![image-20250404033930119](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250404033930119.png)

A continuacion realizaremos el mismo paso anterior pero añadiendo las credenciales para DockeHub y con el ID `dockerhub-cred`

![image-20250404034120547](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250404034120547.png)

**4. Configurar el job de Jenkins para integrarlo con GitLab**
En este momento, ya tienes un `Jenkinsfile` en el repositorio y Jenkins sabe cómo autenticarse con GitLab. El siguiente paso es crear en Jenkins un Job de tipo Pipeline que se vincule con tu repositorio de GitLab:

- En Jenkins, ve a **New Item**.

- Introduce un nombre para el job, por ejemplo “CI Demo Pipeline”, y selecciona **Pipeline**. Luego haz clic en **OK**.

- En la configuración del job:

  - En la sección **General**, puedes agregar una descripción si lo deseas.
  - Busca la sección **Pipeline**. En el campo **Definition**, elige **Pipeline script from SCM**. Esto indica que Jenkins obtendrá el archivo `Jenkinsfile` directamente desde tu repositorio de GitLab.
  - En **SCM**, selecciona **Git** y, en los campos que aparezcan:
    - En **Repository URL**, coloca la URL HTTP de tu repositorio en GitLab (por ejemplo, `http://gitlab/root/demo_project.git`).
    - En **Credentials**, escoge las credenciales del token de GitLab que agregaste (por ejemplo, `gitlab-token-creds`). Esto permitirá que Jenkins use el token como autenticación HTTP.
    - En **Branch**, especifica la rama que desees, por ejemplo `*/main` si esa es la que contiene tu `Jenkinsfile`.
    - Asegúrate de que **Script Path** sea “Jenkinsfile”, que es el nombre del archivo pipeline en tu repositorio.

  *(Si en lugar de “Pipeline script from SCM” prefieres copiar y pegar el contenido del `Jenkinsfile` en Jenkins, puedes elegir “Pipeline script” y escribirlo ahí mismo. Sin embargo, usar SCM te permite actualizarlo automáticamente cuando el repositorio cambie.)*

  ![image-20250404032317904](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250404032317904.png)

- Un poco más arriba, en la configuración del job, encontrarás la sección **Build Triggers**. Con el plugin de GitLab instalado, deberías ver opciones como **“Build when a change is pushed to GitLab”**. Activa esa casilla.

  - También puedes marcar eventos relacionados con **Merge Requests** si quieres que Jenkins se ejecute cuando se abran o cierren solicitudes de fusión.
  - En **GitLab Connection**, selecciona la conexión que configuraste anteriormente. Así, Jenkins podrá registrar automáticamente un webhook en tu proyecto de GitLab (requiere el token con el alcance “api”). Si no lo hace automáticamente, ve manualmente a **Settings > Webhooks** en GitLab y crea uno usando la URL que Jenkins te muestre (normalmente algo como `http://<JENKINS_HOST>/project/CI%20Demo%20Pipeline`).

- Finalmente, haz clic en **Save** para guardar la configuración del job.

## Pruebas de funcionamiento

Al realizar algún cambio dentro del repositorio GitLab podremos ver como se dispara el triggery se ejecuta el Jenkinsfile y el Scrip creando las imágenes de los dos contenedores en el estado en que se encuentran y subiendolas al repositorio de imagenes de DockeHub. Adjunto algunas capturas y gif de su funcionamiento que lo podemos observar desde la consola de jenkins.

![image-20250404035054059](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250404035054059.png)



![image-20250404035105864](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250404035105864.png)

![Peek 04-04-2025 03-54](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/Peek%2004-04-2025%2003-54.gif)



![image-20250404035703855](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/img/image-20250404035703855.png)

## Conclusiones

Al completar estos pasos, tendrás listo tu propio entorno de CI/CD local usando GitLab CE para gestionar repositorios Git y Jenkins como servidor de integración continua (CI). Todo esto estará orquestado con Docker Compose, lo que facilita muchísimo su despliegue y mantenimiento.

¿Cómo funciona? Muy sencillo: cada vez que realices un commit en tu repositorio GitLab, automáticamente Jenkins lanzará una pipeline (definida mediante un archivo llamado `Jenkinsfile` que tendrás en tu propio repositorio). Esta pipeline construirá imágenes Docker y luego las publicará automáticamente en Docker Hub.

- **Instalación en Fedora 41** utilizando `dnf`:
  - [Documentación oficial de Docker](https://docs.docker.com/)
  - [Documentación oficial de Fedora](https://docs.fedoraproject.org/)
  
- **Configuración de Docker Compose**:
  
  - [Docker Compose para GitLab y Jenkins](https://github.com/docker/awesome-compose)
  
- **Configuración inicial de GitLab**:
  
  - [Guía oficial GitLab](https://docs.gitlab.com/)
  
  
  
  

