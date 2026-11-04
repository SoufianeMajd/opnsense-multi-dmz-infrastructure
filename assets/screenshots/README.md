# 📸 Galerie de Captures d'Écran & Preuves Visuelles

Ce dossier regroupe les captures d'écran attestant du bon fonctionnement, de la configuration et de la validation de l'infrastructure OPNsense.

---

## 📌 Liste des Captures Référencées

Pour alimenter ce dossier avec vos propres preuves visuelles, déposez vos captures d'écran en respectant la nomenclature suivante :

1. **`01_dashboard_opnsense.png`** :
   - Vue d'ensemble du Dashboard OPNsense (Lobby) montrant la version `OPNsense 25.7.10`, l'état `UP` des 4 interfaces (`WAN`, `LAN`, `OPT1`, `OPT2`), la charge CPU/RAM et les graphiques de trafic.
2. **`02_interfaces_assignment.png`** :
   - Page *Interfaces > Assignments* montrant la liaison des cartes physiques/virtuelles (`em0`, `em1`, `em2`, `em3`).
3. **`03_firewall_aliases.png`** :
   - Page *Firewall > Aliases* détaillant les objets créés (`ADMIN_IP`, `Web_DMZPUB`, `Tomcat_DMZPROD`, `DNS_VMware`, `PROXY_PORT`).
4. **`04_firewall_rules_lan.png`** :
   - Page *Firewall > Rules > LAN* avec les règles ordonnées (Priorité Admin, DNS interne, Proxy 3128, blocage HTTP/HTTPS direct).
5. **`05_firewall_rules_dmz_pub.png`** :
   - Page *Firewall > Rules > DMZ_PUB* montrant la règle critique de blocage vers le LAN.
6. **`06_firewall_rules_dmz_prod.png`** :
   - Page *Firewall > Rules > DMZ_PROD* montrant l'isolation du serveur Tomcat.
7. **`07_nat_port_forward.png`** :
   - Page *Firewall > NAT > Port Forward* illustrant la redirection du port 80 WAN vers le port 443 du serveur Web Apache.
8. **`08_squid_proxy_blacklist.png`** :
   - Page *Services > Web Proxy > Administration* avec la configuration de la blacklist (Facebook, Twitter/X, YouTube, WhatsApp).
9. **`09_squid_proxy_quota.png`** :
   - Page *Services > Web Proxy* avec la restriction de bande passante et le quota de téléchargement à 20 Mo.
10. **`10_validation_admin_ssh.png`** :
    - Terminal montrant la connexion SSH autorisée depuis le PC Admin (`192.168.100.20`) et refusée depuis le PC Client (`192.168.100.21`).
11. **`11_validation_web_apache.png`** :
    - Statut `systemctl status apache2` et affichage du portail Web dans le navigateur.
12. **`12_validation_app_tomcat.png`** :
    - Statut `systemctl status tomcat10` sur le port 8080.

