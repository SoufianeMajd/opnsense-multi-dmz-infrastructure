#!/bin/bash
# ==============================================================================
# Script d'Audit et de Recette Automatisée des Flux Multi-DMZ (OPNsense)
# Auteur : Soufiane MAJD (https://github.com/SoufianeMajd)
# ==============================================================================

# Codes de couleur pour l'affichage console
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}   AUDIT AUTOMATISÉ DE LA POLITIQUE PARE-FEU MULTI-DMZ (OPNSENSE)     ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# Variables de l'environnement de test
FW_LAN_IP="192.168.100.254"
DNS_VMWARE="10.10.1.2"
SRV_WEB_IP="172.16.100.80"
SRV_TOMCAT_IP="172.16.200.80"
PROXY_PORT="3128"

TEST_PASSED=0
TEST_FAILED=0

run_test() {
    local test_id="$1"
    local desc="$2"
    local expected="$3"
    local cmd="$4"

    echo -e "\n${YELLOW}[$test_id] $desc${NC}"
    eval "$cmd" > /dev/null 2>&1
    local ret=$?

    if [ "$expected" == "SUCCESS" ]; then
        if [ $ret -eq 0 ]; then
            echo -e "${GREEN}  -> CONFORME (Flux autorisé comme attendu)${NC}"
            ((TEST_PASSED++))
        else
            echo -e "${RED}  -> NON CONFORME (Le flux aurait dû être autorisé)${NC}"
            ((TEST_FAILED++))
        fi
    elif [ "$expected" == "BLOCKED" ]; then
        if [ $ret -ne 0 ]; then
            echo -e "${GREEN}  -> CONFORME (Flux bloqué par le pare-feu comme attendu)${NC}"
            ((TEST_PASSED++))
        else
            echo -e "${RED}  -> ALERTE SÉCURITÉ : Le flux n'a pas été bloqué !${NC}"
            ((TEST_FAILED++))
        fi
    fi
}

# 1. Tests d'Administration et Gestion (R9)
run_test "T01" "Accès SSH Administration Pare-feu ($FW_LAN_IP:22)" "SUCCESS" \
    "nc -z -w 2 $FW_LAN_IP 22"

# 2. Tests DNS Centralisé (R5)
run_test "T02" "Résolution DNS vers le serveur VMware autorisé ($DNS_VMWARE:53)" "SUCCESS" \
    "nc -z -u -w 2 $DNS_VMWARE 53"

run_test "T03" "Anti-contournement DNS vers résolveur externe (8.8.8.8:53)" "BLOCKED" \
    "nc -z -u -w 2 8.8.8.8 53"

# 3. Accès aux Services DMZ depuis le LAN (R2 & R8)
run_test "T04" "Accès Intranet au Serveur Web Apache ($SRV_WEB_IP:80)" "SUCCESS" \
    "curl -s --connect-timeout 2 -I http://$SRV_WEB_IP"

run_test "T05" "Accès à l'application Métier Tomcat ($SRV_TOMCAT_IP:8080)" "SUCCESS" \
    "curl -s --connect-timeout 2 -I http://$SRV_TOMCAT_IP:8080"

# 4. Forçage du Proxy Web Squid (R10)
run_test "T06" "Blocage navigation Web directe sans proxy vers l'extérieur" "BLOCKED" \
    "curl -s --connect-timeout 2 -I http://1.1.1.1"

run_test "T07" "Disponibilité du Proxy Web Squid ($FW_LAN_IP:$PROXY_PORT)" "SUCCESS" \
    "nc -z -w 2 $FW_LAN_IP $PROXY_PORT"

# 5. Filtrage d'URL & Blacklist Proxy (R12)
run_test "T08" "Filtrage URL Blacklist Proxy (Blocage Facebook)" "BLOCKED" \
    "curl -s --connect-timeout 3 -x http://$FW_LAN_IP:$PROXY_PORT http://www.facebook.com -f"

# 6. Diagnostics ICMP Ping (R6)
run_test "T09" "Ping de diagnostic LAN vers DMZ Publique ($SRV_WEB_IP)" "SUCCESS" \
    "ping -c 2 -W 2 $SRV_WEB_IP"

run_test "T10" "Blocage Ping vers Internet (Anti-fingerprinting)" "BLOCKED" \
    "ping -c 2 -W 2 8.8.8.8"

echo -e "\n${BLUE}======================================================================${NC}"
echo -e "${BLUE}                     RÉSUMÉ DE L'AUDIT TECHNIQUE                      ${NC}"
echo -e "${BLUE}======================================================================${NC}"
echo -e "Tests Réussis / Conformes : ${GREEN}$TEST_PASSED${NC}"
echo -e "Tests Échoués / Alertes   : ${RED}$TEST_FAILED${NC}"
echo -e "${BLUE}======================================================================${NC}"

if [ $TEST_FAILED -eq 0 ]; then
    echo -e "${GREEN}FÉLICITATIONS : L'infrastructure respecte 100% de la politique de sécurité.${NC}"
    exit 0
else
    echo -e "${RED}ATTENTION : Des écarts ont été détectés avec la politique de filtrage.${NC}"
    exit 1
fi

