{{/*
Logpath prefix
*/}}
{{- define "propeller.logpathPrefix" -}}
{{ $.Values.labels.language | default "nolan" }}-{{ $.Release.Namespace }}
{{- end -}}

{{/*
Secrets items expand to env
*/}}
{{- define "propeller.expandSecrets" -}}
{{- $secrets := get . "secrets" }}
{{- $secretsRef := get . "ref" }}
{{- if $secrets }}
{{- range $s := $secrets }}
{{- if $s.secret }}
{{- if and $secretsRef $secretsRef.global.secretKeys }}
{{- $refSecrets := $secretsRef.global.secretKeys }}
{{- $sd := get $refSecrets $s.type }}
{{- if $sd }}
{{- range $sk := $sd }}
- name: {{ $s.prefix | upper }}_{{ $sk | upper }}
  valueFrom:
    secretKeyRef:
      name: {{ $s.secret }}
      key: {{ $sk }}
{{- end }}
{{- end }}
{{- end }}
{{- else if $s.configMap }}
{{- if and $secretsRef $secretsRef.global.configMaps }}
{{- $configMaps := $secretsRef.global.configMaps }}
{{- $cm := get $configMaps $s.configMap }}
{{- if $cm }}
{{- range $ck := $cm }}
- name: {{ $s.prefix | upper }}_{{ $ck | upper }}
  valueFrom:
    configMapKeyRef:
      name: {{ $s.configMap }}
      key: {{ $ck }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Env values expand template
*/}}
{{- define "propeller.expandEnv" -}}
{{- $env := . -}}
{{- range $e := $env -}}
{{- if $e.valueFrom }}
- name: {{ $e.name }}
  valueFrom:
  {{- range $ek, $ev := $e.valueFrom }}
    {{ $ek }}:
      {{- range $esk, $esv := $ev }}
      {{ $esk }}: {{ $esv }}
      {{- end }}
  {{- end }}
{{- else }}
- name: {{ $e.name }}
  value: "{{ $e.value }}"
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Env values expand template
*/}}
{{- define "propeller.checkConnectionBySecrets" -}}
{{- $addresses := "" }}
{{- $secrets := get . "secrets" }}
{{- $secretsRef := get . "ref" }}
{{- $container := get . "container" }}
{{- $toolboxImage := get . "toolboxImage" }}
{{- if $secrets }}
{{- range $s := $secrets }}
{{- if $s.secret }}
{{- $envPrefix := $s.prefix | upper }}
{{- if and $secretsRef $secretsRef.global.secretKeys }}
{{- $refSecrets := $secretsRef.global.secretKeys }}
{{- $sd := get $refSecrets $s.secret }}
{{- if $sd }}
{{- $hasHost := has "host" $sd }}
{{- $hasPort := has "port" $sd }}
{{- if and $hasHost $hasPort }}
{{- $envHost := cat "${" $envPrefix "_HOST}" | replace " " "" }}
{{- $envPort := cat "${" $envPrefix "_PORT}" | replace " " "" }}
{{- $addresses = cat $addresses "if nc -w 1" $envHost $envPort "; then sleep 0; else success=false; ping -c 1" $envHost "; echo 'Checking'" $envHost $envPort "'network failed, retrying in next 5 seconds...'; fi;" }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- if ne $addresses "" }}
- name: {{ $container }}-check-network
  image: {{ $toolboxImage | default "busybox" }}
  imagePullPolicy: IfNotPresent
  command:
  - sh
  - -c
  - "success=false; until ${success}; do success=true; sleep 5;{{ $addresses }} done"
  env:
  {{- range $s := $secrets }}
  {{- if $s.secret }}
  {{- if and $secretsRef $secretsRef.global.secretKeys }}
  {{- $refSecrets := $secretsRef.global.secretKeys }}
  {{- $sd := get $refSecrets $s.secret }}
  {{- if $sd }}
  {{- range $sk := $sd }}
  {{- if or (eq $sk "host") (eq $sk "port") }}
  - name: {{ $s.prefix | upper }}_{{ $sk | upper }}
    valueFrom:
      secretKeyRef:
        name: {{ $s.secret }}
        key: {{ $sk }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- else if $s.configMap }}
  {{- if and $secretsRef $secretsRef.global.configMaps }}
  {{- $configMaps := $secretsRef.global.configMaps }}
  {{- $cm := get $configMaps $s.configMap }}
  {{- if $cm }}
  {{- range $ck := $cm }}
  {{- if or (eq $ck "host") (eq $ck "port") }}
  - name: {{ $s.prefix | upper }}_{{ $ck | upper }}
    valueFrom:
      configMapKeyRef:
        name: {{ $s.configMap }}
        key: {{ $ck }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
VolumeMounts of dataPath
*/}}
{{- define "propeller.dataPathVolumeMounts" -}}
{{- if kindIs "string" .dataPath }}
- name: {{ $.chartName }}-datapath
  mountPath: {{ .dataPath }}
{{- else }}
{{- range $m := .dataPath }}
{{- if $m }}
{{- if kindIs "string" $m }}
- name: {{ $.chartName }}-datapath
  mountPath: {{ $m }}
  subPath: {{ splitList "/" $m | last }}
{{- else }}
- name: {{ $.chartName }}-datapath
  mountPath: {{ $m.mountPath }}
  subPath: {{ $m.subPath }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
App Name
*/}}
{{- define "propeller.appName" -}}
{{- if .Values.canary -}}
{{ .Chart.Name }}-canary
{{- else -}}
{{ .Chart.Name }}
{{- end -}}
{{- end -}}

