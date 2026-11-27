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
- [x] Automatische Zertifikatsverwaltung und Traefik-HTTPS einrichten
- [x] Cloudflare-Tunnel auf validiertes Origin-HTTPS umstellen
- [x] Prometheus und Grafana bereitstellen
- [x] Kubernetes MCP in Codex integrieren
- [ ] GitHub Actions für Codevalidierung einrichten
- [ ] Vollständigen Aufbau und Abbau testen

## Aktuelle Architektur

```text
Browser ── HTTPS ──► Cloudflare ── verschlüsselter Tunnel ──► cloudflared in kind
                                                            └─ HTTPS:443 ─► Traefik ── HTTP:80 ─► Nginx (2 Pods)
```

Cloudflare liefert `https://lab.motion1.de` aus. `cloudflared` baut den Tunnel
aus dem Cluster heraus auf und verbindet sich per HTTPS mit Traefik. Dabei
prüft es Zertifikatskette, Gültigkeit und Hostname `lab.motion1.de` vollständig.
cert-manager stellt das Let's-Encrypt-Produktionszertifikat per Cloudflare-DNS-01
bereit. Traefik leitet intern per HTTP an die beiden Nginx-Pods weiter.
Prometheus und Grafana sind lokal per Port-Forwarding erreichbar.
Codex liest freigegebene Kubernetes-Ressourcen über einen lokalen MCP-Prozess.
`cluster/` verwaltet kind, `apps/` die Anwendungen und den Cloudflare-Tunnel.
Traefiks interner HTTP-Entrypoint bleibt als manueller Rückfallweg erhalten.

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
zu `https://traefik.web.svc.cluster.local:443` und über den HTTPS-Ingress
zu Nginx. Andere Hostnamen erhalten HTTP 404. Terraform legt den proxied CNAME
erst an, wenn der Connector bereit ist.

Im Namespace `web` läuft dafür eine Replika von `cloudflared` 2026.11.2 mit
festem Image-Digest. Sie liest den Tunnel-Token aus einem schreibgeschützt
eingebundenen Kubernetes-Secret und baut ausgehende Verbindungen zu Cloudflare
auf. Der Connector benötigt ausgehenden Zugriff auf Port 7844 (UDP für QUIC
oder TCP für HTTP/2). Der interne Weg zu Traefik nutzt HTTPS mit
`originServerName = lab.motion1.de` und `noTLSVerify = false`.

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

Nach dem manuellen Apply von PR #10 (`0 added, 1 changed, 0 destroyed`)
bestätigten die Connector-Logs am 27.11.2026 um 18:50 MEZ die Übernahme der
HTTPS-Route mit genau diesen TLS-Einstellungen. Seit dieser Übernahme wurden
keine TLS-Fehler, Fehler oder Warnungen protokolliert, auch nach erneuten
Webseitenaufrufen. `/ready` antwortete mit HTTP 200; die Connector-Metriken
meldeten vier aktive Tunnelverbindungen und null Anfragefehler.
Öffentliches HTTPS und lokales Traefik-HTTPS lieferten jeweils HTTP/2 200,
TLS-Prüfstatus 0 und die Nginx-Startseite. Die interne HTTP-Rückfallroute
lieferte weiterhin HTTP 200.

Bei dieser Abschlussprüfung war der kind-Knoten `Ready`, die API meldete
`/readyz: ok`, alle acht Namespaces waren `Active` und alle 21 Pods liefen
bereit ohne Neustarts. Alle Deployments, DaemonSets und das Prometheus-
StatefulSet erreichten ihre Soll-Replikas. Die elf Services in `web`,
`monitoring` und `cert-manager` waren `ClusterIP` mit bereiten Endpunkten;
Nginx hatte zwei Endpunkte. Beide Issuer und beide Certificates waren `Ready`.
Es lagen keine Kubernetes-Warning-Events vor.

