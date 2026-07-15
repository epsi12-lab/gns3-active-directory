<#
================================================================
 01-config-dc.ps1
 Configuration reseau de DC01, renommage, installation du role
 AD DS et promotion en controleur de domaine.

 A executer sur le futur controleur de domaine, en PowerShell
 administrateur. Le serveur redemarre a chaque etape marquee.
 Domaine : ad.epsilon-lab.fr  /  NetBIOS : EPSILON
================================================================
#>

# --- 1. Configuration reseau (IP statique) -------------------
# Le controleur de domaine DOIT avoir une IP fixe : il heberge
# le DNS du domaine, reference par tous les clients.

$iface = "Ethernet"

# Desactiver le DHCP avant de poser une adresse statique
# (les deux modes s'excluent mutuellement).
Set-NetIPInterface -InterfaceAlias $iface -Dhcp Disabled

# Nettoyer toute adresse residuelle (APIPA ou ancien bail).
Get-NetIPAddress -InterfaceAlias $iface -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

# Poser l'adresse statique dans le magasin persistant.
New-NetIPAddress -InterfaceAlias $iface `
    -IPAddress 10.10.30.10 -PrefixLength 24 -DefaultGateway 10.10.30.1 `
    -PolicyStore PersistentStore

# Le DNS pointe vers LUI-MEME : AD publie ses services (SRV)
# dans le DNS ; le DC doit donc s'interroger localement.
Set-DnsClientServerAddress -InterfaceAlias $iface -ServerAddresses 127.0.0.1

Get-NetIPConfiguration


# --- 2. Renommage (AVANT la promotion) -----------------------
# Renommer un DC apres promotion est risque (nom inscrit dans
# le DNS et la base AD). On le fait donc en amont.

Rename-Computer -NewName "DC01" -Restart
# >>> Le serveur redemarre. Reprendre au bloc 3 apres reconnexion.


# --- 3. Installation du role AD DS ---------------------------
# Installe les binaires du service d'annuaire + les outils.
# N'active pas encore le domaine.

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools


# --- 4. Promotion en controleur de domaine -------------------
# Cree la foret. Demande interactivement le mot de passe DSRM
# (Directory Services Restore Mode) : compte de secours pour
# restaurer un DC dont la base est corrompue. A CONSERVER.

Install-ADDSForest `
    -DomainName "ad.epsilon-lab.fr" `
    -DomainNetbiosName "EPSILON" `
    -InstallDns `
    -DomainMode "WinThreshold" `
    -ForestMode "WinThreshold"
# WinThreshold = niveau fonctionnel Windows Server 2016.
# >>> Le serveur redemarre automatiquement. Se reconnecter
#     ensuite en tant que EPSILON\Administrator.


# --- 5. Verifications (apres redemarrage) --------------------
Get-ADDomain
Get-ADForest
Get-SmbShare | Where-Object { $_.Name -in "SYSVOL","NETLOGON" }
nslookup -type=SRV _ldap._tcp.dc._msdcs.ad.epsilon-lab.fr