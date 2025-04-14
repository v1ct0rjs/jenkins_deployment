# Implementación de una instancia de SonarQube pública con Ngrok

A continuación, se presenta un **resumen** de cómo configurar Jenkins con SonarQube y Ngrok de forma local, de modo que la instancia de SonarQube sea accesible públicamente, usando **Docker**. Esta documentación complementa la documentación realizada en https://github.com/v1ct0rjs/jenkins_deployment/ añadiendo esta capacidad de inspeccionar el código, automatizando cada vez que se realiza un cambio en el repositorio de GitLab con Jenkins.

---



## Índice

1. **Implementación de una instancia de SonarQube pública con Ngrok**  
   - Resumen de configuración  
   - Integración con Jenkins y GitLab  

2. **Parte 1: Despliegue de los contenedores docker-compose.yml y ngrok.yml**  
   - **docker-compose.yml**  
     - Servicio `sonarqube-custom`  
     - Servicio `ngrok-sonarqube`  
     - Definición adicional en docker-compose  
   - **ngrok.yml**  
     - Token de autenticación  
     - Dirección web de administración Ngrok  
     - Túneles configurados (SonarQube, Jenkins, GitLab)  
   - ¿Qué hace en conjunto esta configuración?  

3. **Parte 2: Integrar SonarQube en Jenkins (Docker) con Ngrok**  
   - Instalar el plugin **SonarQube Scanner for Jenkins**  
   - Generar token de autenticación en SonarQube  
   - Configurar el servicio SonarQube en Jenkins  
   - Uso de `withSonarQubeEnv('MySonarQube')` en el Pipeline  
   - Configurar la herramienta **SonarQube Scanner**  
   - Ejecución del análisis SonarQube desde el Pipeline  
   - Verificación de resultados en SonarQube 



---

## Parte 1 Despliege de los contenedores docker-compose.yml y ngrok.yml

Estos dos archivos configuran un entorno de contenedores Docker usando `docker-compose.yml` junto con una configuración específica para `ngrok` definida en `ngrok.yml`. 

------

#### **docker-compose.yml**

Este archivo de Docker Compose define dos servicios principales que se ejecutan en contenedores:

```yaml
version: "3.8"
services:
  sonarqube-custom:
    image: sonarqube:community
    container_name: sonarqube-custom
    ports:
      - "9000:9000"  #Se puede cambiar el puerto de destino es necesario para que no haya un conflicto de puertos
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_logs:/opt/sonarqube/logs
      - sonarqube_extensions:/opt/sonarqube/extensions
    networks:
      - ci-network

  ngrok-sonarqube:
    image: ngrok/ngrok:latest
    container_name: ngrok-sonarqube
    networks:
      - ci-network
    volumes:
      - ./ngrok.yml:/etc/ngrok.yml
    ports:
      - "8085:8085" #Se cambia el puerto por defecto para el contenedor de Ngrok del 8080 al 8085, para evitar comflictos con el contenedor de jenkins
    command: >
      start --all --config /etc/ngrok.yml

volumes:
  sonarqube_data:
  sonarqube_logs:
  sonarqube_extensions:

networks:
  ci-network:

```



#### 1. **Servicio `sonarqube-custom`**

- **Imagen utilizada:**
   `sonarqube:community`
   Utiliza la versión comunitaria de SonarQube, que permite análisis estático y calidad del código fuente.

- **Container Name:**
   `sonarqube-custom`
   Nombre personalizado del contenedor.

- **Puerto expuesto:**
   `9000:9000`
   SonarQube es accesible localmente a través del puerto `9000`. Puedes cambiar el puerto izquierdo (host) si existe conflicto en tu máquina local.

- **Volúmenes persistentes:**

  ```yaml
  - sonarqube_data:/opt/sonarqube/data
  - sonarqube_logs:/opt/sonarqube/logs
  - sonarqube_extensions:/opt/sonarqube/extensions
  ```

  Esto asegura que los datos, registros y extensiones de SonarQube persistan después de detener y reiniciar el contenedor.

- **Red:**

  ```yaml
  - ci-network
  ```

  SonarQube estará dentro de la red Docker personalizada llamada `ci-network`.

------

#### 2. **Servicio `ngrok-sonarqube`**

- **Imagen utilizada:**
   `ngrok/ngrok:latest`
   Permite exponer localmente aplicaciones en internet mediante túneles temporales.

- **Container Name:**
   `ngrok-sonarqube`

