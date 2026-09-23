{{/*
Expand the name of the chart.
*/}}
{{- define "admin-panel.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars (DNS naming spec). If the release name already contains
the chart name it is used as-is.
*/}}
{{- define "admin-panel.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create a DNS-safe name for a component appended to the release fullname.
Pass the root context and component as a list.
*/}}
{{- define "admin-panel.componentName" -}}
{{- $root := index . 0 -}}
{{- $component := index . 1 -}}
{{- $maxBaseLength := sub 62 (len $component) | int -}}
{{- $base := include "admin-panel.fullname" $root | trunc $maxBaseLength | trimSuffix "-" -}}
{{- printf "%s-%s" $base $component -}}
{{- end }}

{{/*
Chart name and version as used by the chart label.
*/}}
{{- define "admin-panel.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "admin-panel.labels" -}}
helm.sh/chart: {{ include "admin-panel.chart" . }}
{{ include "admin-panel.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: admin-panel
{{- end }}

{{/*
Selector labels (stable identity, must not include version).
*/}}
{{- define "admin-panel.selectorLabels" -}}
app.kubernetes.io/name: {{ include "admin-panel.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the service account to use.
*/}}
{{- define "admin-panel.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "admin-panel.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Fully qualified container image reference. A digest takes precedence over the tag.
The tag falls back to the chart appVersion.
*/}}
{{- define "admin-panel.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- $repository := .Values.image.repository -}}
{{- if .Values.image.registry -}}
{{- $repository = printf "%s/%s" .Values.image.registry .Values.image.repository -}}
{{- end -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" $repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" $repository $tag -}}
{{- end -}}
{{- end }}

{{/*
Name of the ConfigMap holding non-secret env.
*/}}
{{- define "admin-panel.configMapName" -}}
{{- include "admin-panel.componentName" (list . "env") -}}
{{- end }}

{{/*
Name of the Secret holding secret env (existingSecret wins).
*/}}
{{- define "admin-panel.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- include "admin-panel.componentName" (list . "env") -}}
{{- end -}}
{{- end }}

{{/*
envFrom block shared by every role. It pulls the full environment from the ConfigMap and Secret.
Usage:  {{- include "admin-panel.envFrom" . | nindent 12 }}
*/}}
{{- define "admin-panel.envFrom" -}}
- configMapRef:
    name: {{ include "admin-panel.configMapName" . }}
- secretRef:
    name: {{ include "admin-panel.secretName" . }}
{{- end }}

{{/*
Name of the shared public-storage PVC (existingClaim wins).
*/}}
{{- define "admin-panel.publicStorageClaimName" -}}
{{- if .Values.persistence.existingClaim -}}
{{- .Values.persistence.existingClaim -}}
{{- else -}}
{{- include "admin-panel.componentName" (list . "public") -}}
{{- end -}}
{{- end }}

{{/*
volumeMounts block shared by app roles (only when persistence is enabled).
Usage:  {{- include "admin-panel.volumeMounts" . | nindent 10 }}
*/}}
{{- define "admin-panel.volumeMounts" -}}
{{- if .Values.persistence.enabled }}
volumeMounts:
  - name: public-storage
    mountPath: {{ .Values.persistence.mountPath | quote }}
{{- end }}
{{- end }}

{{/*
Pod volumes block shared by app roles (only when persistence is enabled).
Usage:  {{- include "admin-panel.volumes" . | nindent 6 }}
*/}}
{{- define "admin-panel.volumes" -}}
{{- if .Values.persistence.enabled }}
volumes:
  - name: public-storage
    persistentVolumeClaim:
      claimName: {{ include "admin-panel.publicStorageClaimName" . }}
{{- end }}
{{- end }}

{{/*
envFrom for the migrate hook Job. It references the hook-managed ConfigMap (and hook
Secret, or the user's existingSecret) so the Job has the CURRENT env at pre-install/
pre-upgrade time, before the runtime ConfigMap/Secret are created/updated.
*/}}
{{- define "admin-panel.migrateEnvFrom" -}}
- configMapRef:
    name: {{ include "admin-panel.componentName" (list . "migrate-env") }}
- secretRef:
    name: {{ if .Values.secrets.existingSecret }}{{ .Values.secrets.existingSecret }}{{ else }}{{ include "admin-panel.componentName" (list . "migrate-env") }}{{ end }}
{{- end }}

{{/*
Pod-template annotations shared by every role: roll pods when env changes, then merge
podAnnotations. Pass the root context.
Usage:  {{- include "admin-panel.podAnnotations" . | nindent 8 }}
*/}}
{{- define "admin-panel.podAnnotations" -}}
# Roll pods when env changes.
checksum/config: {{ include (print $.Template.BasePath "/configmap-env.yaml") . | sha256sum }}
{{- if not .Values.secrets.existingSecret }}
checksum/secret: {{ include (print $.Template.BasePath "/secret-env.yaml") . | sha256sum }}
{{- end }}
{{- with .Values.podAnnotations }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
nodeSelector/tolerations/affinity tail. Pass a role values dict (e.g. .Values.web).
Usage:  {{- with (include "admin-panel.scheduling" .Values.web) }}{{ . | nindent 6 }}{{- end }}
*/}}
{{- define "admin-panel.scheduling" -}}
{{- with .nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
imagePullSecrets block.
*/}}
{{- define "admin-panel.imagePullSecrets" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
ServiceAccount used by the migrate hook Job. When the chart creates the runtime SA, the hook
gets its own hook-managed copy (suffix -migrate) so that its hook-succeeded deletion never
removes the runtime SA the web/worker/scheduler pods mount. Same name as the runtime SA
(user-managed) when serviceAccount.create=false.
*/}}
{{- define "admin-panel.migrateServiceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- include "admin-panel.componentName" (list . "migrate") }}
{{- else }}
{{- include "admin-panel.serviceAccountName" . }}
{{- end }}
{{- end }}