{{/*
Expand common helm labels
*/}}
{{- define "propeller.helmLabels" }}
helm.sh/chart: "{{ .Chart.Name }}-{{ .Chart.Version }}"
app.kubernetes.io/name: "{{ template "propeller.appName" . }}"
app.kubernetes.io/instance: "{{ .Release.Name }}"
app.kubernetes.io/version: "{{ .Chart.AppVersion }}"
app.kubernetes.io/managed-by: "{{ .Release.Service }}"
{{- end -}}

{{/*
Expand chart name and version labels
*/}}
{{- define "propeller.chartLabels" }}
app: {{ template "propeller.appName" . }}
version: "{{ .Chart.AppVersion }}"
{{- end -}}

{{/*
Expand ConfigMap values depends on match condition
*/}}
{{- define "propeller.expandConfigMapByContainer" }}
{{- $configMaps := get . "configMaps" }}
{{- $containerName := get . "container" }}
{{- $chartName := get . "chartName" }}
{{- range $cm := $configMaps }}
{{- if or (and (eq $containerName $chartName) (or (not $cm.container) (and $cm.container (eq (toString $cm.container) $chartName))) ) (and (ne $containerName $chartName) (and $cm.container (eq (toString $cm.container) $containerName))) }}
{{- if $cm.data }}
{{- range $ckey, $_ := $cm.data }}
- name: {{ $chartName }}-{{ $cm.name }}
  mountPath: {{ $cm.mountPath }}/{{ $ckey }}
  subPath: {{ $ckey }}
{{- end }}
{{- else }}
- name: {{ $chartName }}-{{ $cm.name }}
  mountPath: {{ $cm.mountPath }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Expand logPath VolumeMounts
*/}}
{{- define "propeller.logPathVolumeMount" }}
- name: {{ .Chart.Name }}-logpath
  mountPath: {{ .Values.logPath }}
  subPathExpr: {{ .Values.labels.language | default "nolan" }}-{{ .Release.Namespace }}-$(POD_NAME)
{{- end -}}

{{/*
Expand Extra Containers
*/}}
{{- define "propeller.expandExtraContainers" }}
{{- $prependContainers := get . "prependContainers" }}
{{- $src := get . "src" }}
{{- range $c := $src.Values.extraContainers }}
{{- if or (and $prependContainers $c.holdApplicationUntilContainerStarts) (and (not $prependContainers) (not $c.holdApplicationUntilContainerStarts)) }}
# container of {{ $c.name }}
- name: {{ $c.name }}
  image: {{ $c.image }}
  imagePullPolicy: {{ $src.Values.image.pullPolicy | default "IfNotPresent" }}
  {{- if $c.ports }}
  ports:
  {{- range $port := $c.ports }}
  - containerPort: {{ $port }}
    name: port-{{ $c.name }}
  {{- end }}
  {{- end }}
  {{- if $c.command }}
  command:
  {{- range $arg := $c.command }}
  - "{{ $arg }}"
  {{- end }}
  {{- end }}
  {{- if $src.Values.configMaps }}
  {{- $cmParams := dict "configMaps" $src.Values.configMaps "container" $c.name "chartName" $src.Chart.Name -}}
  {{- $cm := include "propeller.expandConfigMapByContainer" $cmParams }}
  {{- if $cm }}
  volumeMounts:
  {{- $cm | indent 2 }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}
{{- end -}}
