#!/bin/bash

# Default domains file
input="domains.txt"
output_dir="recon-results"

# Check tools
for tool in subfinder assetfinder httpx; do
  if ! command -v $tool &> /dev/null; then
    echo "[✗] Tool $tool not found. Install it first."
    exit 1
  fi
done

# Create output directory
mkdir -p "$output_dir"

echo "[*] Starting recon on $(wc -l < $input) domains..."

# Loop through each domain
while read -r domain; do
  [[ -z "$domain" ]] && continue
  echo -e "\n[+] Recon on: $domain"

  domain_dir="$output_dir/$domain"
  mkdir -p "$domain_dir"

  echo "[*] Running Subfinder..."
  subfinder -d "$domain" -silent -o "$domain_dir/subfinder.txt"

  echo "[*] Running Assetfinder..."
  assetfinder --subs-only "$domain" > "$domain_dir/assetfinder.txt"

  # Merge, dedup
  cat "$domain_dir/"*.txt | sort -u > "$domain_dir/all_subdomains.txt"

  echo "[*] Probing live subdomains with httpx..."
  httpx -l "$domain_dir/all_subdomains.txt" -silent -status-code -title -ip -o "$domain_dir/live.txt"

  echo "[✓] Done with $domain | Live: $(wc -l < "$domain_dir/live.txt")"

done < "$input"

echo -e "\n[✔] Recon completed. Results in '$output_dir/'"
