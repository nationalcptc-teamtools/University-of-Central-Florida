#!/usr/bin/env python3
"""
nmap2html.py - Complete nmap XML to HTML pipeline

Workflow: scan.xml -> fix XML -> parse -> markdown -> HTML

Handles:
- Broken XML from --append-output (multiple nmaprun blocks)
- Comprehensive host/port/script extraction
- Clean HTML report generation

Usage:
    python nmap2html.py scan.xml                    # -> scan.html
    python nmap2html.py scan.xml -o report.html     # custom output
    python nmap2html.py scan.xml --format md        # markdown only
    python nmap2html.py scan.xml --format csv       # CSV output
"""

import sys
import re
import argparse
from xml.etree import ElementTree as ET
from dataclasses import dataclass, field
from typing import Optional
from pathlib import Path
from io import StringIO


# =============================================================================
# XML Fixer - handles --append-output broken XML
# =============================================================================

def fix_nmap_xml(content: str) -> ET.Element:
    """
    Fix and merge multiple nmaprun blocks into single valid XML tree.
    Returns the root Element directly (no temp files needed).
    """
    # Check if it's already valid single-block XML
    try:
        root = ET.fromstring(content)
        if root.tag == 'nmaprun':
            return root
    except ET.ParseError:
        pass  # Need to fix it
    
    # Find all complete nmaprun blocks
    nmaprun_pattern = r'<nmaprun[^>]*>.*?</nmaprun>'
    matches = list(re.finditer(nmaprun_pattern, content, re.DOTALL))
    
    if not matches:
        raise ValueError("No valid nmaprun blocks found in XML")
    
    root = None
    all_hosts = []
    
    for i, match in enumerate(matches):
        xml_block = match.group(0)
        
        try:
            current_root = ET.fromstring(xml_block)
            
            if i == 0:
                root = current_root
                for host in current_root.findall('host'):
                    all_hosts.append(host)
                for host in list(root.findall('host')):
                    root.remove(host)
            else:
                for host in current_root.findall('host'):
                    all_hosts.append(host)
                    
        except ET.ParseError as e:
            print(f"[!] Warning: Could not parse block {i+1}: {e}", file=sys.stderr)
            continue
    
    if root is None:
        raise ValueError("Could not parse any nmaprun blocks")
    
    # Reinsert hosts before runstats
    runstats = root.find('runstats')
    if runstats is not None:
        insert_position = list(root).index(runstats)
        for i, host in enumerate(all_hosts):
            root.insert(insert_position + i, host)
    else:
        for host in all_hosts:
            root.append(host)
    
    # Update host count
    if runstats is not None:
        hosts_elem = runstats.find('.//hosts')
        if hosts_elem is not None:
            hosts_elem.set('up', str(len(all_hosts)))
            hosts_elem.set('total', str(len(all_hosts)))
    
    return root


# =============================================================================
# Data Classes
# =============================================================================

@dataclass
class PortInfo:
    port: int
    protocol: str
    state: str
    service: str = ""
    product: str = ""
    version: str = ""
    extrainfo: str = ""
    ostype: str = ""
    tunnel: str = ""
    cpe: list = field(default_factory=list)
    scripts: dict = field(default_factory=dict)


@dataclass
class HostInfo:
    ip: str
    hostnames: list = field(default_factory=list)
    os_match: str = ""
    os_accuracy: str = ""
    os_family: str = ""
    uptime: str = ""
    last_boot: str = ""
    ports: list = field(default_factory=list)
    mac: str = ""
    vendor: str = ""
    distance: str = ""


# =============================================================================
# Script Extractors
# =============================================================================

