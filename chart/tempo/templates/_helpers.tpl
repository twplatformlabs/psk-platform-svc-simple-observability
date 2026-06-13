{{- define "tempo.fullname" -}}
{{- default "tempo" .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "tempo.labels" -}}
app.kubernetes.io/name: tempo
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "tempo.selectorLabels" -}}
app.kubernetes.io/name: tempo
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}


{{- define "tempo.version" -}}
{{- .Values.image.tag | default .Chart.AppVersion -}}
{{- end -}}
