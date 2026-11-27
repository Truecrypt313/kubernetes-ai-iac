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
- [ ] Cloudflare mit motion1.de verbinden
- [ ] Tunnel und DNS über Terraform konfigurieren
- [ ] HTTPS und automatische Zertifikatsverwaltung einrichten
- [ ] Prometheus und Grafana bereitstellen
- [ ] Terraform MCP und Kubernetes MCP integrieren
- [ ] GitHub Actions für Codevalidierung einrichten
- [ ] Vollständigen Aufbau und Abbau testen

## Zielarchitektur

Die Webseite wird lokal im Kubernetes-Cluster betrieben und über Cloudflare Tunnel unter https://lab.motion1.de veröffentlicht.

Der Cluster und seine Anwendungen werden durch getrennte Terraform-Konfigurationen verwaltet.

## KI-Workflow

Natürliche Sprache → Terraform-Code → Git Pull Request → Validierung → Terraform Plan → Manuelle Freigabe → Terraform Apply

Für die KI-Anbindung werden bestehende Terraform- und Kubernetes-MCP-Server verwendet.

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
terraform -chdir=apps plan -input=false -detailed-exitcode
```

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

Am 27.11.2026 wurden bei STRATO für `motion1.de` die Cloudflare-Nameserver
eingetragen. Bei der Prüfung lieferten die `.de`-Zone und öffentliche Resolver
noch die bisherigen STRATO-Nameserver. Die Cloudflare-Aktivierung steht aus.
Das lokale Monitoring ist davon unabhängig und wird vorgezogen.

## Lokales Monitoring

`apps/main.tf` plant den Namespace `monitoring` und das Helm-Release
[`kube-prometheus-stack` 94.1.0](https://github.com/prometheus-community/helm-charts/releases/tag/kube-prometheus-stack-94.1.0).
Das Chart verlangt Kubernetes ab 1.25 und wurde mit Helm 3.20.2 für Kubernetes
1.35.8 gerendert. Es bündelt Prometheus, Prometheus Operator, Grafana, Node
Exporter und kube-state-metrics mit versionierten Images. Alertmanager bleibt
deaktiviert.

Prometheus hält Metriken 24 Stunden vor. Prometheus und Grafana verwenden
temporären Speicher. Auf diesem kind-Cluster bleiben die lokalen Metrik-Endpunkte
von etcd, Controller Manager, Scheduler und kube-proxy unangetastet und werden
nicht abgefragt. Der App-Plan sieht zwei neue Ressourcen vor und keine
Änderungen an den bestehenden Ressourcen.

Nach dem freigegebenen Apply sind Prometheus und Grafana per Port-Forwarding
erreichbar. Vom Projektverzeichnis aus die Variable in jedem Terminal setzen
und jeweils einen der beiden `port-forward`-Befehle ausführen:

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
