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
- [ ] Git-Projekt initialisieren
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
