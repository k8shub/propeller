# Propeller - Basic Library of Helm Based Applications Deployment on Kubernetes

基于Kubernetes平台的应用Helm部署包的公共依赖库。

## TODO

## Application charts/values.yaml template

```
# Default values for app-name.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

labels:
  service: "app-name"
  type: "security"
  group: "group-name"
  env: "prod"
  language: "python"
  org: "organization-name"
  k8s.kuboard.cn/layer: cloud

replicaCount: 1

deploymentType: Deployment

image:
  repository: harbor.local/common/app-name
  pullPolicy: IfNotPresent

imagePullSecrets: 
- name: "harbor-registry-key"

toolboxImage: busybox

nameOverride: ""
fullnameOverride: ""

serviceAccount:
  # Specifies whether a service account should be created
  create: true
  # Annotations to add to the service account
  annotations: {}
  # The name of the service account to use.
  # If not set and create is true, a name is generated using the fullname template
  name: "app-name"
  account: "app-name"

podSecurityContext: {}
  # fsGroup: 2000

podManagementPolicy: OrderedReady

securityContext: {}
  # capabilities:
  #   drop:
  #   - ALL
  # readOnlyRootFilesystem: true
  # runAsNonRoot: true
  # runAsUser: 1000

service:
  type: ClusterIP
  # sessionAffinity loadbalance strategy, default roundrobin, supports None,ClientIP
  sessionAffinity: 
  port: 8042
  # timeout seconds for exported virtual service
  timeout: 60s
  # if container has extra ports, specify extraPorts like [{"port": 80, "name": "http" }]
  extraPorts:
    - port: 8081
      name: http1
      path: biz1      # exported http route: http://host:port/{namespace}/{podname}/biz1
    - port: 8082
      name: http2
      path: biz2
  gateway: app-gateway
  # istio virtual service destination route Headers
  headers:
    response:
      set:
        access-control-allow-origin: "*"
  # optional: mirror to other service
  mirror:
    host: httpbin
    port:
      number: 8000

container:
  port: 8042
  ports:
  - name: http1
    port: 8081
  - name: http2
    port: 8082

livenessProbe:
  httpGet:
    path: /healthz
    port: 8042
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 15
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /healthz
    port: 8042
  initialDelaySeconds: 10
  periodSeconds: 25
  timeoutSeconds: 15
  failureThreshold: 3

initContainers: []

extraContainers: []

resources:
  # We usually recommend not to specify default resources and to leave this as a conscious
  # choice for the user. This also increases chances charts run on environments with little
  # resources, such as Minikube. If you do want to specify resources, uncomment the following
  # lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  requests:
    cpu: 16m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 1Gi

istioProxy:
  # custom requests and limits for istio-proxy container, if empty, it will use default
  # default: requests.cpu: 16m, requests.memory: 24Mi, limits.cpu: "2", limits.memory: 1Gi
  requests:
    cpu: 16m
    memory: 24Mi
  limits:
    cpu: "2"
    memory: 1Gi

# annotations
# do not specify sidecar.istio.io/proxyCPU, sidecar.istio.io/proxyMemory, 
# sidecar.istio.io/proxyCPULimit, sidecar.istio.io/proxyMemoryLimit here.
annotations: {}

nodeSelector: {}

tolerations: []

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
          - key: node-ext-usage
            operator: In
            values:
              - security
              - nginx

lifecycle: {}

configMaps:
- name: config-demo
  mountPath: /etc/config
  data:
    demo-01.yaml: |
      healthzChecks: []
      #- name: http
      #  type: HttpGet
      #  endpoints:
      #  - http://host1:6001/
- name: global-config-assets
  mountPath: /usr/share/nginx/html/prod/configurable/images

storage:
  hostPath: /etc/ssl/private-ca

# format 1: directly specify container mountPath in dataPath field(for single data path mounting requirments), like:
dataPath: /app/app-name/data
# format 2: split multiple data path mounts into array
dataPath:
  # supported format 2.1:
  - /app/app-name/data1
  # supported format 2.2: manually specify mountPath(app container path) and subPath(persistent volumm sub folder)
  - mountPath: /app/app-name/data2
    subPath: data2
  # supported format 2.3: manually specify mountPath(app container path) and hostPath(localhost sub folder)
  - mountPath: /app/app-name/data3
    hostPath: data3

logPath: /app/app-name/log

appInitializement:
  runAsRoot: false
  configFiles:
  - path: /app/app-name/etc
    files:
    - templateFile: app-template.yaml
      file: app.yaml
    # debug: true, dump the generated /app/app-name/etc/app.yaml configure file contents in 
    #   container <app-name>-prepare of pod app-name-<version>-pod_suffix 
    debug: true
  - path: /usr/share/nginx/html
    subPath: index.html
    files:
    - replace:
        src: "window.__sysname__.*$"
        dst: "window.__sysname__ = $APP_SYS_NAME"
      file: index.html
    debug: true
  secrets:
  - secret: database-demo
    type: database
    prefix: DB
  env:
    - name: APP_SYS_NAME
      valueFrom:
        secretKeyRef:
          name: envKeys
          key: APP_SYSNAME
  
env:
- name: TZ
  value: Asia/Shanghai

```

