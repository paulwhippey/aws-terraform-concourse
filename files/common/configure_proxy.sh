#!/bin/bash
# Proxy Setting
echo "Checking and setting Proxy configuration..."
# Checking if HTTP Proxy(s) provided and setting
%{ if proxy_config.http_proxy != null ~}
  echo "export http_proxy=${proxy_config.http_proxy}" >> /etc/profile.d/proxy.sh
  echo "export HTTP_PROXY=${proxy_config.http_proxy}" >> /etc/profile.d/proxy.sh
  echo "HTTP Proxy configured"
%{ else ~}
  echo "No HTTP Proxy configuration found. Skipping"
%{ endif ~}
# Checking if HTTPS Proxy(s) provided and setting
%{ if proxy_config.https_proxy != null ~}
  echo "export https_proxy=${proxy_config.https_proxy}" >> /etc/profile.d/proxy.sh
  echo "export HTTPS_PROXY=${proxy_config.https_proxy}" >> /etc/profile.d/proxy.sh
  echo "HTTPS Proxy configured"
%{ else ~}
  echo "No HTTPS Proxy configuration found. Skipping"
%{ endif ~}
# Checking if No Proxy configuration provided and setting
%{ if proxy_config.no_proxy != null ~}
  echo "export no_proxy=${proxy_config.no_proxy}" >> /etc/profile.d/proxy.sh
  echo "export NO_PROXY=${proxy_config.no_proxy}" >> /etc/profile.d/proxy.sh
  # echo "No-Proxy settings configured"
%{ else ~}
  echo "No No-Proxy configuration found. Skipping"
%{ endif ~}
