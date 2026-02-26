# Tenable Nessus Integration

The Tenable Nessus integration collects vulnerability data from [Tenable Nessus](https://www.tenable.com/products/nessus) scanners and ingests it into Elastic Security's **Findings > Vulnerabilities** tab.

## Overview

This integration connects to the Nessus REST API, retrieves completed scan results with full plugin details (CVE, CVSS scores, descriptions, solutions), and maps them to the Elastic Common Schema (ECS). A Latest Transform ensures that the most recent vulnerability state is always available for the Security Findings page.

## Data Streams

### Vulnerability

The `vulnerability` data stream collects vulnerability findings from Nessus scans. For each vulnerability detected, it fetches detailed plugin information including:

- **CVE identifiers** (when available from the plugin)
- **CVSS v2/v3 scores** (real scores from Nessus, not approximations)
- **Full description** and **synopsis**
- **Solution / remediation guidance**
- **Reference URLs**
- **Plugin publication and modification dates**
- **CWE identifiers**
- **Plugin output** (scan-specific findings)

## Requirements

- **Elastic Stack**: Kibana 8.13.0 or later
- **Tenable Nessus**: Professional, Expert, or Essentials edition with API access enabled
- **API Keys**: Generate at Nessus UI → Settings → My Account → API Keys

## Setup

1. In Kibana, go to **Fleet > Integrations** and search for "Tenable Nessus"
2. Click **Add Tenable Nessus**
3. Configure the following settings:
   - **Nessus URL**: Base URL of your Nessus scanner (e.g., `https://nessus-host:8834`)
   - **API Access Key**: Your Nessus API access key
   - **API Secret Key**: Your Nessus API secret key
   - **SSL Verification Mode**: Set to `none` for self-signed certificates
4. Save and deploy to your agent policy

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| Nessus URL | `https://localhost:8834` | Base URL of the Nessus scanner |
| API Access Key | — | Nessus API access key (required) |
| API Secret Key | — | Nessus API secret key (required) |
| SSL Verification Mode | `none` | SSL verification: `full`, `certificate`, or `none` |
| Collection Interval | `1h` | How often to poll for new scan results |
| Minimum Severity | `0` | Minimum severity level to collect (0=Info, 1=Low, 2=Medium, 3=High, 4=Critical) |

## Viewing Vulnerabilities

After data collection begins, vulnerabilities appear in two places:

1. **Security > Findings > Vulnerabilities** — Integrated view with grouping, filtering, and flyout details
2. **Dashboard > [Nessus] Vulnerability Overview** — Summary dashboard with severity breakdown, categories, and details table

## ECS Field Mapping

| ECS Field | Source |
|-----------|--------|
| `vulnerability.id` | First CVE from plugin, or `nessus-plugin-{id}` |
| `vulnerability.title` | Plugin name |
| `vulnerability.description` | Full plugin description |
| `vulnerability.severity` | CRITICAL / HIGH / MEDIUM / LOW |
| `vulnerability.score.base` | CVSS v3 score (preferred) or CVSS v2 score |
| `vulnerability.score.version` | `3.0` or `2.0` |
| `vulnerability.enumeration` | `CVE` if CVE present, `NESSUS` otherwise |
| `vulnerability.reference` | CVE IDs + `see_also` URLs from plugin |
| `vulnerability.published_date` | Plugin publication date |
| `vulnerability.category` | Plugin family (e.g., "Web Servers") |
| `vulnerability.scanner.vendor` | `Tenable` |
| `vulnerability.scanner.name` | `Nessus` |
| `resource.id` | Host IP address |
| `resource.name` | Hostname |
| `resource.type` | `host` |

## Logs

### Vulnerability

An example event for `vulnerability` looks as following:

{{event "vulnerability"}}

{{fields "vulnerability"}}
