# 📊 Matrice Complète des Flux et Politiques de Filtrage (OPNsense)

Ce document formalise la politique de sécurité et les règles de filtrage implémentées sur le pare-feu **OPNsense 25.7.10** pour l'infrastructure réseau Multi-DMZ.

**Auteur :** [Soufiane MAJD](https://github.com/SoufianeMajd) — *Élève-Ingénieur en Génie Informatique*

---

## 🎯 1. Principes Directeurs de Sécurité

1. **Politique du "Default Deny" (Zéro Confiance)** : Tout flux non explicitement autorisé est immédiatement jeté (`DROP` / `BLOCK`).
2. **Cloisonnement Strict Inter-DMZ (Anti-Rebond)** : Aucune machine en DMZ (même compromise) ne peut initier de connexion vers le réseau d'administration (LAN).
3. **Différenciation des Privilèges (RBAC / IP-based)** :
   - Le poste **Admin** (`192.168.100.20`) bénéficie des privilèges d'administration complète (SSH, WebGUI, ports d'administration applicatifs).
   - Les postes **Clients standards** (`192.168.100.21`) sont contraints d'emprunter le Proxy Web Squid avec filtrage de contenu et quotas stricts.
4. **Anti-Contournement DNS** : Seul le serveur DNS interne/passerelle (`10.10.1.2`) est autorisé. Toute tentative d'interrogation DNS directe vers l'extérieur (ex: `8.8.8.8` ou DoH) est bloquée.

---

## 🗂️ 2. Objets et Alias Définis sur OPNsense

Pour une gestion saine et maintenable des règles pare-feu, les alias suivants ont été configurés :

| Nom de l'Alias | Type | Valeur / Contenu | Rôle |
|:---|:---:|:---|:---|
| `ADMIN_IP` | Host | `192.168.100.20` | Adresse IP du poste d'administration |
| `CLIENT_PC` | Host | `192.168.100.21` | Poste client soumis au proxy obligatoire |
| `Web_DMZPUB` | Host | `172.16.100.80` | Serveur Web Apache en DMZ Publique |
| `Tomcat_DMZPROD` | Host | `172.16.200.80` | Serveur applicatif Apache Tomcat en DMZ Métier |
| `DNS_VMware` | Host | `10.10.1.2` | Serveur DNS de référence autorisé |
| `Web_Ports` | Port(s) | `80, 443` | Ports standards HTTP et HTTPS |
| `FW_MGMT_PORTS` | Port(s) | `22, 443` | Ports d'administration OPNsense (SSH & WebGUI) |
| `TOMCAT8080` | Port | `8080` | Port d'écoute du serveur d'application Tomcat |
| `PROXY_PORT` | Port | `3128` | Port d'écoute du service Squid Web Proxy |

---

## 📋 3. Matrice de Filtrage Granulaire (Règles F1 à F14 / R1 à R13)

| ID Flux | Règle Métier | Interface OPNsense | Source | Destination | Protocole | Port(s) | Action | Log | Justification Technique |
|:---:|:---:|:---:|:---|:---|:---:|:---:|:---:|:---:|:---|
| **F1** | **R9** | `LAN` | `ADMIN_IP` (192.168.100.20) | Toutes Zones | TCP / UDP | ALL | **PASS** | ✅ Oui | Administration complète du SI (SSH, WebGUI, BDD, App) |
| **F2** | **R5** | `LAN` / `DMZs` | `LAN net`, `DMZPUB_NET`, `DMZPROD_NET` | `DNS_VMware` (10.10.1.2) | UDP / TCP | 53 | **PASS** | ❌ Non | Résolution DNS centralisée autorisée |
| **F3** | **R5** | `LAN` / `DMZs` | `LAN net`, `DMZs nets` | `WAN net` / Internet | UDP / TCP | 53 | **BLOCK** | ✅ Oui | Anti-contournement : blocage des résolutions DNS externes |
| **F4** | **R10** | `LAN` | `CLIENT_PC` (192.168.100.21) | Firewall LAN (192.168.100.254) | TCP | 3128 | **PASS** | ❌ Non | Accès obligatoire au Proxy Web Squid |
| **F5** | **R10** | `LAN` | `CLIENT_PC` (192.168.100.21) | `WAN net` / Internet | TCP | 80, 443 | **BLOCK** | ✅ Oui | Blocage de la navigation directe sans proxy |
| **F6** | **R2** | `LAN` | `LAN net` | `Web_DMZPUB` (172.16.100.80) | TCP | 80, 443 | **PASS** | ❌ Non | Consultation de l'intranet Web par les utilisateurs LAN |
| **F7** | **R8** | `LAN` | `LAN net` | `Tomcat_DMZPROD` (172.16.200.80) | TCP | 8080 | **PASS** | ❌ Non | Accès des postes internes à l'application métier Tomcat |
| **F8** | **R6** | `LAN` | `LAN net` | `DMZPUB_NET`, `DMZPROD_NET` | ICMP | Echo Req | **PASS** | ❌ Non | Diagnostics réseau internes (Ping autorisé vers DMZ) |
| **F9** | **R6** | `DMZ_PUB` / `DMZ_PROD` | `DMZs nets` | `LAN net` | ICMP | Echo Req | **PASS** | ❌ Non | Réponse au ping et tests de connectivité supervisés |
| **F10** | **R3** | `DMZ_PUB` / `DMZ_PROD` | `DMZs nets` | `LAN net` | IP (All) | ALL | **BLOCK** | ✅ Oui | **Règle vitale anti-rebond** : Interdiction absolue d'accéder au LAN |
| **F11** | **R4** | `DMZ_PUB` / `DMZ_PROD` | `DMZs nets` | `WAN net` / Internet | TCP | 80, 443 | **PASS** | ❌ Non | Mises à jour de sécurité des serveurs (`apt update / upgrade`) |
| **F12** | **R6** | `Toutes Interfaces` | `ALL` | `WAN net` / Internet | ICMP | Echo Req | **BLOCK** | ✅ Oui | Interdiction de ping vers l'extérieur pour éviter le fingerprinting |
| **F13** | **R7** | `WAN` (Port Forward) | Internet (ANY) | `WAN Address` (Port 80) $\to$ `Web_DMZPUB`:443 | TCP | 80 $\to$ 443 | **PASS (NAT)** | ✅ Oui | Redirection sécurisée du trafic public vers le serveur Web Apache |
| **F14** | **R8** | `WAN` | Internet (ANY) | `Tomcat_DMZPROD` (172.16.200.80) | TCP | 8080 | **BLOCK** | ✅ Oui | Application métier interne strictement invisible depuis Internet |

---

## 🛡️ 4. Configuration du Filtrage Proxy Web (Squid)

Le service **Squid Web Proxy** est configuré en mode explicite / forcé sur le pare-feu :

* **Interface d'écoute** : `LAN` (`192.168.100.254:3128`)
* **Listes Noires (Blacklists - R12)** :
  * `facebook.com` / `www.facebook.com`
  * `twitter.com` / `x.com`
  * `whatsapp.com`
  * `youtube.com` / `www.youtube.com`
* **Contrôle de Téléchargement & Quota (R13)** :
  * `Maximum Download Size` : `20480 KB` (20 Mo).
  * Toute tentative de téléchargement dépassant 20 Mo est immédiatement interrompue par Squid avec renvoi d'un code HTTP `403 Forbidden` / Erreur de quota.

