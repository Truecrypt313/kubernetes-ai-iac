# Kubernetes AI Infrastructure as Code

## Projektziel

Automatisierte Bereitstellung einer lokalen Kubernetes-Infrastruktur mit Terraform, öffentlich erreichbarer Webseite, DNS, HTTPS und Monitoring.

Das Projekt dient als DevOps-Portfolio und demonstriert KI-gestützte Infrastructure as Code.

## Technologie-Stack

| Technologie | Aufgabe |
|---|---|
| Terraform | Infrastruktur als Code |
| Docker / kind | Lokaler Kubernetes-Cluster |
| Helm | Installation von Kubernetes-Anwendungen |
| Nginx | Webserver |
| Traefik | Ingress und Load Balancing |
| Cloudflare Tunnel | Öffentliche Erreichbarkeit |
| Cloudflare DNS | DNS-Verwaltung |
| cert-manager / Let's Encrypt | Automatische TLS-Zertifikate |
| Prometheus Operator / Grafana | Monitoring |
| Git / GitHub | Versionierung und CI |
| Codex / MCP | KI-gestützte Infrastrukturverwaltung |

## Roadmap

- [x] Alte Infrastruktur vollständig entfernen
- [x] Git-Projekt initialisieren
- [x] Kubernetes-Cluster mit Terraform bereitstellen
- [x] Nginx-Webseite mit Deployment und Service bereitstellen
- [x] Traefik installieren
- [x] Cloudflare mit motion1.de verbinden
- [x] Tunnel und DNS über Terraform konfigurieren
- [ ] Origin-HTTPS und automatische Zertifikatsverwaltung einrichten
- [x] Prometheus und Grafana bereitstellen
- [x] Kubernetes MCP in Codex integrieren
- [ ] GitHub Actions für Codevalidierung einrichten
- [ ] Vollständigen Aufbau und Abbau testen

## Aktuelle Architektur

```text
Browser ── HTTPS ──► Cloudflare ── verschlüsselter Tunnel ──► cloudflared in kind
                                                            └─ HTTP ─► Traefik ─► Nginx
```

Cloudflare liefert `https://lab.motion1.de` aus. `cloudflared` baut den Tunnel
aus dem Cluster heraus auf. Traefik leitet intern an die beiden Nginx-Pods
weiter. Prometheus und Grafana sind lokal per Port-Forwarding erreichbar.
Codex liest freigegebene Kubernetes-Ressourcen über einen lokalen MCP-Prozess.
`cluster/` verwaltet kind, `apps/` die Anwendungen und den Cloudflare-Tunnel.

## KI-Workflow

Natürliche Sprache → Terraform-Code → Git Pull Request → Validierung → Terraform Plan → Manuelle Freigabe → Terraform Apply

Codex verwendet einen lokalen Kubernetes-MCP-Server für lesende Cluster-Abfragen.

## Projektregeln

- Möglichst wenig Code, Dateien und Abhängigkeiten.
- Keine unnötigen Abstraktionen oder eigenen Frameworks.
- Ausschließlich etablierte Werkzeuge und Provider.
- Keine kostenpflichtige Cloud-Infrastruktur.
- Feste Provider-, Chart- und Image-Versionen.
- Keine Zugangsdaten, kubeconfigs oder Terraform-State-Dateien in Git.
- Keine öffentlichen Kubernetes-, MCP- oder Monitoring-Schnittstellen.
- Keine Infrastrukturänderungen ohne Freigabe.
- Kleine, nachvollziehbare Git-Commits und Pull Requests.
- Alle Komponenten müssen reproduzierbar bereitgestellt und entfernt werden können.
- Technische Entscheidungen und wichtige Befehle kurz dokumentieren.

## Erfolgskriterien

- Kubernetes-Cluster vollständig aus Terraform-Code erzeugbar.
- Webseite öffentlich über HTTPS erreichbar.
- Monitoring funktionsfähig.
- Infrastruktur durch Code skalierbar.
- KI kann Infrastrukturänderungen vorbereiten und den Cluster analysieren.
- Vollständiger Neuaufbau und Abbau reproduzierbar.

