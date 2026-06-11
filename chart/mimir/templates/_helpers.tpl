{{- define "mimir.fullname" -}}
{{- default "mimir" .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mimir.labels" -}}
app.kubernetes.io/name: {{ include "mimir.fullname" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "mimir.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mimir.fullname" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

{{- define "mimir.version" -}}
{{- .Values.image.tag | default .Chart.AppVersion -}}
{{- end -}}