- **Puerto expuesto:**
   `8085:8085`
   El panel web de Ngrok será accesible localmente en el puerto `8085`. Normalmente, ngrok usa `8080`, pero aquí lo cambiaron a `8085` para evitar conflictos con otros servicios (como Jenkins).

- **Volumen montado (archivo de configuración):**

  ```yaml
  ./ngrok.yml:/etc/ngrok.yml
  ```

  Monta localmente tu archivo `ngrok.yml` dentro del contenedor para configurar los túneles.

- **Comando ejecutado:**

  ```bash
  start --all --config /etc/ngrok.yml
  ```

  Inicia todos los túneles especificados en tu archivo `ngrok.yml`.

- **Red:**

  ```yaml
  - ci-network
  ```

  Conecta este contenedor también a la misma red que SonarQube, permitiendo acceso interno entre ambos servicios.

------

#### Definición adicional en docker-compose:

- **Volúmenes persistentes:**

  ```yaml
  volumes:
    sonarqube_data:
    sonarqube_logs:
    sonarqube_extensions:
  ```

  Docker administra estos volúmenes automáticamente.

- **Red personalizada:**

  ```yaml
  networks:
    ci-network:
  ```

  Los servicios definidos comparten esta red interna personalizada.

------

### **ngrok.yml**

Este archivo configura cómo Ngrok creará túneles hacia tus contenedores internos, exponiéndolos públicamente por internet:

```yaml
version: 2
authtoken: #aqui debes añadir el token que genera ngrok, lo puedes ver accedieno a tu cuenta en https://ngrok.com/
web_addr: 0.0.0.0:8085
tunnels:
  sonarqube:
    proto: http
    addr: sonarqube-custom:9000

  jenkins:
    proto: http
    addr: jenkins:8080

  gitlab:
    proto: http
    addr: gitlab
```



