#!/bin/bash

# Usage: ./strong-recon.sh example.com

if [ -z "$1" ]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

domain=$1
output_dir="recon-$domain"
mkdir -p $output_dir

echo "[+] Starting Recon on: $domain"
echo "[+] Output directory: $output_dir"

#######################
# Subdomain Enumeration
#######################

echo "[+] Sublist3r..."
sublist3r -d $domain -o $output_dir/sublist3r.txt

echo "[+] Amass..."
amass enum -d $domain -o $output_dir/amass.txt

echo "[+] Knockpy..."
knockpy $domain --output $output_dir/knockpy

echo "[+] Subfinder..."
subfinder -d $domain -o $output_dir/subfinder.txt

echo "[+] AssetFinder..."
assetfinder --subs-only $domain > $output_dir/assetfinder.txt

echo "[+] Findomain..."
findomain --target $domain --output - > $output_dir/findomain.txt

# Combine and sort all subdomains
cat $output_dir/*.txt $output_dir/knockpy/$domain.csv | sort -u | grep $domain > $output_dir/all_subdomains.txt
echo "[+] Total unique subdomains found: $(wc -l < $output_dir/all_subdomains.txt)"

####################
# DNS Resolution
####################

echo "[+] Resolving subdomains with massdns..."
massdns -r /path/to/resolvers.txt -t A -o S -w $output_dir/resolved.txt $output_dir/all_subdomains.txt

# Extract valid domains from massdns output
awk '{print $1}' $output_dir/resolved.txt | sed 's/\.$//' | sort -u > $output_dir/resolved_domains.txt

####################
# Live Host Checking
####################

echo "[+] Probing for live subdomains using httpx..."
httpx -l $output_dir/resolved_domains.txt -silent -status-code -title -tech-detect -o $output_dir/live_hosts.txt

####################
# DNS Brute-force
####################

echo "[+] Running AltDNS..."
altdns -i $output_dir/all_subdomains.txt -o $output_dir/altdns_output.txt -w /path/to/words.txt -r -s $output_dir/altdns_resolved.txt

echo "[+] DNSrecon zone transfer test..."
dnsrecon -d $domain -a > $output_dir/dnsrecon.txt

echo "[+] Fierce scan..."
fierce --domain $domain > $output_dir/fierce.txt

####################
# Web Directory Bruteforce
####################

echo "[+] Gobuster vhost scan on live subdomains..."
while read sub; do
  gobuster vhost -u http://$sub -w /path/to/vhosts.txt -o $output_dir/gobuster_$sub.txt
done < $output_dir/resolved_domains.txt

####################
# Port Scanning
####################

echo "[+] RustScan fast port scan..."
while read ip; do
  rustscan -a $ip -r 1-65535 --ulimit 5000 -b 500 -o $output_dir/rustscan_$ip.txt
done < <(awk '{print $2}' $output_dir/resolved.txt | sort -u)

####################
# Final Notes
####################

echo "[+] Recon completed. All output saved in $output_dir/"
echo "[+] Live hosts found: $(wc -l < $output_dir/live_hosts.txt)"
