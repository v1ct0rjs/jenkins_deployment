## Implementación de una instancia de SonarQube pública con Ngrok

A continuación, se presenta un **resumen** de cómo configurar Jenkins con SonarQube y Ngrok de forma local, de modo que la instancia de SonarQube sea accesible públicamente, usando **Docker**. Esta documentación complementa la documentación realizada en https://github.com/v1ct0rjs/jenkins_deployment/ añadiendo esta capacidad de inspeccionar el código, automatizando cada vez que se realiza un cambio en el repositorio de GitLab con Jenkins.

---



### 1 Despliege de los contenedores docker-compose.yml y ngrok.yml

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