- **Token de autenticación:**

  ```yaml
  authtoken: TU_TOKEN_GENERADO_EN_
  ￼
  Navegador Web <--HTTP--> ngrok (expuesto en internet) <--HTTP--> SonarQube (contenedor interno en Docker)NGROK
  ```

  Aquí debes colocar tu token personal de ngrok, obtenido al registrarte en [ngrok.com](https://ngrok.com/).

- **Dirección web de administración Ngrok:**

  ```yaml
  web_addr: 0.0.0.0:8085
  ```

  El dashboard administrativo de Ngrok estará disponible en todas las interfaces del contenedor en el puerto `8085`.

- **Túneles configurados:**

  ```yaml
  tunnels:
    sonarqube:
      proto: http
      addr: sonarqube-custom:9000
  
    jenkins:
      proto: http
      addr: jenkins:8080
  
    gitlab:
      proto: http
      addr: gitlab
  ```

  Cada uno de estos túneles permite exponer públicamente un contenedor interno:

  - **SonarQube**: disponible en internet vía HTTP (puerto 9000).
  - **Jenkins**: disponible vía HTTP (en el contenedor llamado `jenkins` en puerto 8080).
  - **GitLab**: disponible vía HTTP en el contenedor llamado `gitlab`.

  *(Nota: Jenkins y GitLab se mencionan aquí, pero no aparecen en el `docker-compose.yml. Deben estar definidos por separado en otro archivo Docker Compose como se explica en https://github.com/v1ct0rjs/jenkins_deployment.)*

------

### **¿Qué hace en conjunto esta configuración?**

Con ambos archivos en funcionamiento simultáneo:

1. **SonarQube** ejecuta un servidor interno en un contenedor Docker.
2. **Ngrok** expone SonarQube públicamente en internet mediante un túnel HTTP generado automáticamente. Esto facilita que equipos remotos puedan acceder a tu instancia de SonarQube sin exponer directamente el puerto de tu máquina local al internet público.

Además, la configuración está preparada para integrar fácilmente otros servicios como Jenkins y GitLab, formando así parte de un pipeline de integración continua o desarrollo ágil.

## Parte 2: Integrar SonarQube en Jenkins (Docker) con Ngrok

#### 1. Instalar el plugin **SonarQube Scanner for Jenkins**

Primero, asegúrate de que Jenkins tenga instalado el plugin **SonarQube Scanner for Jenkins**:

- Accede a **Manage Jenkins** > **Manage Plugins**.
- En la pestaña **Available**, busca **SonarQube Scanner for Jenkins**.
- Selecciónalo y haz clic en **Install without restart**.
- Una vez instalado, reinicia Jenkins si es necesario.

Este plugin permite que Jenkins se comunique con SonarQube y ejecute análisis de código.

![image-20250414135636205](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/SonaQube/img/image-20250414135636205.png)

#### 2. Generar un token de autenticación en SonarQube

Para que Jenkins pueda autenticarse con SonarQube, necesitas un token:

- Accede a la interfaz web de SonarQube (por defecto en `http://localhost:9000`).

- Inicia sesión con tus credenciales (por defecto, usuario: `admin`, contraseña: `admin`).

- Despues de acceder te permite cambiar la contraseña.

- Ve a **My Account** > **Security**.

- En la sección **Tokens**, ingresa un nombre (por ejemplo, `jenkins-token`) y haz clic en **Generate**.

- Copia el token generado y guárdalo en un lugar seguro; lo necesitarás más adelante.

  ![image-20250414135756270](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/SonaQube/img/image-20250414135756270.png)

#### 3. Configurar el servicio SonarQube en Jenkins

- En Jenkins, ve a **Manage Jenkins** > **Configure System**.

- Busca la sección **SonarQube servers** y haz clic en **Add SonarQube**.

- Completa los campos:

  - **Name**: un nombre identificador (por ejemplo, `MySonarQube`).
  - **Server URL**: la URL pública generada por Ngrok.
  - **Server authentication token**: haz clic en **Add**, selecciona **Secret text**, pega el token generado en SonarQube, asigna un ID (por ejemplo, `SonarQubeToken`) y guárdalo.

- Marca la casilla **Enable injection of SonarQube server configuration as build environment variables**.

- Haz clic en **Save** para guardar la configuración.

  ![image-20250414140207006](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/SonaQube/img/image-20250414140207006.png)

#### 4. Usar `withSonarQubeEnv('MySonarQube')` en el Pipeline

En tu pipeline de Jenkins, utiliza el bloque `withSonarQubeEnv('MySonarQube')` para ejecutar el análisis de SonarQube:

```groovy
pipeline {
    agent any

    environment {
        GIT_CREDENTIALS = 'gitlab-pat'
        DOCKER_CREDS    = credentials('dockerhub-creds')
        SONAR_SCANNER_HOME = tool name: 'SonarQubeScanner'
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
                    DOCKERHUB_USER="$DOCKER_CREDS_USR" \
                    DOCKERHUB_PASS="$DOCKER_CREDS_PSW" \
                    ./dockerhub_push.sh
                '''
            }
        }

        stage('Verify Images') {
            steps {
                sh "docker images | grep '${env.DOCKER_CREDS_USR}'"
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('MySonarQube') {
                    sh """
                        ${SONAR_SCANNER_HOME}/bin/sonar-scanner \
                          -Dsonar.projectKey=demo_project \
                          -Dsonar.sources=.
                    """
                }
            }
        }

        stage('Quality Gate') {
            steps {
                waitForQualityGate abortPipeline: true
            }
        }
    }
}
```

Debes asegurarte de que el nombre `'MySonarQube'` coincida exactamente con el nombre que configuraste en el paso anterior.

#### 5. Configurar la herramienta **SonarQube Scanner** en Jenkins

Para ejecutar el análisis, necesitas configurar el SonarQube Scanner en Jenkins:

- Ve a **Manage Jenkins** > **Tools**.

- Busca la sección **SonarQube Scanner** y haz clic en **Add SonarQube Scanner**.

- Completa los campos:

  - **Name**: un nombre identificador (por ejemplo, `SonarQubeScanner`).
  - Marca la casilla **Install automatically** y selecciona la versión más reciente del scanner.

- Haz clic en **Save** para guardar la configuración.

  ![image-20250414140519429](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/SonaQube/img/image-20250414140519429.png)

#### 6. Ejecutar el análisis SonarQube desde el Pipeline

Con todo configurado, puedes ejecutar el análisis desde tu prollecto de Jenkins:

![image-20250414140732993](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/SonaQube/img/image-20250414140732993.png)

Como podemos observar se realiza el comprobación del código cuando se realiza un cambio en el respositorio de GitLab que habiamos automatizado anteriormente.

Podemos acceder a la instancia de SonarQube para poder ver que la comprobacion se realizó con exito

![image-20250414140917599](https://github.com/v1ct0rjs/jenkins_deployment/blob/main/SonaQube/img/image-20250414140917599.png)