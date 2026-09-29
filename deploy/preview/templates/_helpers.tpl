{{- define "preview.fullname" -}}
{{- .Values.name | trunc 50 | trimSuffix "-" -}}
{{- end -}}

{{- define "preview.labels" -}}
app.kubernetes.io/name: {{ include "preview.fullname" . }}
app.kubernetes.io/managed-by: helm
preview.commit: {{ .Values.commit | quote }}
{{- end -}}
