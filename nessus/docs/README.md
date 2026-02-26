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

This is a custom integration uploaded via ZIP. It is not available in the public Elastic Package Registry.

### Upload the package

The ZIP archive must contain a top-level directory named `nessus-{version}` (e.g. `nessus-1.4.0`).

**PowerShell:**
```powershell
$v = (Select-String -Path nessus/manifest.yml -Pattern '^version:\s*(.+)$').Matches.Groups[1].Value
Copy-Item -Recurse nessus "nessus-$v"
Compress-Archive -Path "nessus-$v" -DestinationPath nessus.zip -Force
Remove-Item -Recurse -Force "nessus-$v"

curl -sk -u elastic:<password> -X POST "https://<kibana-host>:5601/api/fleet/epm/packages" `
  -H "kbn-xsrf: true" -H "Content-Type: application/zip" --data-binary "@nessus.zip"
```

**Bash:**
```bash
v=$(grep '^version:' nessus/manifest.yml | awk '{print $2}')
cp -r nessus "nessus-$v"
zip -r nessus.zip "nessus-$v"
rm -rf "nessus-$v"

curl -sk -u elastic:<password> -X POST "https://<kibana-host>:5601/api/fleet/epm/packages" \
  -H "kbn-xsrf: true" -H "Content-Type: application/zip" --data-binary @nessus.zip
```

### Add the integration

1. In Kibana, go to **Fleet > Integrations** and search for "Tenable Nessus"
2. Click **Add Tenable Nessus**
3. Configure the following settings:
   - **Nessus URL**: Base URL of your Nessus scanner (e.g., `https://nessus-host:8834`)
   - **API Access Key**: Your Nessus API access key
   - **API Secret Key**: Your Nessus API secret key
   - **SSL Verification Mode**: Defaults to `full`; set to `none` for self-signed certificates
   - **SSL Certificate Authorities**: (Optional) Path(s) to PEM files if using a corporate CA
   - **Proxy URL**: (Optional) HTTP proxy URL if required by your network
4. Save and deploy to your agent policy

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| Nessus URL | `https://localhost:8834` | Base URL of the Nessus scanner |
| API Access Key | — | Nessus API access key (required) |
| API Secret Key | — | Nessus API secret key (required) |
| SSL Verification Mode | `full` | SSL verification: `full`, `certificate`, or `none` |
| SSL Certificate Authorities | — | Paths to custom CA certificate files (PEM). For corporate/private CAs |
| Proxy URL | — | HTTP proxy URL (e.g. `http://proxy:8080`) |
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
| `vulnerability.severity` | CRITICAL / HIGH / MEDIUM / LOW / INFO |
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

## Known Limitations

- **API call volume**: The integration makes O(hosts × vulnerabilities) API calls per scan. Large scans with thousands of hosts and plugins may take a long time. Increase `resource.timeout` (default 300s) if needed.
- **Incremental collection**: The integration tracks the `last_modification_date` of each scan to avoid re-fetching unchanged scans. However, if a scan is re-run with the same scan ID and the same modification timestamp, it will not be re-collected until the timestamp changes.
- **Nessus editions**: Tested with Nessus Professional and Nessus Expert. Nessus Essentials should work but has scan limits that may affect the number of findings collected.
- **Severity mapping**: Nessus severity 0 ("Informational") maps to `INFO` in the ECS `vulnerability.severity` field. The Kibana Findings page may not display INFO-level entries depending on its filters. Set `min_severity` to `1` to exclude them.

## Troubleshooting

### SSL certificate errors

If your Nessus instance uses a self-signed certificate, set **SSL Verification Mode** to `none`:

```
ssl_verification_mode: none
```

For corporate CA-signed certificates, add the CA PEM path to **SSL Certificate Authorities** instead of disabling verification.

### Scans not appearing

Verify that the scan is in `completed` or `imported` status in the Nessus UI. Running, paused, or cancelled scans are not collected.

Also check that the scan's `last_modification_date` is newer than the last successful collection. On the first run, all completed scans are collected.

### Timeout errors

If you see timeout errors in the agent logs, increase the `resource.timeout` value in the integration policy. The default is 300 seconds, but large scans with many hosts/plugins may require more.

### Transform "deferred installations" warning

Fleet creates the Latest Transform as the `kibana_system` user, which lacks the required index privileges. The "Reauthorize" button in Fleet UI does not work for custom (ZIP-uploaded) packages.

**Fix:** Run the post-install script from the project root. It recreates the transform and clears the deferred flag:

```powershell
.\post-install.ps1                  # PowerShell (defaults: localhost, elastic:changeme)
```
```bash
./post-install.sh                   # Bash (defaults: localhost, elastic:changeme)
```

If you prefer to do it manually, recreate the transform as a privileged user (e.g. `elastic`). The transform definition is in `transform_create.json` at the project root:

```bash
ES="https://localhost:9200"
TID="logs-nessus.nessus_vulnerability_latest-default-0.1.0"

curl -sk -u elastic:changeme -X POST "$ES/_transform/$TID/_stop?force=true"
curl -sk -u elastic:changeme -X DELETE "$ES/_transform/$TID"
curl -sk -u elastic:changeme -X PUT "$ES/_transform/$TID" \
  -H "Content-Type: application/json" \
  -d @transform_create.json
curl -sk -u elastic:changeme -X POST "$ES/_transform/$TID/_start"
```

### No data in Security > Findings > Vulnerabilities

Ensure the Latest Transform is running and healthy (**Stack Management > Transforms**). The Findings page reads from the `security_solution-nessus.vulnerability_latest` destination index, not the raw data stream. If the transform has `red` health, follow the steps above to recreate it.

## Logs

### Vulnerability

An example event for `vulnerability` looks as following:

{{event "vulnerability"}}

{{fields "vulnerability"}}