def extract_hostname_from_scripts(port_elem) -> list:
    """Extract hostnames from various NSE scripts."""
    hostnames = []
    
    for script in port_elem.findall(".//script"):
        script_id = script.get("id", "")
        
        # RDP NTLM Info
        if script_id == "rdp-ntlm-info":
            for elem in script.findall(".//elem"):
                key = elem.get("key", "")
                if key in ["DNS_Computer_Name", "NetBIOS_Computer_Name", "DNS_Domain_Name"]:
                    if elem.text and elem.text not in hostnames:
                        hostnames.append(elem.text)
        
        # SSL Certificate
        elif script_id == "ssl-cert":
            for table in script.findall(".//table[@key='subject']"):
                for elem in table.findall("elem[@key='commonName']"):
                    if elem.text and elem.text not in hostnames:
                        cn = elem.text
                        if cn.startswith("*."):
                            cn = cn[2:]
                        if cn not in hostnames:
                            hostnames.append(cn)
            # SAN
            for table in script.findall(".//table[@key='extensions']"):
                for ext_table in table.findall("table"):
                    name_elem = ext_table.find("elem[@key='name']")
                    if name_elem is not None and "Subject Alternative Name" in (name_elem.text or ""):
                        value_elem = ext_table.find("elem[@key='value']")
                        if value_elem is not None and value_elem.text:
                            for part in value_elem.text.split(","):
                                part = part.strip()
                                if part.startswith("DNS:"):
                                    dns = part[4:].strip()
                                    if dns.startswith("*."):
                                        dns = dns[2:]
                                    if dns and dns not in hostnames:
                                        hostnames.append(dns)
        
        # SMB OS Discovery
        elif script_id == "smb-os-discovery":
            for elem in script.findall(".//elem"):
                key = elem.get("key", "")
                if key in ["fqdn", "computer", "server"]:
                    if elem.text and elem.text not in hostnames:
                        hostnames.append(elem.text)
        
        # NetBIOS
        elif script_id == "nbstat":
            output = script.get("output", "")
            for line in output.split("\n"):
                if "<00>" in line or "NetBIOS" in line:
                    parts = line.split()
                    if parts:
                        name = parts[0].strip()
                        if name and name not in hostnames and not name.startswith("_"):
                            hostnames.append(name)
    
    return hostnames


def extract_script_info(port_elem) -> dict:
    """Extract relevant script output as key-value pairs."""
    scripts = {}
    
    for script in port_elem.findall("script"):
        script_id = script.get("id", "")
        
        if script_id == "http-title":
            title_elem = script.find("elem[@key='title']")
            if title_elem is not None and title_elem.text:
                scripts["http_title"] = title_elem.text
            elif script.get("output"):
                output = script.get("output", "").strip()
                if not output.startswith("Site doesn't have"):
                    scripts["http_title"] = output
        
        elif script_id == "http-server-header":
            for elem in script.findall("elem"):
                if elem.text:
                    scripts["server_header"] = elem.text
                    break
        
        elif script_id == "http-generator":
            scripts["generator"] = script.get("output", "").strip()
        
        elif script_id == "http-robots.txt":
            output = script.get("output", "").strip()
            if "disallowed" in output.lower():
                scripts["robots"] = output.split("\n")[0]
        
        elif script_id == "http-methods":
            risky = script.find(".//table[@key='Potentially risky methods']")
            if risky is not None:
                methods = [e.text for e in risky.findall("elem") if e.text]
                if methods:
                    scripts["risky_methods"] = ", ".join(methods)
        
        elif script_id == "rdp-ntlm-info":
            for elem in script.findall(".//elem"):
                key = elem.get("key", "")
                if key == "Product_Version" and elem.text:
                    scripts["windows_version"] = elem.text
                elif key == "DNS_Domain_Name" and elem.text:
                    scripts["domain"] = elem.text
        
        elif script_id == "ssl-cert":
            for table in script.findall(".//table[@key='subject']"):
                cn = table.find("elem[@key='commonName']")
                if cn is not None and cn.text:
                    scripts["ssl_cn"] = cn.text
            validity = script.find(".//table[@key='validity']")
            if validity is not None:
                not_after = validity.find("elem[@key='notAfter']")
                if not_after is not None and not_after.text:
                    scripts["ssl_expires"] = not_after.text
        
        elif script_id == "ssh-hostkey":
            key_types = []
            for table in script.findall("table"):
                key_type = table.find("elem[@key='type']")
                if key_type is not None and key_type.text:
                    key_types.append(key_type.text)
            if key_types:
                scripts["ssh_keys"] = ", ".join(key_types)
        
        elif script_id == "rpcinfo":
            services = []
            for key in ["100003", "100005"]:
                if script.find(f".//table[@key='{key}']") is not None:
                    if key == "100003":
                        services.append("nfs")
                    elif key == "100005":
                        services.append("mountd")
            if services:
                scripts["rpc_services"] = ", ".join(services)
    
    return scripts


# =============================================================================
# XML Parser
# =============================================================================