## cert-manager und TLS am Traefik-Origin

Cloudflare terminiert öffentliches HTTPS. Zusätzlich ist der interne Hop
von `cloudflared` zu Traefik mit HTTPS und vollständiger Zertifikatsprüfung
abgesichert. Traefik nutzt dafür das Let's-Encrypt-Produktionszertifikat.

1. `apps/main.tf` verwaltet den Namespace `cert-manager` und das offizielle
   [cert-manager-Chart v1.21.3](https://cert-manager.io/docs/installation/helm/)
   mit `crds.enabled = true`. Nach dem manuellen Apply waren alle drei Pods
   bereit, alle sechs CRDs registriert und der Webhook im Server-Dry-Run
   funktionsfähig. Auf einem neuen Cluster zuerst das Chart installieren und
   auf CRDs und Webhook warten. Der Kubernetes-Provider braucht die CRDs
   bereits beim Planen von `Issuer` und `Certificate`.
2. Im Namespace `web` verwaltet Terraform das Secret `cloudflare-dns01-token`,
   den [Let’s-Encrypt-Staging-Issuer](https://letsencrypt.org/docs/staging-environment/)
   `letsencrypt-staging` und das Certificate `lab-motion1-de-staging`.
   Der Issuer referenziert das Secret über `apiTokenSecretRef` für
   [DNS-01](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/).
   Nach dem manuellen Apply (`3 added, 0 changed, 0 destroyed`) waren Issuer
   und Certificate `Ready`, und der ACME-Order war `valid`. DNS-01 hat damit
   funktioniert. Cert-manager speichert das Staging-Zertifikat im Secret
   `lab-motion1-de-staging-tls` für die Ausstellungsprobe.
3. Für Production verwaltet Terraform den Issuer `letsencrypt-production` und
   das Certificate `lab-motion1-de-production`. Beide Umgebungen nutzen das
   vorhandene DNS-01-Secret und dieselbe ACME-Kontaktadresse. Cert-manager
   verwendet für Production die separaten Secrets
   `letsencrypt-production-account` und `lab-motion1-de-production-tls`.
   Beide Issuer und beide Certificates wurden nach dem manuellen
   Production-Apply als `Ready` bestätigt. Das Produktionszertifikat ist
   bis zum 25.02.2027 gültig.
4. Der HTTPS-Entrypoint und der Ingress `nginx-https` aus PR #9 sind angewendet.
   Am 27.11.2026 lieferten lokales HTTPS über Traefik und öffentliches HTTPS
   über Cloudflare jeweils HTTP/2 200 mit der Nginx-Startseite und ohne
   Zertifikatsfehler. OpenSSL bestätigte die Zertifikatskette und den Hostnamen;
   ein absichtlich falscher Prüfhostname wurde abgewiesen. Die bisherige
   lokale HTTP-Route lieferte weiterhin HTTP 200. Nginx war mit zwei Replikas
   bereit, Traefik und cloudflared jeweils mit einer. Beide Issuer und beide
   Certificates waren `Ready`.
5. PR #10 stellte ausschließlich die Tunnelroute auf
   `https://traefik.web.svc.cluster.local:443` um. Im
   [Cloudflare-Provider 5.29.0](https://github.com/cloudflare/terraform-provider-cloudflare/blob/v5.29.0/docs/resources/zero_trust_tunnel_cloudflared_config.md)
   heißt der Block `origin_request`. `origin_server_name` übernimmt
   `lab.motion1.de` aus dem HTTPS-Ingress und stellt damit auch die
   Terraform-Abhängigkeit zu diesem Ingress her. `no_tls_verify = false`
   lässt die Prüfung von Zertifikatskette, Gültigkeit und Hostname aktiv;
   das öffentliche Let's-Encrypt-Zertifikat benötigt keinen eigenen CA-Pool.
   Siehe [Cloudflare-Origin-Parameter](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/origin-parameters/#tls-settings).
   Initialisierung mit unveränderter Lockdatei, Formatprüfung und Validierung
   waren erfolgreich. Provider-Schema und Terraform-Abhängigkeitsgraph wurden
   ebenfalls geprüft. Alle anderen Terraform-Ressourcen sind unverändert.
   Der authentifizierte Plan im vorbereiteten Terminal enthielt ausschließlich
   die Aktualisierung von `cloudflare_zero_trust_tunnel_cloudflared_config.lab`
   (`0 to add, 1 to change, 0 to destroy`). Nach dem Merge bestätigte das manuelle
   Apply genau diese Änderung. Die anschließende Log-, TLS- und HTTP-Prüfung
   war erfolgreich; der Origin-HTTPS-Schritt ist abgeschlossen.

Der HTTP-Entrypoint auf Port 80 und der HTTP-Ingress `nginx` bleiben unverändert
als Rückfallweg erhalten. Ein Rückwechsel erfolgt bewusst über Terraform:
die Tunnel-`service`-URL wieder auf `http://traefik.web.svc.cluster.local:80`
setzen und `origin_request` entfernen, dann den Plan prüfen und das Apply
freigeben. Bei einem TLS-Fehler gibt es keinen automatischen Rückfall auf HTTP.

Für den authentifizierten App-Plan im vorbereiteten Terminal zusätzlich
zu den [Cloudflare-Variablen für den Tunnel](#cloudflare-tunnel) setzen:

| Variable | Zweck |
|---|---|
| `TF_VAR_cloudflare_dns01_api_token` | Separater Cloudflare-Token mit `Zone Read` und `DNS Edit` nur für `motion1.de` |
| `TF_VAR_acme_email` | Kontaktadresse für das ACME-Konto |

Den DNS-01-Token beim Plan und beim späteren Apply über die Umgebung setzen.
`ephemeral` und `data_wo` halten ihn aus Terraform-State und gespeicherten
Plänen heraus. Für den Plan weiterhin einen geschützten Speicherort und
Modus `0600` verwenden, da andere Werte darin sensibel sein können.
Beim Drehen des DNS-01-Tokens `data_wo_revision` erhöhen.

Die Zustände des Production-Issuers und des Certificates lassen sich so prüfen:

```sh
kubectl_lab="${XDG_CACHE_HOME:-$HOME/.cache}/kubernetes-ai-iac/kubectl/v1.35.8/kubectl"
"$kubectl_lab" --kubeconfig=cluster/kubeconfig -n web wait --for=condition=Ready issuer/letsencrypt-production --timeout=120s
"$kubectl_lab" --kubeconfig=cluster/kubeconfig -n web wait --for=condition=Ready certificate/lab-motion1-de-production --timeout=300s
```

### Lokaler HTTPS-Test für Traefik

Terraform aktiviert zusätzlich `websecure` auf dem internen Traefik-Service
an Port 443. `web` bleibt der Standard-Entrypoint für die bestehende
HTTP-Ingress-Regel. Die neue Ingress-Regel `nginx-https` nutzt ausdrücklich
`websecure`, aktiviert TLS und referenziert `lab-motion1-de-production-tls`.
PR #9 wurde mit `1 to add, 1 to change, 0 to destroy` geplant und anschließend
manuell angewendet. Beide Entrypoints sind verfügbar. Der angewendete
Cloudflare-Tunnel führt seit PR #10 auf HTTPS-Port 443; Port 80 bleibt intern
als Rückfallweg verfügbar.

Im ersten Terminal vom Projektverzeichnis aus:

```sh
kubectl_lab="${XDG_CACHE_HOME:-$HOME/.cache}/kubernetes-ai-iac/kubectl/v1.35.8/kubectl"
"$kubectl_lab" --kubeconfig=cluster/kubeconfig -n web rollout status deployment/traefik --timeout=120s
"$kubectl_lab" --kubeconfig=cluster/kubeconfig -n web port-forward --address=127.0.0.1 svc/traefik 8080:80 8443:443
```

Im zweiten Terminal HTTPS und die bisherige HTTP-Route prüfen:

```sh
curl --noproxy '*' --fail --show-error --include --resolve lab.motion1.de:8443:127.0.0.1 https://lab.motion1.de:8443/
curl --noproxy '*' --fail --show-error --include -H 'Host: lab.motion1.de' http://127.0.0.1:8080/
```

Beide Aufrufe sollen HTTP 200 und die Nginx-Startseite liefern. `--resolve`
verbindet direkt zum lokalen Port und erhält den Namen `lab.motion1.de` für
SNI und Hostname-Prüfung. curl prüft die Zertifikatskette mit dem lokalen
CA-Speicher. Zusätzlich lässt sich der TLS-Handshake separat prüfen:

```sh
openssl s_client -connect 127.0.0.1:8443 -servername lab.motion1.de -verify_hostname lab.motion1.de -verify_return_error -CApath /etc/ssl/certs </dev/null
```

Am 27.11.2026 ergab die Prüfung `Verify return code: 0 (ok)`; curl meldete
bei lokalem und öffentlichem HTTPS jeweils HTTP/2 200 und TLS-Prüfstatus 0.
Für den öffentlichen Test `curl --fail --show-error --include https://lab.motion1.de/`
verwenden. Port-Forwarding mit `Ctrl+C` beenden.

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

Nach der Origin-HTTPS-Umstellung am 27.11.2026 waren weiterhin alle zwölf
Scrape-Targets `up` ohne Scrape-Fehler. Prometheus-Readiness und die Oberfläche
(nach regulärer Weiterleitung von `/graph`) antworteten mit HTTP 200.
Grafanas `/login` und `/api/health` lieferten HTTP 200; die Datenbank meldete
`ok`. Beide Dienste wurden über temporäres, an `127.0.0.1` gebundenes
Port-Forwarding geprüft; die Weiterleitungen wurden danach beendet.
Prometheus meldete die aktiven Alerts `Watchdog` und
`PrometheusNotConnectedToAlertmanagers`. Alertmanager ist bewusst deaktiviert;
die bestehende Konfiguration wurde bei dieser Prüfung nicht verändert.

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

Bei der Abschlussprüfung nach PR #10 am 27.11.2026 war der kurzlebige Token
abgelaufen. Er wurde für denselben ServiceAccount mit einer Stunde Laufzeit
erneuert; die lokale kubeconfig blieb im Modus `0600` und von Git ausgeschlossen.
Anschließend lasen echte MCP-Tool-Aufrufe erfolgreich Pods, Deployments und
Services in `web` und `monitoring`. Secret-Abfragen und Pods in `kube-system`
wurden abgewiesen. `kubectl auth can-i` mit der MCP-kubeconfig bestätigte
zusätzlich die Sperren für Secrets, Pod-Exec, Erstellen, Ändern und Löschen
sowie Zugriffe auf `cert-manager`. Die RBAC-Konfiguration blieb unverändert.

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

## Portfolio documentation and screenshot review

[Back to the English portfolio overview](../README.md).

The original technical README above is retained in German, including the local
verification updates made after PR #10. Run all commands from the repository
root; paths in command examples are relative to that directory.

Before publication, all six supplied screenshots were inspected visually and
checked for embedded PNG text and EXIF metadata: `grafana-cluster.png`,
`grafana-node.png`, `grafana-workloads.png`, `cloudflare.png`, `website.png` and
`kubernetes-mcp.png`. No API tokens, passwords, private keys, account IDs or
session credentials were found. The Node Exporter view includes a private
Docker network address; other visible identifiers are lab resource names and
the public project domain. Image metadata contains only DPI information. The
screenshots are retained unchanged and represent captured lab observations,
not performance benchmarks or availability guarantees.
