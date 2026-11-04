#!/bin/bash
# ==============================================================================
# Script de Déploiement Rapide des Services DMZ (Apache2 & Tomcat10)
# Auteur : Soufiane MAJD (https://github.com/SoufianeMajd)
# ==============================================================================

set -e

echo "=== DÉPLOIEMENT DES SERVICES APPLICATIFS EN DMZ ==="

# 1. Vérification du rôle de la machine
if [ "$1" == "web" ]; then
    echo "[+] Configuration du Serveur Web Apache (DMZ Publique - 172.16.100.80)"
    sudo apt-get update -y
    sudo apt-get install -y apache2 ssl-cert
    sudo a2enmod ssl rewrite headers
    sudo cp ../configs/dmz_web/apache_virtualhost.conf /etc/apache2/sites-available/dmz_web.conf
    sudo a2ensite dmz_web.conf
    sudo a2dissite 000-default.conf
    echo "<h1>Bienvenue sur le portail Web securise (DMZ Publique)</h1>" | sudo tee /var/www/html/index.html
    sudo systemctl restart apache2
    echo "[OK] Apache2 operationnel sur les ports 80 et 443."

elif [ "$1" == "tomcat" ]; then
    echo "[+] Configuration du Serveur Tomcat (DMZ Production - 172.16.200.80)"
    sudo apt-get update -y
    sudo apt-get install -y default-jdk tomcat10
    sudo cp ../configs/dmz_prod/server.xml /etc/tomcat10/server.xml
    sudo systemctl restart tomcat10
    echo "[OK] Tomcat 10 operationnel sur le port 8080."

else
    echo "Usage: $0 [web|tomcat]"
    echo "  web    : Installe et configure Apache2 (DMZ Publique)"
    echo "  tomcat : Installe et configure Tomcat10 (DMZ Production)"
    exit 1
fi

