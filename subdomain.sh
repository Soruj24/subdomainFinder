#!/bin/bash

# --------------------------
# Automated Domain Recon Script
# Usage: ./recon.sh domains.txt
# --------------------------

# Input file and output directory
input_file="$1"
output_dir="recon-results"

# Check if input file exists
if [[ ! -f "$input_file" ]]; then
  echo -e "[✗] Error: Input file '$input_file' not found.\nUsage: $0 domains.txt"
  exit 1
fi

# Verify required tools are installed
required_tools=("subfinder" "assetfinder" "amass" "httpx" "dnsx" "nmap" "aquatone")
for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" &> /dev/null; then
    echo "[✗] Error: $tool is not installed. Install it first."
    exit 1
  fi
done

# Create output directory
mkdir -p "$output_dir"

# Fix Windows encoding issues (CRLF -> LF)
if ! command -v dos2unix &> /dev/null; then
  tr -d '\r' < "$input_file" > "$input_file.tmp"
  mv "$input_file.tmp" "$input_file"
else
  dos2unix "$input_file" &> /dev/null
fi

# Count domains
domain_count=$(wc -l < "$input_file")
echo -e "[*] Starting recon on $domain_count domains...\n"

# Domain processing function
process_domain() {
  local domain="$1"
  echo -e "\n[+] Processing: $domain"
  local domain_dir="$output_dir/$domain"
  mkdir -p "$domain_dir"

  # Subdomain enumeration
  echo "[→] Running Subfinder, Assetfinder, and Amass..."
  subfinder -d "$domain" -silent -o "$domain_dir/subfinder.txt" &> /dev/null
  assetfinder --subs-only "$domain" > "$domain_dir/assetfinder.txt" 2>/dev/null
  amass enum -passive -d "$domain" -o "$domain_dir/amass.txt" &> /dev/null

  # Merge and deduplicate subdomains
  cat "$domain_dir/"*.txt | sort -u > "$domain_dir/all_subdomains.txt"

  # DNS verification (A, AAAA, CNAME, etc.)
  if [[ -s "$domain_dir/all_subdomains.txt" ]]; then
    echo "[→] Verifying DNS records with dnsx..."
    dnsx -l "$domain_dir/all_subdomains.txt" -a -aaaa -cname -ns -txt -json -o "$domain_dir/dns_records.json" &> /dev/null
  fi

  # Probe live hosts (HTTP/HTTPS)
  echo "[→] Probing live hosts with httpx..."
  httpx -l "$domain_dir/all_subdomains.txt" -status-code -title -ip -web-server -tech-detect -json -o "$domain_dir/live_hosts.json" &> /dev/null

  # Capture screenshots with Aquatone
  if [[ -s "$domain_dir/live_hosts.json" ]]; then
    echo "[→] Taking screenshots with Aquatone..."
    cat "$domain_dir/live_hosts.json" | jq -r '.url' | aquatone -out "$domain_dir/aquatone" &> /dev/null
  fi

  # Nmap port scanning (Top 100 ports)
  echo "[→] Scanning ports with Nmap..."
  nmap -iL "$domain_dir/all_subdomains.txt" -T4 --top-ports 100 -oG "$domain_dir/nmap_scan.txt" &> /dev/null

  echo -e "[✓] Completed: $domain | Live hosts: $(jq length "$domain_dir/live_hosts.json" 2>/dev/null || echo 0)\n"
}

# Multi-threaded processing (GNU Parallel)
export -f process_domain
export output_dir
parallel -j 4 process_domain ::: $(cat "$input_file")

echo -e "\n[✔] All done! Final reports saved to: $output_dir/"