## Umgebung

- Linux Mint
- Terraform 1.17.2
- Docker 29.1.3
- kind 0.33.0
- kubectl 1.37.3
- Helm 4.3.2
- Domain: motion1.de (STRATO)

## Lokaler Kubernetes-Cluster

`cluster/main.tf` beschreibt einen einzelnen kind-Knoten mit dem Namen
`kubernetes-ai-iac`. Der Knoten betreibt die Kubernetes-Steuerung und kann
auch die späteren Anwendungen ausführen. Die Kubernetes-API ist vom Host
aus nur über `127.0.0.1` und einen automatisch gewählten Port erreichbar.

Die Konfiguration verwendet Terraform 1.17.2, den Community-Provider
[`tehcyx/kind` 0.13.0](https://github.com/tehcyx/terraform-provider-kind/tree/v0.13.0)
mit eingebettetem kind 0.33.0 und das
[`kindest/node`-Image für Kubernetes 1.35.8](https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0).
Der Image-Digest fixiert den genauen Inhalt. Die versionierte Datei
`cluster/.terraform.lock.hcl` fixiert die Provider-Auswahl und Prüfsummen.
Änderungen an der Cluster-Konfiguration erfordern beim kind-Provider einen
Neuaufbau und müssen deshalb vor der Ausführung geprüft werden.

Kubernetes 1.35 ist als gemeinsame Basis für den späteren Helm-Provider 3.3.0
(eingebettetes Helm 3.20.2) und cert-manager 1.21.3 vorgesehen.
Quellen: [Helm-Provider](https://github.com/hashicorp/terraform-provider-helm/releases/tag/v3.3.0),
[Helm-Kompatibilität](https://helm.sh/docs/v3/topics/version_skew/),
[cert-manager-Kompatibilität](https://cert-manager.io/docs/releases/).
Für die Cluster-Prüfung wurde kubectl 1.35.8 aus dem separaten Projektcache
verwendet. Das systemweit installierte kubectl 1.37.3 liegt außerhalb der
[unterstützten Versionsabweichung](https://kubernetes.io/releases/version-skew-policy/).

Vom Projektverzeichnis aus prüfen:

```sh
terraform -chdir=cluster init -input=false
terraform -chdir=cluster fmt -check
terraform -chdir=cluster validate
terraform -chdir=cluster plan -input=false -detailed-exitcode
```

Am 27.11.2026 waren Initialisierung, Formatierung und Validierung erfolgreich.
Der gespeicherte Plan enthielt ausschließlich die Erstellung von `kind_cluster.lab`
(Exitcode 2). `terraform apply` mit diesem Plan erstellte genau eine Ressource.
Der Folgeplan meldete keine Änderungen (Exitcode 0).

Die Kubernetes-API meldete unter `/readyz` den Status `ok`. Client und Server
meldeten Version 1.35.8. Der einzige Knoten war `Ready`, alle fünf Namespaces
waren `Active`. Die acht Pods in `kube-system` und der Pod in
`local-path-storage` liefen und waren bereit. Der vollständige Abbau und
Neuaufbau bleibt ein eigener Roadmap-Schritt.

`cluster/kubeconfig` und `cluster/terraform.tfstate` haben Modus `0600`
(nur der Besitzer darf lesen und schreiben). Git ignoriert beide Dateien,
die lokalen Terraform-Daten, gespeicherte Pläne und lokale Geheimnisse.
Der State kann private Cluster-Schlüssel enthalten und muss außerhalb von
Git geschützt aufbewahrt und gesichert werden.

## Nginx und Traefik

`apps/main.tf` verwendet die bestehende Cluster-kubeconfig und einen eigenen
Terraform-State. Der Namespace `web` enthält zwei Nginx-Pods, ihren internen
Service und Traefik. Der Ingress leitet `lab.motion1.de` über Traefik an den
Nginx-Service weiter. Beide Services sind vom Typ `ClusterIP`.

Die App-Konfiguration fixiert die Provider Kubernetes 3.5.0 und Helm 3.3.0,
Nginx 1.30.8 sowie das [offizielle Traefik-Chart 43.0.0](https://github.com/traefik/traefik-helm-chart/releases/tag/v43.0.0)
mit Traefik 3.8.0. Beide Images sind per Digest festgelegt. Das Chart verlangt
Kubernetes ab 1.30. Der vorhandene Cluster mit 1.35.8 liegt außerdem im
unterstützten Bereich des im Helm-Provider eingebetteten Helm 3.20.2.

Vom Projektverzeichnis aus prüfen:

```sh
terraform -chdir=apps init -input=false -lockfile=readonly
terraform -chdir=apps fmt -check
terraform -chdir=apps validate
```

Für den App-Plan sind die unten dokumentierten Cloudflare-Variablen nötig.

Am 27.11.2026 erstellte `terraform apply` mit dem geprüften Plan genau fünf
Ressourcen. Beide Nginx-Pods waren bereit und im Service registriert. Traefik
lief mit einer bereiten Replika. Beide Services waren `ClusterIP` auf Port 80.
Der Ingress leitete `lab.motion1.de` an Nginx. Der lokale HTTP-Test lieferte
Status `200` mit der Nginx-Startseite und `404` für einen anderen Host.
Die Folgepläne für `apps/` und `cluster/` meldeten keine Änderungen.

Für den lokalen Aufruf im ersten Terminal auf die beiden Deployments warten
und Traefik an Port 8080 weiterleiten:

```sh
kubectl_lab="${XDG_CACHE_HOME:-$HOME/.cache}/kubernetes-ai-iac/kubectl/v1.35.8/kubectl"
"$kubectl_lab" --kubeconfig=cluster/kubeconfig -n web rollout status deployment/nginx --timeout=120s
"$kubectl_lab" --kubeconfig=cluster/kubeconfig -n web rollout status deployment/traefik --timeout=120s
"$kubectl_lab" --kubeconfig=cluster/kubeconfig -n web port-forward --address=127.0.0.1 svc/traefik 8080:80
```

Im zweiten Terminal die Nginx-Startseite über den Ingress abrufen:

```sh
curl -fsS -H 'Host: lab.motion1.de' http://127.0.0.1:8080/ | grep -F 'Welcome to nginx!'
```

Der `Host`-Header wählt die Ingress-Regel aus. Der Aufruf verwendet die lokale
IP und funktioniert unabhängig vom öffentlichen DNS. Port-Forwarding mit
`Ctrl+C` beenden.

## Cloudflare DNS

`motion1.de` ist seit dem 27.11.2026 öffentlich an `major.ns.cloudflare.com`
und `maleah.ns.cloudflare.com` delegiert. Beide Nameserver antworten
autoritativ. Cloudflare liefert die Seite unter `https://lab.motion1.de` aus.

## Cloudflare Tunnel

`apps/main.tf` beschreibt einen von Cloudflare verwalteten Tunnel mit dem
[Cloudflare-Provider 5.29.0](https://github.com/cloudflare/terraform-provider-cloudflare/releases/tag/v5.29.0).
Seine einzige öffentliche Route ist `lab.motion1.de`. Sie führt über `cloudflared`
zu `http://traefik.web.svc.cluster.local:80` und über den vorhandenen Ingress
zu Nginx. Andere Hostnamen erhalten HTTP 404. Terraform legt den proxied CNAME
erst an, wenn der Connector bereit ist.

Im Namespace `web` läuft dafür eine Replika von `cloudflared` 2026.11.2 mit
festem Image-Digest. Sie liest den Tunnel-Token aus einem schreibgeschützt
eingebundenen Kubernetes-Secret und baut ausgehende Verbindungen zu Cloudflare
auf. Der Connector benötigt ausgehenden Zugriff auf Port 7844 (UDP für QUIC
oder TCP für HTTP/2). Der interne Weg zu Traefik nutzt zunächst HTTP.
cert-manager und Let's Encrypt folgen in einem eigenen Schritt.

Für den authentifizierten Plan im vorbereiteten Terminal werden diese
Umgebungsvariablen benötigt:

| Variable | Zweck |
|---|---|
| `CLOUDFLARE_API_TOKEN` | API-Token mit `Cloudflare Tunnel Write` im Zielkonto und `DNS Write` für `motion1.de` |
| `TF_VAR_cloudflare_account_id` | Account-ID des Zielkontos |
| `TF_VAR_cloudflare_zone_id` | Zone-ID von `motion1.de` im selben Konto |

Die Werte lokal in der Umgebung setzen, etwa über einen Passwortmanager.
Bei einem Neuaufbau im Cloudflare-Dashboard prüfen, dass die Zone `Active`
ist und `lab.motion1.de` nicht durch einen anderen DNS-Eintrag belegt ist.
Vom Projektverzeichnis aus:

```sh
set +x
umask 077
if test -f apps/terraform.tfstate; then chmod 600 apps/terraform.tfstate; fi
plan_dir=$(mktemp -d "${TMPDIR:-/tmp}/kubernetes-ai-iac-plan.XXXXXXXX")
TF_LOG=OFF terraform -chdir=apps plan -input=false -out="$plan_dir/cloudflare.tfplan"
```

Der API-Token wird direkt aus der Umgebung des Providers gelesen. Der separate
Tunnel-Token kann über die Cloudflare-Datenquelle im State und in späteren
Plänen stehen. Das Secret nutzt `data_wo`, damit die Kubernetes-Ressource den
Token dort nicht zusätzlich ablegt. State, Backups und Pläne sind lokale
Geheimnisdateien und gehören nicht in Git oder in geteilte Ausgaben. State und
Plan im Modus `0600` halten, Pläne nach Gebrauch löschen und für die Prüfung
die normale Terraform-Ausgabe ohne Debug-Logs oder JSON-Export verwenden.

Der authentifizierte Plan und das manuelle Apply vom 27.11.2026 meldeten je
fünf neue Ressourcen, keine Änderungen und keine Löschungen. Bei der
Laufzeitprüfung war `cloudflared` bereit und hatte vier Tunnel-Verbindungen
registriert. Die öffentliche Seite lieferte HTTP/2 200 über Cloudflare mit
gültigem TLS und der Nginx-Startseite „Welcome to nginx!“.

## cert-manager und TLS am Traefik-Origin

Öffentliches HTTPS endet derzeit bei Cloudflare. Der nächste Meilenstein
sichert zusätzlich den internen Hop von `cloudflared` zu Traefik ab.

1. `apps/main.tf` ergänzt den Namespace `cert-manager` und das offizielle
   [cert-manager-Chart v1.21.3](https://cert-manager.io/docs/installation/helm/)
   mit `crds.enabled = true`. Helm 3.20.2 rendert das Chart für Kubernetes
   1.35.8 mit drei Deployments und sechs CRDs. Für die Freigabe im
   vorbereiteten Terminal prüfen, dass der App-Plan nur den Namespace und
   das Helm-Release anlegt. Nach dem Apply auf die CRDs und den Webhook warten.
   Der Kubernetes-Provider braucht die CRDs bereits beim Planen von `Issuer`
   und `Certificate`.
2. In einem Folgeschritt einen `Issuer` und ein `Certificate` für
   `lab.motion1.de` im Namespace `web` ergänzen und
   [DNS-01](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)
   zuerst mit Let's Encrypt Staging prüfen. Dafür einen separaten
   Cloudflare-Token mit `Zone Read` und `DNS Edit` nur für `motion1.de`
   und eine ACME-Kontaktadresse bereithalten. Der Token ist für diesen
   Installationsschritt noch nicht nötig. Später wird er als sensitive
   temporäre Terraform-Variable `TF_VAR_cloudflare_dns01_api_token` an ein
   Kubernetes-Secret in `web` übergeben. Der Issuer referenziert das Secret
   über `apiTokenSecretRef`. Das Staging-Zertifikat dient als Ausstellungsprobe.
3. Nach dem Staging-Test das Produktionszertifikat ausstellen und den
   HTTPS-Entrypoint von Traefik parallel zur bisherigen HTTP-Route aktivieren.
   Das Zertifikat lokal mit
   Port-Forwarding und SNI `lab.motion1.de` prüfen. Erst danach den Tunnel
   auf `https://traefik.web.svc.cluster.local:443` umstellen.
   [`originServerName`](https://developers.cloudflare.com/tunnel/troubleshooting/https-origins/)
   auf `lab.motion1.de` setzen. `cloudflared` verwendet diesen Namen für SNI
   und prüft Hostname und Zertifikatskette. `no_tls_verify` bleibt `false`.
   Zum Abschluss HTTPS öffentlich erneut testen. Die HTTP-Route bleibt bis
   dahin als Rückfallweg verfügbar.

## Lokales Monitoring

`apps/main.tf` verwaltet den Namespace `monitoring` und das Helm-Release
[`kube-prometheus-stack` 94.1.0](https://github.com/prometheus-community/helm-charts/releases/tag/kube-prometheus-stack-94.1.0).
Das Chart verlangt Kubernetes ab 1.25 und wurde mit Helm 3.20.2 für Kubernetes
1.35.8 gerendert. Es bündelt Prometheus, Prometheus Operator, Grafana, Node
Exporter und kube-state-metrics mit versionierten Images. Alertmanager bleibt
deaktiviert.

Prometheus hält Metriken 24 Stunden vor. Prometheus und Grafana verwenden
temporären Speicher. Auf diesem kind-Cluster bleiben die lokalen Metrik-Endpunkte
von etcd, Controller Manager, Scheduler und kube-proxy unangetastet und werden
nicht abgefragt.

Am 27.11.2026 erstellte der geprüfte Terraform-Plan zwei Ressourcen. Alle fünf
Monitoring-Pods waren bereit und liefen ohne Neustarts. Alle sechs Services
im Namespace `monitoring` und die beiden Scrape-Services in `kube-system`
hatten bereite Endpunkte. Prometheus meldete 12 von 12 aktiven Zielen als `up`
und keine Scrape-Fehler. Prometheus und Grafana antworteten über Port-Forwarding
mit HTTP 200. Grafana konnte die 12 `up`-Zeitreihen aus Prometheus abrufen.
Nginx antwortete über Traefik weiterhin mit HTTP 200 für `lab.motion1.de`.
Die Folgepläne für `apps/` und `cluster/` meldeten keine Änderungen.

Auch nach der Tunnel-Bereitstellung waren alle 12 Prometheus-Ziele `up`.

Grafanas Readiness-Prüfung meldete beim Start drei abgelehnte Verbindungen.
Danach war Grafana bereit. Dem Node Exporter fehlen udev-Zusatzdaten im
kind-Knoten. Der `diskstats`-Collector lieferte trotzdem Metriken.

Für den lokalen Zugriff vom Projektverzeichnis aus die Variable in jedem
Terminal setzen und jeweils einen der beiden `port-forward`-Befehle ausführen:

```sh
kubectl_lab="${XDG_CACHE_HOME:-$HOME/.cache}/kubernetes-ai-iac/kubectl/v1.35.8/kubectl"
"$kubectl_lab" --kubeconfig=cluster/kubeconfig -n monitoring port-forward --address=127.0.0.1 svc/monitoring-kube-prometheus-prometheus 9090:9090
"$kubectl_lab" --kubeconfig=cluster/kubeconfig -n monitoring port-forward --address=127.0.0.1 svc/monitoring-grafana 3000:80
```

Prometheus öffnet sich unter `http://127.0.0.1:9090`, Grafana unter
`http://127.0.0.1:3000`. Beide Services sind `ClusterIP` und haben keinen
Ingress. Für die Anmeldung als `admin` lässt sich das vom Chart erzeugte
Kennwort lokal aus dem Kubernetes-Secret lesen:

```sh
"$kubectl_lab" --kubeconfig=cluster/kubeconfig -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 --decode
printf '\n'
```

Helm installiert die Monitoring-CRDs beim ersten Apply. Beim Entfernen des
Releases bleiben die CRDs bis zum vollständigen Cluster-Abbau bestehen.

## Kubernetes MCP in VS Code

Codex startet [`containers/kubernetes-mcp-server` 0.1.3](https://github.com/containers/kubernetes-mcp-server/releases/tag/v0.1.3)
aus `.codex/config.toml` lokal mit `npx` über stdio. Die Server-Konfiguration
`.codex/kubernetes-mcp.toml` bietet vier lesende Werkzeuge an und sperrt
Secrets. Ein geerbter Terraform-MCP-Server ist für dieses Projekt deaktiviert.

Terraform verwaltet den ServiceAccount `web/codex-mcp`, eine gemeinsame ClusterRole
und je ein RoleBinding in `web` und `monitoring`. Die Bindings begrenzen
`get` und `list` für Pods, Services, Events, Deployments, DaemonSets,
StatefulSets und Ingresses auf diese zwei Namespaces. Secrets, Pod-Exec,
Pod-Logs und Änderungen an Workloads sind nicht erlaubt.

Am 27.11.2026 erstellte der geprüfte Plan genau diese vier RBAC-Ressourcen.
`kubectl auth can-i` bestätigte mit dem ServiceAccount 28 erlaubte und 55
verbotene Abfragen. Echte MCP-Aufrufe lasen Pods, Deployments und Services in
`web` und `monitoring`. Secrets und die übrigen fünf Namespaces wurden
abgewiesen. Eine generische Pod-Liste ohne Namespace verwendet `web` aus dem
kubeconfig-Kontext. Der Codex-App-Server konnte die Pods in `web` über MCP lesen.
Die Folgepläne für `apps/` und `cluster/` meldeten keine Änderungen.

Nach der Tunnel-Bereitstellung las Codex über MCP in `web` vier Pods, drei
Deployments, zwei Services und einen Ingress. Eine Secret-Liste wurde
abgewiesen.

Eine separate kubeconfig mit kurzlebigem Token liegt lokal vor. Bei Ablauf
vom Projektverzeichnis aus mit `jq` und dem kubectl aus dem Projektcache
erneuern. Die Admin-kubeconfig wird nur für diesen manuellen Schritt verwendet.
Der MCP-Prozess erhält ausschließlich `cluster/kubeconfig.mcp`.

```sh
(
  set -euo pipefail
  umask 077
  kubectl_lab="${XDG_CACHE_HOME:-$HOME/.cache}/kubernetes-ai-iac/kubectl/v1.35.8/kubectl"
  lab_admin() {
    "$kubectl_lab" --kubeconfig=cluster/kubeconfig --context=kind-kubernetes-ai-iac "$@"
  }
  connection=$(lab_admin config view --minify --flatten -o 'jsonpath-as-json={.clusters[0].cluster}' |
    jq -ce '.[0] | {server, "certificate-authority-data"} | select(.server and ."certificate-authority-data")')
  mcp_tmp=$(mktemp cluster/kubeconfig.mcp.XXXXXX)
  trap 'rm -- "$mcp_tmp"' EXIT
  lab_admin -n web create token codex-mcp --duration=1h |
    jq -Rce --argjson connection "$connection" 'select(length > 0) | {
      apiVersion: "v1", kind: "Config", "current-context": "codex-mcp",
      clusters: [{name: "kind-lab", cluster: $connection}],
      contexts: [{name: "codex-mcp", context: {cluster: "kind-lab", user: "codex-mcp", namespace: "web"}}],
      users: [{name: "codex-mcp", user: {token: .}}]
    }' > "$mcp_tmp"
  mv -- "$mcp_tmp" cluster/kubeconfig.mcp
  trap - EXIT
)
```

Die Datei hat Modus `0600` und wird von Git ignoriert. Das Token gilt eine
Stunde. In VS Code das Projektverzeichnis als vertrauenswürdigen Workspace
öffnen und die Codex-Erweiterung neu starten. `codex mcp list` zeigt im
Projektverzeichnis den lokalen Server `kubernetes` als aktiviert an.

Beispielabfragen im Codex-Chat:

- „Liste über Kubernetes MCP die Pods, Deployments und Services in `web` und
  `monitoring`. Nutze keine Shell.“
- „Prüfe ausschließlich über Kubernetes MCP, ob eine Pod-Liste in `kube-system`
  und eine Secret-Liste in `monitoring` abgewiesen werden. Gib nur das Ergebnis aus.“
