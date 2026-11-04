# 🏛️ Étude Avancée : Architecture en 2 Étages, Forçage Proxy & Haute Disponibilité (HA)

Ce document présente l'analyse d'ingénierie réseau et les concepts d'architecture avancés étudiés dans le cadre de ce projet de sécurisation.

**Auteur :** [Soufiane MAJD](https://github.com/SoufianeMajd) — *Élève-Ingénieur en Génie Informatique*

---

## 1. Mécanisme de Forçage du Proxy Web (Squid)

Dans une architecture d'entreprise, les utilisateurs internes ne doivent pas pouvoir naviguer librement sans contrôle applicatif (filtrage d'URL, analyse antivirus de flux, quotas de bande passante).

```mermaid
sequenceDiagram
    autonumber
    actor Client as 💻 PC Client (192.168.100.21)
    participant FW as 🛡️ Pare-feu OPNsense
    participant Proxy as 🔎 Squid Web Proxy (:3128)
    participant Web as 🌍 Serveur Web Externe (Internet)

    Note over Client, FW: Cas 1 : Tentative de navigation directe (Port 80/443)
    Client ->> FW: SYN TCP :80 vers IP externe
    FW -->> Client: DROP / REJECT (Règle F5: Blocage direct)

    Note over Client, FW: Cas 2 : Navigation conforme via le Proxy
    Client ->> Proxy: CONNECT / GET http://example.com via :3128
    Proxy ->> Proxy: Vérification Blacklist & Quotas (R12 / R13)
    alt Site Interdit (ex: Facebook)
        Proxy -->> Client: HTTP 403 Forbidden (Page d'erreur Squid)
    else Site Autorisé
        Proxy ->> Web: Établissement de la connexion pour le compte du client
        Web -->> Proxy: Données HTTP/HTTPS
        Proxy -->> Client: Données relayées (avec contrôle de taille < 20 Mo)
    end
```

---

## 2. Architecture Pare-Feu en Deux Étages (Two-Tier Firewalls)

Pour les infrastructures critiques, une architecture à double étage de pare-feu permet de cloisonner le risque en évitant le point unique de compromission (*Single Point of Failure* sécuritaire) :

```mermaid
flowchart TD
    WAN["🌍 Internet / WAN"]
    FW_EXT["🛡️ Pare-feu Externe (Étage 1)<br>Filtrage périmétrique & NAT"]
    DMZ_PUB["🌐 DMZ Publique<br>Serveur Web Apache / Reverse Proxy"]
    FW_INT["🛡️ Pare-feu Interne (Étage 2)<br>Contrôle d'accès applicatif strict"]
    DMZ_PROD["🗄️ DMZ Privée / Production<br>Serveur Tomcat & Bases de données"]
    LAN["🏢 Réseau Interne LAN"]

    WAN <--> FW_EXT
    FW_EXT <--> DMZ_PUB
    DMZ_PUB <--> FW_INT
    FW_INT <--> DMZ_PROD
    FW_INT <--> LAN
```

### Avantages Majeurs :
* **Hétérogénéité des technologies** : Il est possible d'utiliser deux systèmes pare-feu différents (ex: OPNsense en frontal, pfSense ou iptables/nftables en interne) pour qu'une vulnérabilité zero-day sur un système ne donne pas accès à l'ensemble du réseau.
* **Séparation des responsabilités** : Le pare-feu externe gère l'exposition publique et les flux massifs d'Internet, tandis que le pare-feu interne protège les actifs vitaux (ERP, RH, bases de données relationnelles).

---

## 3. Schéma de Haute Disponibilité Actif-Passif (Cluster OPNsense CARP)

Afin de prévenir toute interruption de service en production, l'architecture a été conçue pour supporter un basculement automatique (*Failover*) transparent :

```mermaid
flowchart TD
    WAN_SWITCH["🌐 Switch Virtuel WAN"]
    
    subgraph CLUSTER["🔄 Cluster Pare-feu Haute Disponibilité"]
        direction LR
        FW_MASTER["🛡️ OPNsense MASTER<br>(Actif)<br>IP Réelle: 10.10.1.252"]
        FW_BACKUP["🛡️ OPNsense BACKUP<br>(Passif / Standby)<br>IP Réelle: 10.10.1.253"]
        
        FW_MASTER <-->|"Liaison Dédiée (Sync Heartbeat)<br>• pfSync (Table d'état)<br>• XMLRPC (Réplication config)"| FW_BACKUP
    end

    VIP_WAN["🔑 IP Virtuelle Partagée (VIP CARP)<br>10.10.1.254 (Passerelle par défaut)"]
    LAN_SWITCH["🏢 Switch Virtuel LAN"]

    WAN_SWITCH --- VIP_WAN
    VIP_WAN --- CLUSTER
    CLUSTER --- LAN_SWITCH
```

### Protocoles et Synchronisation :
1. **CARP (Common Address Redundancy Protocol)** : Partage d'une adresse IP Virtuelle (VIP) entre les deux nœuds. En fonctionnement normal, seul le nœud Maître répond aux requêtes ARP.
2. **pfSync** : Synchronise en temps réel la table des états de connexion (*State Table*) à travers un lien réseau dédié. En cas de panne matérielle du Maître, les sessions TCP actives des utilisateurs (téléchargements, appels Web) ne sont pas interrompues.
3. **XMLRPC Sync** : Toute modification apportée aux règles de pare-feu, aux alias ou aux paramètres Squid sur le Maître est automatiquement répliquée sur le Backup.

