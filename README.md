# Nessus ELK Integration

Elastic Agent integration package for [Tenable Nessus](https://www.tenable.com/products/nessus) vulnerability scanner.

Collects vulnerability data from Nessus scans and displays it in Kibana's **Security > Findings > Vulnerabilities** tab using the Elastic Common Schema (ECS).

## Features

- Collects scan results via Nessus REST API (CEL input)
- Enriches each vulnerability with plugin details (CVE, CVSS, description, solution)
- Maps data to ECS for native Kibana Security integration
- Latest Transform for deduplication and real-time vulnerability state
- Kibana dashboard for vulnerability overview

## Structure

```
nessus/                              # Integration package
├── manifest.yml                     # Package metadata and configuration
├── changelog.yml                    # Version history
├── docs/README.md                   # Documentation shown in Kibana
├── img/nessus-logo.svg              # Package icon
├── _dev/build/build.yml             # Build configuration
├── kibana/dashboard/                # Kibana dashboards
├── data_stream/vulnerability/       # Vulnerability data stream
│   ├── manifest.yml                 # Stream configuration (interval, severity)
│   ├── sample_event.json            # Example document
│   ├── agent/stream/cel.yml.hbs     # CEL program (API collection logic)
│   ├── elasticsearch/ingest_pipeline/default.yml  # Ingest pipeline (ECS mapping)
│   └── fields/                      # Field definitions
└── elasticsearch/transform/         # Latest Transform for Findings page
docker-compose.yml                   # Dev environment (ES, Kibana, Fleet, Nessus)
```

## Quick Start

1. Start the dev environment: `docker compose up -d`
2. Build the package: `Compress-Archive -Path nessus -DestinationPath nessus.zip`
3. Upload to Fleet:
   ```bash
   curl -sk -u elastic:changeme -X POST "https://localhost:5601/api/fleet/epm/packages" \
     -H "kbn-xsrf: true" -H "Content-Type: application/zip" \
     --data-binary @nessus.zip
   ```
4. Add integration to an agent policy with Nessus API credentials
5. Authorize the transform in Fleet > Integrations > Tenable Nessus

## Requirements

- Elastic Stack 8.13+
- Tenable Nessus with API access enabled
- Docker (for development environment)
