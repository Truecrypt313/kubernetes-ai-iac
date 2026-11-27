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
- [ ] Kubernetes-Cluster mit Terraform bereitstellen
- [ ] Nginx-Webseite mit Deployment und Service bereitstellen
- [ ] Traefik installieren
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
Vor einem späteren Cluster-Test wird kubectl 1.35.x oder 1.36.x benötigt;
das installierte kubectl 1.37.3 liegt außerhalb der
[unterstützten Versionsabweichung](https://kubernetes.io/releases/version-skew-policy/).

Vom Projektverzeichnis aus prüfen:

```sh
terraform -chdir=cluster init -input=false
terraform -chdir=cluster fmt -check
terraform -chdir=cluster validate
terraform -chdir=cluster plan -input=false -detailed-exitcode
```

Am 27.11.2026 waren Initialisierung, Formatierung, Validierung und Planung
erfolgreich. Der Plan sieht eine neue Ressource vor, keine Änderungen und
keine Löschungen. Exitcode 2 bei `plan -detailed-exitcode` bedeutet einen
erfolgreichen Plan mit vorgesehenen Änderungen.
Der Cluster wurde noch nicht bereitgestellt; der entsprechende Roadmap-Punkt
bleibt offen. Laufzeit und vollständiger Abbau sind noch nicht getestet.

Bei einer späteren freigegebenen Bereitstellung entsteht `cluster/kubeconfig`.
Diese Datei, lokale Terraform-Daten unter `.terraform/`, State-Dateien,
gespeicherte Pläne und lokale Geheimnisse werden durch `.gitignore`
ausgeschlossen. Der State kann private Cluster-Schlüssel enthalten und muss
außerhalb von Git geschützt aufbewahrt und gesichert werden.
