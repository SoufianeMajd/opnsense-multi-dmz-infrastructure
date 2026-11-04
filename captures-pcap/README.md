# 🔬 Captures de Trafic Réseau Wireshark (.pcap / .pcapng)

Ce répertoire contient les traces réseau brutes capturées durant les phases de tests d'intrusion et de validation de la politique de filtrage.

---

## 📁 Nomenclature et Description des Fichiers de Capture

| Nom du Fichier | Interface d'Écoute | Scénario Testé | Éléments Clés Observables dans Wireshark |
|:---|:---:|:---|:---|
| `drop_dmz_to_lan.pcapng` | `em1` / `em2` | Tentative d'accès depuis la DMZ Web vers le LAN interne | Paquets TCP SYN émis par la DMZ sans réponse SYN-ACK (ou paquets silencieusement détruits par la règle R3 d'OPNsense). |
| `nat_port_forward_80_to_443.pcapng` | `em0` (WAN) & `em1` (DMZ) | Translation d'adresse Destination NAT | Paquet arrivant sur l'adresse WAN publique sur le port 80 réécrit et transmis à l'adresse `172.16.100.80:443`. |
| `proxy_intercept_facebook.pcapng` | `em2` (LAN) | Filtrage d'URL interdit via Squid | Établissement de la connexion TCP vers le port 3128 d'OPNsense, requête HTTP CONNECT / GET, suivie de la réponse HTTP `403 Forbidden` émise par Squid. |
| `dns_anti_contournement.pcapng` | `em2` (LAN) | Tentative de requête DNS vers `8.8.8.8` | Requête DNS sur le port UDP 53 rejetée / bloquée par la règle F3 d'OPNsense. |

---

## 🛠️ Instructions pour Ouvrir et Analyser les Fichiers

1. Téléchargez et installez **Wireshark** ([https://www.wireshark.org/](https://www.wireshark.org/)).
2. Ouvrez le fichier souhaité.
3. Filtres Wireshark recommandés :
   - Pour observer les rejets pare-feu : `icmp.type == 3 || tcp.flags.reset == 1`
   - Pour observer le trafic Proxy : `tcp.port == 3128`
   - Pour observer les requêtes DNS : `udp.port == 53`
   - Pour observer la translation NAT : `ip.addr == 172.16.100.80 && (tcp.port == 80 || tcp.port == 443)`

