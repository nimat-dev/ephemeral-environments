# PERSONAS — who it's for

## 1. Feature developer
- **Goal**: share a running build of their branch without touching k8s/DNS/TLS.
- **Context**: has repo write access; uses the Actions UI.
- **Job**: "Dispatch `Deploy Preview` with my branch, get a URL in the job summary,
  paste it in the PR."

## 2. Reviewer / QA / stakeholder
- **Goal**: click a stable link and see the branch working.
- **Context**: no cluster access; may hit the link hours later.
- **Job**: "Open the URL; if the preview is asleep, it wakes (short cold-start) and works."

## 3. Platform engineer (owns the cluster)
- **Goal**: previews are safe, bounded, and self-cleaning.
- **Context**: runs Part A bootstrap once; owns RBAC, quotas, ACR retention.
- **Job**: "Previews can't eat the cluster, can't outlive their lifetime, and the pipeline
  holds no long-lived secrets."
