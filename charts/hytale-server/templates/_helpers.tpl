{{/*
Expand the name of the chart.
*/}}
{{- define "hytale-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Define the namespace where the chart will be installed.
*/}}
{{- define "hytale-server.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "hytale-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "hytale-server.labels" -}}
helm.sh/chart: {{ include "hytale-server.chart" . }}
{{ include "hytale-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "hytale-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hytale-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