def parse_nmap_xml(root: ET.Element) -> list:
    """Parse nmap XML element tree and return list of HostInfo objects."""
    hosts = []
    
    for host_elem in root.findall("host"):
        status = host_elem.find("status")
        if status is not None and status.get("state") != "up":
            continue
        
        addr_elem = host_elem.find("address[@addrtype='ipv4']")
        if addr_elem is None:
            addr_elem = host_elem.find("address[@addrtype='ipv6']")
        if addr_elem is None:
            continue
        
        host = HostInfo(ip=addr_elem.get("addr", ""))
        
        # MAC address
        mac_elem = host_elem.find("address[@addrtype='mac']")
        if mac_elem is not None:
            host.mac = mac_elem.get("addr", "")
            host.vendor = mac_elem.get("vendor", "")
        
        # Hostnames from nmap
        for hostname in host_elem.findall(".//hostnames/hostname"):
            name = hostname.get("name", "")
            if name and name not in host.hostnames:
                host.hostnames.append(name)
        
        # OS Detection
        os_match = host_elem.find(".//osmatch")
        if os_match is not None:
            host.os_match = os_match.get("name", "")
            host.os_accuracy = os_match.get("accuracy", "")
            os_class = os_match.find("osclass")
            if os_class is not None:
                host.os_family = os_class.get("osfamily", "")
        
        # Uptime
        uptime_elem = host_elem.find("uptime")
        if uptime_elem is not None:
            host.uptime = uptime_elem.get("seconds", "")
            host.last_boot = uptime_elem.get("lastboot", "")
        
        # Distance
        distance_elem = host_elem.find("distance")
        if distance_elem is not None:
            host.distance = distance_elem.get("value", "")
        
        # Ports
        for port_elem in host_elem.findall(".//port"):
            state_elem = port_elem.find("state")
            if state_elem is None or state_elem.get("state") != "open":
                continue
            
            port = PortInfo(
                port=int(port_elem.get("portid", 0)),
                protocol=port_elem.get("protocol", ""),
                state=state_elem.get("state", "")
            )
            
            service_elem = port_elem.find("service")
            if service_elem is not None:
                port.service = service_elem.get("name", "")
                port.product = service_elem.get("product", "")
                port.version = service_elem.get("version", "")
                port.extrainfo = service_elem.get("extrainfo", "")
                port.ostype = service_elem.get("ostype", "")
                port.tunnel = service_elem.get("tunnel", "")
                
                for cpe_elem in service_elem.findall("cpe"):
                    if cpe_elem.text:
                        port.cpe.append(cpe_elem.text)
            
            # Extract hostnames from scripts
            script_hostnames = extract_hostname_from_scripts(port_elem)
            for hn in script_hostnames:
                if hn not in host.hostnames:
                    host.hostnames.append(hn)
            
            # Extract script info
            port.scripts = extract_script_info(port_elem)
            
            host.ports.append(port)
        
        hosts.append(host)
    
    return hosts


# =============================================================================
# Output Generators
# =============================================================================

def generate_markdown(hosts: list, include_scripts: bool = True) -> str:
    """Generate markdown output from parsed hosts."""
    lines = []
    
    lines.append("# Nmap Scan Results\n")
    lines.append("## Host Summary\n")
    lines.append("| IP | Hostname(s) | OS Guess | Ports |")
    lines.append("|:---|:------------|:---------|------:|")
    
    for host in hosts:
        hostnames = ", ".join(host.hostnames[:3]) if host.hostnames else "-"
        if len(host.hostnames) > 3:
            hostnames += f" (+{len(host.hostnames) - 3})"
        
        os_info = host.os_match[:50] if host.os_match else "-"
        if host.os_accuracy:
            os_info += f" ({host.os_accuracy}%)"
        
        port_count = len(host.ports)
        lines.append(f"| {host.ip} | {hostnames} | {os_info} | {port_count} |")
    
    lines.append("")
    lines.append("## Host Details\n")
    
    for host in hosts:
        lines.append(f"### {host.ip}")
        
        if host.hostnames:
            lines.append(f"**Hostnames:** {', '.join(host.hostnames)}")
        if host.os_match:
            lines.append(f"**OS:** {host.os_match} ({host.os_accuracy}% confidence)")
        if host.last_boot:
            lines.append(f"**Last Boot:** {host.last_boot}")
        
        lines.append("")
        
        if not host.ports:
            lines.append("*No open ports detected*\n")
            continue
        
        if include_scripts:
            lines.append("| Port | Service | Version | Extra Info | Notes |")
            lines.append("|-----:|:--------|:--------|:-----------|:------|")
        else:
            lines.append("| Port | Service | Version | Extra Info |")
            lines.append("|-----:|:--------|:--------|:-----------|")
        
        for port in host.ports:
            port_str = f"{port.port}/{port.protocol}"
            if port.tunnel:
                port_str += f" ({port.tunnel})"
            
            version = f"{port.product} {port.version}".strip()
            if not version:
                version = "-"
            
            extra = port.extrainfo if port.extrainfo else ""
            if port.ostype and port.ostype not in extra:
                extra = f"{port.ostype}; {extra}" if extra else port.ostype
            if not extra:
                extra = "-"
            
            notes = []
            if port.scripts.get("http_title"):
                notes.append(f"Title: {port.scripts['http_title']}")
            if port.scripts.get("generator"):
                notes.append(port.scripts["generator"])
            if port.scripts.get("domain"):
                notes.append(f"Domain: {port.scripts['domain']}")
            if port.scripts.get("windows_version"):
                notes.append(f"Win {port.scripts['windows_version']}")
            if port.scripts.get("ssl_cn"):
                notes.append(f"CN: {port.scripts['ssl_cn']}")
            if port.scripts.get("rpc_services"):
                notes.append(f"RPC: {port.scripts['rpc_services']}")
            if port.scripts.get("risky_methods"):
                notes.append(f"Risky: {port.scripts['risky_methods']}")
            if port.scripts.get("robots"):
                notes.append(f"robots.txt: {port.scripts['robots']}")
            
            notes_str = "; ".join(notes) if notes else "-"
            
            if include_scripts:
                lines.append(f"| {port_str} | {port.service} | {version} | {extra} | {notes_str} |")
            else:
                lines.append(f"| {port_str} | {port.service} | {version} | {extra} |")
        
        lines.append("")
    
    return "\n".join(lines)


