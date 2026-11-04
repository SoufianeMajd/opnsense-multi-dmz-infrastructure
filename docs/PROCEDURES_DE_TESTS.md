# 🧪 Cahier de Recette, Procédures de Tests & Validation

Ce document détaille l'ensemble des scénarios de test exécutés pour valider la conformité de l'infrastructure OPNsense avec le cahier des charges et la matrice des flux.

**Auteur :** [Soufiane MAJD](https://github.com/SoufianeMajd) — *Élève-Ingénieur en Génie Informatique*

---

## 🎯 Synthèse des Résultats de Validation

| Scénario | Source | Destination Testée | Commande Exécutée | Résultat Attendu | Résultat Obtenu | Statut |
|:---|:---|:---|:---|:---|:---|:---:|
| **T01 - Admin Firewall** | PC Admin (`.20`) | OPNsense (`.254:22`) | `ssh root@192.168.100.254` | Invite mot de passe reçue | ✅ Connexion réussie | **VALIDE (R9)** |
| **T02 - Client Firewall** | PC Client (`.21`) | OPNsense (`.254:22`) | `ssh root@192.168.100.254` | Connexion rejetée / Timeout | ❌ Connection refused / Denied | **VALIDE (R9)** |
| **T03 - Accès Web Intranet** | LAN Client (`.21`) | Srv Web (`172.16.100.80`) | `curl -I http://172.16.100.80` | HTTP 200 OK | ✅ Page d'accueil Apache reçue | **VALIDE (R2)** |
| **T04 - Accès Tomcat Métier**| LAN Client (`.21`) | Srv App (`172.16.200.80:8080`) | `curl -I http://172.16.200.80:8080`| HTTP 200 OK | ✅ Page d'accueil Tomcat reçue | **VALIDE (R8)** |
| **T05 - Blocage Navigation Directe**| PC Client (`.21`) | Internet (`8.8.8.8:80`) | `curl -I http://1.1.1.1` (sans proxy) | Timeout (bloqué par firewall) | ❌ Connection timed out | **VALIDE (R10)** |
| **T06 - Navigation via Proxy** | PC Client (`.21`) | Site autorisé via Proxy | `curl -x 192.168.100.254:3128 http://example.com` | HTTP 200 OK | ✅ Navigation fonctionnelle | **VALIDE (R10)** |
| **T07 - Filtrage URL Réseaux Sociaux**| PC Client (`.21`) | `facebook.com` via Proxy | `curl -x 192.168.100.254:3128 http://facebook.com` | HTTP 403 Forbidden | ❌ Page d'erreur Squid reçue | **VALIDE (R12)** |
| **T08 - Quota Téléchargement (>20Mo)**| PC Client (`.21`) | Fichier ISO/Test (25 Mo) | `wget -e use_proxy=yes -e http_proxy=192.168.100.254:3128 [URL_25MB]` | Échec au-delà de 20 Mo | ❌ Connexion coupée à 20 Mo | **VALIDE (R13)** |
| **T09 - Isolation DMZ -> LAN** | Srv Web (`172.16.100.80`) | PC Admin (`192.168.100.20`) | `ssh 192.168.100.20` | Timeout / Dropped | ❌ Bloqué par OPNsense (Rule R3) | **VALIDE (R3)** |
| **T10 - Diagnostic Ping Réseau** | LAN Client (`.21`) | Srv Web (`172.16.100.80`) | `ping -c 3 172.16.100.80` | Réponse Echo Reply reçue | ✅ 0% packet loss | **VALIDE (R6)** |
| **T11 - Blocage Ping Internet** | LAN / DMZ | `8.8.8.8` | `ping -c 3 8.8.8.8` | Requêtes bloquées | ❌ 100% packet loss | **VALIDE (R6)** |
| **T12 - Accès Public Web (DNAT)** | Client WAN (`10.10.1.X`)| WAN IP (`10.10.1.254:80`) | `curl -I http://10.10.1.254` | Redirigé vers DMZ Web (443) | ✅ HTTP 200 / 301 vers 443 | **VALIDE (R7)** |
| **T13 - Exposition Tomcat WAN** | Client WAN (`10.10.1.X`)| WAN IP (`10.10.1.254:8080`) | `curl -I http://10.10.1.254:8080` | Port fermé / filtré | ❌ Connection refused | **VALIDE (R8)** |

---

## 🔬 Détail des Procédures d'Exécution

### Scénario 1 : Différenciation des Accès Administration vs Client

1. **Depuis le poste PC Admin (`192.168.100.20`) :**
   ```bash
   ssh -v root@192.168.100.254
   ```
   *Observation :* Le tunnel SSH s'établit et OPNsense demande la saisie de la clé / mot de passe. Règle `F1` active.

2. **Depuis le poste PC Client (`192.168.100.21`) :**
   ```bash
   ssh -o ConnectTimeout=3 root@192.168.100.254
   ```
   *Observation :* `ssh: connect to host 192.168.100.254 port 22: Connection refused` ou `timed out`. La règle de rejet/drop par défaut interdit tout accès aux ports de gestion du pare-feu.

---

### Scénario 2 : Audit de Ségrégation Critique DMZ vers LAN (Anti-Rebond)

Ce test simule un attaquant ayant pris le contrôle du serveur Web Apache hébergé en DMZ Publique.

```bash
# Connecté sur la machine 172.16.100.80 (DMZ Publique) :
# 1. Tentative d'accès SSH vers le poste Administrateur
nc -zv -w 2 192.168.100.20 22

# 2. Tentative d'accès Web vers un équipement LAN
curl -I --connect-timeout 2 http://192.168.100.20
```

**Résultat dans les journaux OPNsense (*Firewall > Log Files > Live View*) :**
* Le pare-feu intercepte le paquet provenant de `172.16.100.80` à destination de `192.168.100.20`.
* La règle explicite `R3: bloquer DMZ->LAN (hors ping)` déclenche un `BLOCK` immédiat avec icône rouge.

---

### Scénario 3 : Validation du Proxy Squid & Règles de Filtrage

1. **Test d'interdiction de contournement :**
   ```bash
   # Sur PC Client (192.168.100.21) : tentative de requête directe sans renseigner le proxy
   curl -I --connect-timeout 3 http://example.com
   # Résultat : Échec (Timeout). Règle F5 bloque le port 80/443 direct.
   ```

2. **Test avec mandataire configuré (Squid) :**
   ```bash
   # En passant par le proxy OPNsense
   export http_proxy="http://192.168.100.254:3128"
   curl -I http://example.com
   # Résultat : HTTP/1.1 200 OK (généré via Squid)
   ```

3. **Test des domaines interdits (Blacklist R12) :**
   ```bash
   curl -I -x http://192.168.100.254:3128 http://www.facebook.com
   ```
   *Résultat :*
   ```http
   HTTP/1.1 403 Forbidden
   Server: squid
   Content-Type: text/html;charset=utf-8
   ```
   La page d'erreur standard Squid "Access Denied by Network Policy" s'affiche dans le navigateur du client.

---

## 🛠️ Diagnostics et Incidents Résolus pendant le Lab

1. **Incident de la passerelle WAN perdue en mode DHCP :**
   - *Symptôme :* En laissant l'interface `em0` (WAN) en DHCP, OPNsense perdait par intermittence sa route par défaut suite aux baux VMware.
   - *Résolution :* Fixation d'une IP Statique sur le WAN (`10.10.1.254/24`) avec définition explicite de la passerelle en amont (`10.10.1.2`).

2. **Échec de résolution DNS post-configuration statique :**
   - *Symptôme :* Message `"Host not found"` lors des tentatives de mise à jour des packages OPNsense.
   - *Résolution :* Ajout manuel des résolveurs de secours (`8.8.8.8` / `1.1.1.1`) dans *System > Settings > General*, tout en maintenant Unbound DNS pour le filtrage local.

