#!/usr/bin/env python3
"""
Quick fix for NMAP XML files created with --append-output flag.
Merges multiple <nmaprun> blocks into a single valid XML file.
"""

import sys
import re
from xml.etree import ElementTree as ET

def fix_nmap_xml(input_file, output_file):
    """Merge multiple nmaprun blocks into one valid XML."""
    
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find all complete nmaprun blocks
    nmaprun_pattern = r'<nmaprun[^>]*>.*?</nmaprun>'
    matches = re.finditer(nmaprun_pattern, content, re.DOTALL)
    
    root = None
    all_hosts = []
    
    for i, match in enumerate(matches):
        xml_block = match.group(0)
        
        try:
            current_root = ET.fromstring(xml_block)
            
            # Use the first block as the base
            if i == 0:
                root = current_root
                # Extract hosts from first block
                for host in current_root.findall('host'):
                    all_hosts.append(host)
                # Remove all hosts from root (we'll add them back later)
                for host in list(root.findall('host')):
                    root.remove(host)
            else:
                # Extract hosts from subsequent blocks
                for host in current_root.findall('host'):
                    all_hosts.append(host)
                    
        except ET.ParseError as e:
            print(f"Warning: Could not parse block {i+1}: {e}", file=sys.stderr)
            continue
    
    if root is None:
        print("Error: Could not find any valid nmaprun blocks!", file=sys.stderr)
        sys.exit(1)
    
    # Add all hosts back to the root, just before runstats
    runstats = root.find('runstats')
    if runstats is not None:
        insert_position = list(root).index(runstats)
        for i, host in enumerate(all_hosts):
            root.insert(insert_position + i, host)
    else:
        # No runstats, just append at the end
        for host in all_hosts:
            root.append(host)
    
    # Update the host count in runstats if it exists
    if runstats is not None:
        hosts_elem = runstats.find('.//hosts')
        if hosts_elem is not None:
            hosts_elem.set('up', str(len(all_hosts)))
            hosts_elem.set('total', str(len(all_hosts)))
    
    # Write the merged XML
    tree = ET.ElementTree(root)
    ET.indent(tree, space='  ')
    tree.write(output_file, encoding='utf-8', xml_declaration=True)
    print(f"✓ Fixed XML written to: {output_file}")
    print(f"  Merged {len(all_hosts)} host(s) from the scans")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 fix_nmap_xml.py <input.xml> <output.xml>")
        sys.exit(1)
    
    fix_nmap_xml(sys.argv[1], sys.argv[2])