def generate_csv(hosts: list) -> str:
    """Generate CSV output from parsed hosts."""
    lines = []
    lines.append("IP,Hostname,OS,Port,Protocol,Service,Product,Version,Extra,OS Type,CPE")
    
    for host in hosts:
        hostname = host.hostnames[0] if host.hostnames else ""
        os_info = host.os_match if host.os_match else ""
        
        for port in host.ports:
            cpe = port.cpe[0] if port.cpe else ""
            line = f'"{host.ip}","{hostname}","{os_info}",{port.port},{port.protocol},"{port.service}","{port.product}","{port.version}","{port.extrainfo}","{port.ostype}","{cpe}"'
            lines.append(line)
    
    return "\n".join(lines)


def markdown_to_html(markdown_text: str, title: str = "Nmap Scan Report") -> str:
    """Convert markdown to styled HTML document."""
    
    # Simple markdown to HTML conversion (no external dependencies)
    html_content = markdown_text
    
    # Headers
    html_content = re.sub(r'^### (.+)$', r'<h3>\1</h3>', html_content, flags=re.MULTILINE)
    html_content = re.sub(r'^## (.+)$', r'<h2>\1</h2>', html_content, flags=re.MULTILINE)
    html_content = re.sub(r'^# (.+)$', r'<h1>\1</h1>', html_content, flags=re.MULTILINE)
    
    # Bold
    html_content = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', html_content)
    
    # Italic
    html_content = re.sub(r'\*(.+?)\*', r'<em>\1</em>', html_content)
    
    # Tables
    lines = html_content.split('\n')
    in_table = False
    new_lines = []
    
    for i, line in enumerate(lines):
        # Detect table row
        if line.strip().startswith('|') and line.strip().endswith('|'):
            cells = [c.strip() for c in line.strip()[1:-1].split('|')]
            
            # Check if separator row
            if all(re.match(r'^:?-+:?$', c) for c in cells):
                continue  # Skip separator
            
            if not in_table:
                new_lines.append('<table>')
                in_table = True
                # First row is header
                new_lines.append('<thead><tr>')
                for cell in cells:
                    new_lines.append(f'<th>{cell}</th>')
                new_lines.append('</tr></thead>')
                new_lines.append('<tbody>')
            else:
                new_lines.append('<tr>')
                for cell in cells:
                    new_lines.append(f'<td>{cell}</td>')
                new_lines.append('</tr>')
        else:
            if in_table:
                new_lines.append('</tbody></table>')
                in_table = False
            new_lines.append(line)
    
    if in_table:
        new_lines.append('</tbody></table>')
    
    html_content = '\n'.join(new_lines)
    
    # Paragraphs (simple: convert double newlines)
    html_content = re.sub(r'\n\n+', '\n</p>\n<p>\n', html_content)
    
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <style>
        :root {{
            --bg-primary: #1a1a2e;
            --bg-secondary: #16213e;
            --bg-table: #0f0f1a;
            --text-primary: #eee;
            --text-secondary: #aaa;
            --accent: #00d9ff;
            --accent-dim: #0a4f5c;
            --border: #333;
            --highlight: #e94560;
        }}
        * {{
            box-sizing: border-box;
        }}
        body {{
            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            line-height: 1.6;
            margin: 0;
            padding: 20px;
        }}
        .container {{
            max-width: 1400px;
            margin: 0 auto;
        }}
        h1 {{
            color: var(--accent);
            border-bottom: 2px solid var(--accent);
            padding-bottom: 10px;
            margin-top: 0;
        }}
        h2 {{
            color: var(--accent);
            margin-top: 30px;
            border-left: 4px solid var(--accent);
            padding-left: 12px;
        }}
        h3 {{
            color: var(--highlight);
            margin-top: 25px;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 1.3em;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
            background: var(--bg-table);
            border-radius: 8px;
            overflow: hidden;
            font-size: 0.9em;
        }}
        th {{
            background: var(--bg-secondary);
            color: var(--accent);
            text-align: left;
            padding: 12px 10px;
            font-weight: 600;
            border-bottom: 2px solid var(--accent-dim);
        }}
        td {{
            padding: 10px;
            border-bottom: 1px solid var(--border);
            vertical-align: top;
        }}
        tr:hover {{
            background: var(--bg-secondary);
        }}
        tr:last-child td {{
            border-bottom: none;
        }}
        /* Port column styling */
        td:first-child {{
            font-family: 'Consolas', 'Monaco', monospace;
            color: var(--accent);
            white-space: nowrap;
        }}
        strong {{
            color: var(--accent);
        }}
        em {{
            color: var(--text-secondary);
            font-style: normal;
        }}
        p {{
            margin: 8px 0;
        }}
        /* Responsive */
        @media (max-width: 768px) {{
            table {{
                font-size: 0.8em;
            }}
            td, th {{
                padding: 6px 4px;
            }}
        }}
        /* Print styles */
        @media print {{
            body {{
                background: white;
                color: black;
            }}
            table {{
                background: white;
            }}
            th {{
                background: #f0f0f0;
                color: black;
            }}
            h1, h2, h3, strong, td:first-child {{
                color: black;
            }}
        }}
    </style>
