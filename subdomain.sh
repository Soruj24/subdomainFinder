#!/bin/bash

# Get input file from argument
input_file="$1"
output_dir="recon-results"

# Check if file provided
if [[ ! -f "$input_file" ]]; then
  echo "[✗] Input file '$input_file' not found."
  echo "Usage: $0 domains.txt"
  exit 1
fi

# Check required tools
for tool in subfinder assetfinder httpx; do
  if ! command -v $tool &> /dev/null; then
    echo "[✗] Tool $tool not found. Install it first."
    exit 1
  fi
done

mkdir -p "$output_dir"

# Clean carriage returns (in case of Windows file)
dos2unix "$input_file" &> /dev/null

domain_count=$(wc -l < "$input_file")
echo "[*] Starting recon on $domain_count domains..."

# Loop through each domain
while IFS= read -r domain || [[ -n "$domain" ]]; do
  [[ -z "$domain" ]] && continue

  echo -e "\n[+] Recon on: $domain"
  domain_dir="$output_dir/$domain"
  mkdir -p "$domain_dir"

  echo "[*] Running Subfinder..."
  subfinder -d "$domain" -silent -o "$domain_dir/subfinder.txt"

  echo "[*] Running Assetfinder..."
  assetfinder --subs-only "$domain" > "$domain_dir/assetfinder.txt"

  # Merge and deduplicate
  cat "$domain_dir/"*.txt | sort -u > "$domain_dir/all_subdomains.txt"

  echo "[*] Probing live subdomains with httpx..."
  httpx -l "$domain_dir/all_subdomains.txt" -silent -status-code -title -ip -o "$domain_dir/live.txt"

  echo "[✓] Done with $domain | Live: $(wc -l < "$domain_dir/live.txt")"
done < "$input_file"

echo -e "\n[✔] Recon completed. Results in '$output_dir/'"
