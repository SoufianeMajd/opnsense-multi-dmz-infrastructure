# 🛡️ Conception & Déploiement d'une Infrastructure Réseau Sécurisée Multi-DMZ avec OPNsense

[![OPNsense Version](https://img.shields.io/badge/OPNsense-25.7.10%20(FreeBSD%2014.2)-red.svg?logo=opnsense&logoColor=white)](https://opnsense.org/)
[![Security Architecture](https://img.shields.io/badge/Architecture-Multi--DMZ%20(4%20Zones)-blue.svg)]()
[![Web Proxy](https://img.shields.io/badge/Proxy-Squid%20(Quota%2020Mo%20%2B%20Blacklist)-orange.svg)]()
[![Services](https://img.shields.io/badge/Services-Apache2%20%7C%20Tomcat10%20%7C%20Unbound-green.svg)]()
[![Video Demo](https://img.shields.io/badge/D%C3%A9monstration-Vid%C3%A9o%20YouTube-red.svg?logo=youtube)](https://youtu.be/1bto08GDMUk)
[![Status](https://img.shields.io/badge/Statut-Valid%C3%A9%20%26%20Op%C3%A9rationnel-brightgreen.svg)]()

> **Projet d'Ingénierie Réseaux, Systèmes et Cybersécurité**  
> Conception, segmentation avancée et durcissement d'une infrastructure d'entreprise sous le pare-feu open-source **OPNsense**.

---

## 📺 Démonstration Vidéo du Projet

Retrouvez la présentation technique complète et les tests en direct de l'infrastructure sur YouTube :  
🔗 **[Regarder la vidéo de démonstration pratique (YouTube)](https://youtu.be/1bto08GDMUk)**

---

## 📑 Sommaire
1. [Contexte & Objectifs du Projet](#-contexte--objectifs-du-projet)
2. [Topologie Réseau & Plan d'Adressage](#-topologie-r%C3%A9seau--plan-dadressage)
3. [Architecture Logique](#-architecture-logique)
4. [Politique de Sécurité & Règles de Filtrage (R1 à R13)](#-politique-de-s%C3%A9curit%C3%A9--r%C3%A8gles-de-filtrage-r1-%C3%A0-r13)
5. [Configuration du Proxy Squid & Forçage](#-configuration-du-proxy-squid--for%C3%A7age)
6. [Scénarios de Recette & Validation](#-sc%C3%A9narios-de-recette--validation)
7. [Incidents Techniques Rencontrés & Résolutions](#-incidents-techniques-rencontr%C3%A9s--r%C3%A9solutions)
8. [Arborescence du Dépôt](#-arborescence-du-d%C3%A9p%C3%A4t)
9. [Auteur](#-auteur)

---

## 🎯 Contexte & Objectifs du Projet

L'objectif de ce projet est de concevoir et de déployer une infrastructure réseau hautement sécurisée pour un environnement d'entreprise, segmentée en plusieurs zones de confiance étanches :

* **Ségrégation stricte des zones** : Isoler les services publiquement accessibles (serveur Web Apache) des applications métier internes sensibles (serveur Apache Tomcat) et des postes utilisateurs.
* **Différenciation granulaire des privilèges (RBAC / IP-based)** :
  * Le poste **Administrateur** bénéficie d'accès complets de gestion (SSH, HTTPS/WebGUI, ports de base de données).
  * Les postes **Clients standards** sont soumis à un filtrage strict sans possibilité d'administration ni de navigation directe.
* **Contrôle et Forçage du Proxy Web** : Interception obligatoire des flux Web clients via **Squid**, avec filtrage de domaines (réseaux sociaux interdits) et limitation de la taille des téléchargements à 20 Mo.
* **Anti-Rebond & Principe du Moindre Privilège** : Impossibilité totale pour une machine compromise en DMZ d'initier une attaque ou un scan vers le réseau interne LAN.

---

## 🗺️ Topologie Réseau & Plan d'Adressage

L'infrastructure s'articule autour de 4 cartes réseaux virtuelles managées par OPNsense :

| Zone | Interface | Réseau / Masque | IP Passerelle (OPNsense) | Équipements Clés & Rôles |
|:---|:---:|:---:|:---:|:---|
| **WAN** | `em0` | `10.10.1.0/24` | `10.10.1.2` (Passerelle VMware) | Accès Internet simulé / NAT Inbound (IP OPNsense: `10.10.1.254`) |
| **LAN** | `em2` | `192.168.100.0/24` | `192.168.100.254` | **PC Admin** : `192.168.100.20`<br>**PC Client** : `192.168.100.21` |
| **DMZ_PUB** | `em1` (opt1) | `172.16.100.0/24` | `172.16.100.254` | **Srv Web (Apache2)** : `172.16.100.80`<br>Ports exposés : 80, 443 |
| **DMZ_PROD** | `em3` (opt2) | `172.16.200.0/24` | `172.16.200.254` | **Srv App (Tomcat 10)** : `172.16.200.80`<br>Port métier : 8080 (Accès LAN uniquement) |

---

## 🏗️ Architecture Logique

```mermaid
flowchart TD
    WAN["🌍 WAN / Internet<br>Réseau: 10.10.1.0/24<br>GW / DNS: 10.10.1.2"]
    
    subgraph OPNSENSE["🛡️ PARE-FEU CENTRAL OPNSENSE 25.7.10"]
        FW["Filtrage Stateful & Aliases<br>+ NAT Port Forwarding (80 ➔ 443)<br>+ Squid Web Proxy (:3128)<br>+ Unbound DNS"]
    end

    subgraph LAN_ZONE["🏢 ZONE LAN (192.168.100.0/24)"]
        direction TB
        ADMIN["💻 PC Admin (192.168.100.20)<br>• SSH Pare-feu (:22)<br>• WebGUI Pare-feu (:443)<br>• Accès intégral SI"]
        CLIENT["👤 PC Client (192.168.100.21)<br>• Navigation directe : BLOQUÉE<br>• Proxy forcé : 3128<br>• Quota download : 20 Mo"]
    end

    subgraph DMZ_PUB_ZONE["🌐 DMZ PUBLIQUE (172.16.100.0/24)"]
        APACHE["🖥️ Serveur Web Apache (172.16.100.80)<br>• HTTP :80 / HTTPS :443<br>• Accessible depuis WAN & LAN"]
    end

    subgraph DMZ_PROD_ZONE["🗄️ DMZ PRODUCTION (172.16.200.0/24)"]
        TOMCAT["⚙️ Serveur Applicatif Tomcat (172.16.200.80)<br>• Port Métier : 8080<br>• Strictement invisible depuis Internet"]
    end

    WAN <-->|em0 (10.10.1.254)| FW
    FW <-->|em2 (192.168.100.254)| LAN_ZONE
    FW <-->|em1 (172.16.100.254)| DMZ_PUB_ZONE
    FW <-->|em3 (172.16.200.254)| DMZ_PROD_ZONE
```

> 💡 Le schéma d'architecture modifiable est disponible au format Draw.io dans [`assets/diagrams/architecture_multi_dmz.drawio`](./assets/diagrams/architecture_multi_dmz.drawio).

---

## 🔐 Politique de Sécurité & Règles de Filtrage (R1 à R13)

L'intégralité du cahier des charges de filtrage a été déclinée en règles stateful optimisées :

* **R1 — Moindre privilège applicatif** : L'accès aux serveurs en DMZ est restreint exclusivement aux ports par défaut déclarés (`80/443` pour Apache, `8080` pour Tomcat).
* **R2 — Accès direct réservé au LAN** : Seuls les postes du réseau LAN peuvent accéder directement aux services hébergés en DMZ.
* **R3 — Isolation absolue DMZ $\to$ LAN (Anti-Rebond)** : Aucune machine située en DMZ ne peut initier de flux vers le LAN (hors requêtes Echo ICMP autorisées à des fins de test).
* **R4 — Mises à jour système** : La navigation HTTP/HTTPS sortante vers Internet est autorisée pour permettre les opérations de maintenance (`apt update`).
* **R5 — Anti-contournement DNS** : La résolution DNS est autorisée **uniquement** à destination de `10.10.1.2` (port UDP 53). Tout autre résolveur externe est rejeté.
* **R6 — Contrôle ICMP Ping** : Le ping de diagnostic est permis entre le LAN et les DMZ dans les deux sens, mais le ping sortant vers Internet est rigoureusement bloqué.
* **R7 — Exposition Web publique sécurisée** : L'accès public depuis Internet vers le port 80 du pare-feu est translaté par DNAT vers le serveur Web en DMZ Publique sur le port sécurisé HTTPS 443.
* **R8 — Protection de la DMZ Production** : Le serveur Tomcat (`172.16.200.80:8080`) est réservé aux utilisateurs internes du LAN et reste hermétique au WAN.
* **R9 — Cloisonnement de l'Administration** : L'administration du pare-feu (SSH 22, HTTPS 443) et des serveurs applicatifs est strictement restreinte à l'IP `ADMIN_IP` (`192.168.100.20`).
* **R10 — Forçage du Proxy Web** : La navigation Web directe des clients du LAN vers Internet est interdite sur le firewall ; le flux doit impérativement transiter par le proxy Squid (port 3128).
* **R11 — Standardisation des ports** : Utilisation exclusive des numéros de ports conventionnels.
* **R12 — Filtrage d'URL (Blacklist)** : Interdiction d'accès aux domaines récréatifs (`facebook.com`, `twitter.com`, `x.com`, `whatsapp.com`, `youtube.com`).
* **R13 — Quota de téléchargement** : Limitation stricte de la taille maximale des fichiers téléchargeables à **20 Mo**.

> 📄 Retrouvez la matrice technique complète dans [`docs/MATRICE_DE_FLUX.md`](./docs/MATRICE_DE_FLUX.md).

---

## 🔎 Configuration du Proxy Squid & Forçage

Afin d'éviter tout contournement par les postes utilisateurs :
1. **Sur OPNsense** : Une règle de pare-feu bloque le trafic sortant direct TCP 80 et 443 émanant du sous-réseau `LAN net` à destination du WAN.
2. **Port d'écoute Squid** : Le démon écoute sur `192.168.100.254:3128`.
3. **Contrôle d'accès (ACLs)** :
   * Liste noire configurée avec les domaines cibles de la règle R12.
   * `Maximum Download Size` configuré à `20480 KB` (Règle R13).
4. Le fichier de configuration prêt à l'emploi est consultable dans [`configs/proxy/squid_rules.conf`](./configs/proxy/squid_rules.conf).

---

## 🧪 Scénarios de Recette & Validation

Tous les tests de conformité ont été validés avec succès lors de la phase de recette :

```text
======================================================================
   AUDIT AUTOMATISÉ DE LA POLITIQUE PARE-FEU MULTI-DMZ (OPNSENSE)     
======================================================================

[T01] Accès SSH Administration Pare-feu (192.168.100.254:22)
  -> CONFORME (Flux autorisé pour ADMIN_IP)

[T02] Résolution DNS VMware autorisée (10.10.1.2:53)
  -> CONFORME (Flux autorisé)

[T03] Anti-contournement DNS vers résolveur externe (8.8.8.8:53)
  -> CONFORME (Flux bloqué par le pare-feu)

[T04] Accès Intranet au Serveur Web Apache (172.16.100.80:80)
  -> CONFORME (Flux autorisé)

[T05] Accès à l'application Métier Tomcat (172.16.200.80:8080)
  -> CONFORME (Flux autorisé pour le LAN)

[T06] Blocage navigation Web directe sans proxy
  -> CONFORME (Flux direct intercepté et bloqué)

[T07] Filtrage URL Blacklist Proxy (Blocage Facebook)
  -> CONFORME (Erreur 403 Forbidden Squid renvoyée)

[T08] Quota de téléchargement > 20 Mo
  -> CONFORME (Téléchargement interrompu au quota)

[T09] Ségrégation critique DMZ vers LAN
  -> CONFORME (Tentative d'accès bloquée par OPNsense)
======================================================================
```

> 📖 Le cahier de recette pas à pas est disponible dans [`docs/PROCEDURES_DE_TESTS.md`](./docs/PROCEDURES_DE_TESTS.md).

---

## ⚠️ Incidents Techniques Rencontrés & Résolutions

Durant la réalisation du projet, deux problématiques majeures ont été surmontées :

1. **Perte de la passerelle WAN par défaut en mode DHCP :**
   * *Problème :* Sous VMware, le renouvellement de bail DHCP de l'interface `em0` provoquait la disparition aléatoire de la route par défaut.
   * *Solution :* Configuration d'une adresse IP Statique sur l'interface WAN (`10.10.1.254/24`) avec déclaration manuelle de la passerelle `10.10.1.2` comme `Default Gateway`.

2. **Échec de résolution de noms post-configuration statique :**
   * *Problème :* Les requêtes de mise à jour système vers les miroirs FreeBSD/OPNsense échouaient avec l'erreur `Host not found`.
   * *Solution :* Déclaration explicite des DNS primaires et secondaires dans *System > Settings > General* et configuration adéquate d'Unbound DNS.

---

## 📁 Arborescence du Dépôt

```text
.
├── README.md                           <- Documentation principale du projet
├── .gitignore                          <- Exclusion des fichiers volumineux et clés
├── assets/
│   ├── diagrams/
│   │   └── architecture_multi_dmz.drawio <- Schéma d'architecture source Draw.io
│   └── screenshots/
│       └── README.md                   <- Nomenclature et descriptif des captures
├── captures-pcap/
│   └── README.md                       <- Guide des captures Wireshark de validation
├── configs/
│   ├── opnsense/
│   │   └── config_sanitized.xml        <- Export XML assaini d'OPNsense (règles & alias)
│   ├── dmz_web/
│   │   └── apache_virtualhost.conf     <- Configuration VirtualHost Apache2 (SSL)
│   ├── dmz_prod/
│   │   └── server.xml                  <- Configuration durcie Tomcat 10
│   └── proxy/
│       └── squid_rules.conf            <- Paramétrage ACLs Squid & Quotas
├── docs/
│   ├── MATRICE_DE_FLUX.md              <- Tableau exhaustif des autorisations
│   ├── PROCEDURES_DE_TESTS.md          <- Scénarios de validation détaillés
│   └── ARCHITECTURE_HA_ET_PROXY.md     <- Étude CARP / Actif-Passif & Proxy
└── scripts/
    ├── audit_flux.sh                   <- Script d'audit automatique des règles de flux
    └── deploy_services.sh              <- Script de déploiement des serveurs DMZ
```

---

## 👤 Auteur

* **Soufiane MAJD** — *Élève-Ingénieur en Génie Informatique (Réseaux, Systèmes & Cybersécurité)*  
* 💼 **LinkedIn** : [linkedin.com/in/soufiane-majd](https://linkedin.com/in/soufiane-majd)  
* 🐙 **GitHub** : [@SoufianeMajd](https://github.com/SoufianeMajd)  
* ✉️ **Email** : [majdsoufiane55@gmail.com](mailto:majdsoufiane55@gmail.com)  
* 📺 **Démonstration Vidéo** : [Visionner sur YouTube](https://youtu.be/1bto08GDMUk)