</head>
<body>
<div class="container">
{html_content}
</div>
</body>
</html>"""


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Convert nmap XML to HTML report (handles broken --append-output XML)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python nmap2html.py scan.xml                     # -> scan.html
    python nmap2html.py scan.xml -o report.html      # custom output name
    python nmap2html.py scan.xml --format md         # markdown only
    python nmap2html.py scan.xml --format csv        # CSV for spreadsheets
    python nmap2html.py scan.xml --no-scripts        # minimal tables
    python nmap2html.py scan.xml --fix-only fixed.xml  # just fix XML
        """
    )
    parser.add_argument("xml_file", help="Nmap XML file to process")
    parser.add_argument("-o", "--output", help="Output file (default: <input>.html)")
    parser.add_argument("-f", "--format", choices=["html", "md", "csv"], default="html",
                        help="Output format (default: html)")
    parser.add_argument("--no-scripts", action="store_true",
                        help="Exclude script notes column")
    parser.add_argument("--fix-only", metavar="OUTPUT",
                        help="Only fix XML and write to file (no conversion)")
    parser.add_argument("--title", default="Nmap Scan Report",
                        help="HTML document title")
    
    args = parser.parse_args()
    
    # Read input file
    try:
        with open(args.xml_file, 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"[!] File not found: {args.xml_file}", file=sys.stderr)
        sys.exit(1)
    
    # Fix XML
    try:
        root = fix_nmap_xml(content)
        print(f"[+] XML parsed successfully", file=sys.stderr)
    except ValueError as e:
        print(f"[!] {e}", file=sys.stderr)
        sys.exit(1)
    
    # Fix-only mode
    if args.fix_only:
        tree = ET.ElementTree(root)
        ET.indent(tree, space='  ')
        tree.write(args.fix_only, encoding='utf-8', xml_declaration=True)
        print(f"[+] Fixed XML written to: {args.fix_only}", file=sys.stderr)
        sys.exit(0)
    
    # Parse hosts
    hosts = parse_nmap_xml(root)
    
    if not hosts:
        print("[!] No hosts found in scan", file=sys.stderr)
        sys.exit(1)
    
    print(f"[+] Found {len(hosts)} host(s)", file=sys.stderr)
    
    # Generate output
    if args.format == "csv":
        output = generate_csv(hosts)
        ext = ".csv"
    elif args.format == "md":
        output = generate_markdown(hosts, include_scripts=not args.no_scripts)
        ext = ".md"
    else:  # html
        md = generate_markdown(hosts, include_scripts=not args.no_scripts)
        output = markdown_to_html(md, title=args.title)
        ext = ".html"
    
    # Determine output path
    if args.output:
        output_path = args.output
    else:
        output_path = str(Path(args.xml_file).with_suffix(ext))
    
    # Write output
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(output)
    
    print(f"[+] Output written to: {output_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
