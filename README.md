# sh

This repository contains a set of shell scripts for quick installation and setup of common services.
These scripts are designed to be fast, minimal, and ready to use in production or development environments.

## 📦 Available Install Scripts

Each script can be executed directly from the terminal using `bash` and `curl`.

### 📝 Swapfile

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/swapfile.sh)
```

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/swapfile.sh) --enable
```

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/swapfile.sh) --enable --size 2048
```

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/swapfile.sh) --disable
```

### 🔧 Prometheus

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/prometheus_install.sh)
```

### 🔔 Alertmanager

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/alertmanager_install.sh)
```

### 📊 Node Exporter

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/node_install.sh)
```

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/node_install.sh) --ufw-allow-ip ip_addr
```

### 📦 Blackbox Exporter

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/blackbox_install.sh)
```

### ⚙️ BBR

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/bbr_install.sh)
```

### ⚙️ IPv6

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/ipv6.sh)
```

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/ipv6.sh) on
```

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/ipv6.sh) off
```

### 🌊 SQL Exporter Remnawave

```shell
bash <(curl -fsSL raw.githubusercontent.com/hteppl/sh/master/grafana/sql_exporter/sql_install.sh)
```

## 📄 License

This project is licensed under the MIT License. You are free to use, modify, and distribute the scripts with proper
attribution.