#!/bin/bash

# --------------------------
# Aquatone-free Recon Script
# Usage: ./recon.sh domains.txt
# --------------------------

input_file="$1"
output_dir="recon-results"

# Error handling
if [[ ! -f "$input_file" ]]; then
  echo -e "[✗] Error: Input file '$input_file' not found.\nUsage: $0 domains.txt"
  exit 1
fi

# Required tools (Aquatone removed)
required_tools=("subfinder" "assetfinder" "amass" "httpx" "dnsx" "nmap")
for tool in "${required_tools[@]}"; do
  if ! command -v "$tool" &> /dev/null; then
    echo "[✗] Error: $tool is not installed. Install it first."
    exit 1
  fi
done

# Prepare environment
mkdir -p "$output_dir"
dos2unix "$input_file" &> /dev/null || tr -d '\r' < "$input_file" > "$input_file.tmp"

# Main recon function
process_domain() {
  local domain="$1"
  echo -e "\n[+] Processing: $domain"
  local domain_dir="$output_dir/$domain"
  mkdir -p "$domain_dir"

  # Subdomain discovery
  echo "[→] Running Subfinder, Assetfinder, Amass..."
  subfinder -d "$domain" -silent -o "$domain_dir/subfinder.txt"
  assetfinder --subs-only "$domain" > "$domain_dir/assetfinder.txt"
  amass enum -passive -d "$domain" -o "$domain_dir/amass.txt"

  # Merge results
  cat "$domain_dir/"*.txt | sort -u > "$domain_dir/all_subdomains.txt"

  # DNS verification
  if [[ -s "$domain_dir/all_subdomains.txt" ]]; then
    echo "[→] DNS verification with dnsx..."
    dnsx -l "$domain_dir/all_subdomains.txt" -a -aaaa -cname -json -o "$domain_dir/dns.json"
  fi

  # HTTP(S) probing
  echo "[→] Probing with httpx..."
  httpx -l "$domain_dir/all_subdomains.txt" -status-code -title -tech-detect -json -o "$domain_dir/http.json"

  # Port scanning
  echo "[→] Nmap scanning (Top 100 ports)..."
  nmap -iL "$domain_dir/all_subdomains.txt" -T4 --top-ports 100 -oG "$domain_dir/nmap.txt"

  echo -e "[✓] Completed: $domain | Live: $(jq length "$domain_dir/http.json" 2>/dev/null || echo 0)\n"
}

# Parallel execution
export -f process_domain
export output_dir
parallel -j 4 process_domain ::: $(cat "$input_file")

echo -e "\n[✔] Recon completed! Results: $output_dir/"
