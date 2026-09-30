{{- define "preview.fullname" -}}
{{- .Values.name | trunc 50 | trimSuffix "-" -}}
{{- end -}}

{{- define "preview.labels" -}}
app.kubernetes.io/name: {{ include "preview.fullname" . }}
app.kubernetes.io/managed-by: helm
preview.commit: {{ .Values.commit | quote }}
{{- end -}}

{{- /*
preview.components -> JSON {"items":[...]}: one entry per workload. `components` set (F016, DEC-044):
<fullname trunc 40>-<component>, own image/port/probe/route, resources merged over the defaults, routed
by path prefix. Empty: the legacy single workload from the top-level values, named <fullname>, so a
legacy render stays byte-identical to the pre-F016 chart.
*/ -}}
{{- define "preview.components" -}}
{{- $full := include "preview.fullname" . -}}
{{- $items := list -}}
{{- if .Values.components -}}
{{- range .Values.components -}}
{{- $res := mergeOverwrite (deepCopy $.Values.resources) (.resources | default dict) -}}
{{- $items = append $items (dict "fullname" (printf "%s-%s" ($full | trunc 40 | trimSuffix "-") .name) "image" .image "port" (.port | default 8080) "probePath" (.probePath | default "/") "route" (.route | default "/") "resources" $res "byPath" true) -}}
{{- end -}}
{{- else -}}
{{- $items = append $items (dict "fullname" $full "image" .Values.image "port" .Values.containerPort "probePath" .Values.probePath "route" "/" "resources" .Values.resources "byPath" false) -}}
{{- end -}}
{{- dict "items" $items | toJson -}}
{{- end -}}

{{- define "preview.componentLabels" -}}
app.kubernetes.io/name: {{ .c.fullname }}
app.kubernetes.io/managed-by: helm
preview.commit: {{ .root.Values.commit | quote }}
{{- end -}}
