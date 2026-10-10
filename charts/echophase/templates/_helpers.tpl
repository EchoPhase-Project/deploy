{{/*
Expand the name of the chart.
*/}}
{{- define "echophase.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "echophase.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "echophase.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "echophase.labels" -}}
helm.sh/chart: {{ include "echophase.chart" . }}
{{ include "echophase.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "echophase.selectorLabels" -}}
app.kubernetes.io/name: {{ include "echophase.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Image pull policy
*/}}
{{- define "echophase.imagePullPolicy" -}}
{{- .Values.global.imagePullPolicy | default "IfNotPresent" }}
{{- end }}

{{/*
Pull policy of one of our images (pass its .image values): the explicit
pullPolicy if set, else Always for the moving "latest" tag and IfNotPresent
for any other tag (docker:publish pushes an immutable tag per build).
*/}}
{{- define "echophase.appImagePullPolicy" -}}
{{- .pullPolicy | default (ternary "Always" "IfNotPresent" (eq (toString .tag) "latest")) }}
{{- end }}
