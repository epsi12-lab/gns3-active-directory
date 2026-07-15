<#
================================================================
 03-config-wks01.ps1
 Configuration reseau du poste client WKS01 et jonction au
 domaine ad.epsilon-lab.fr.

 A executer sur WKS01 en PowerShell administrateur.
================================================================
#>

$iface = "Ethernet"

# --- 1. Configuration reseau ---------------------------------
# Point CRITIQUE : le DNS du client pointe vers DC01 (10.10.30.10),
# PAS vers lui-meme, PAS vers un DNS public. Pour rejoindre le
# domaine, le client doit localiser le controleur via les
# enregistrements SRV publies dans le DNS de DC01. Un client sur
# un DNS externe ne trouvera jamais le domaine (erreur n.1 sur AD).

Set-NetIPInterface -InterfaceAlias $iface -Dhcp Disabled

Get-NetIPAddress -InterfaceAlias $iface -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress -InterfaceAlias $iface `
    -IPAddress 10.10.30.20 -PrefixLength 24 -DefaultGateway 10.10.30.1 `
    -PolicyStore PersistentStore

Set-DnsClientServerAddress -InterfaceAlias $iface -ServerAddresses 10.10.30.10

Get-NetIPConfiguration

# --- 2. Tests de resolution avant jonction -------------------
# Verifier que le client voit bien le domaine AVANT de tenter
# la jonction : le ping doit passer et le domaine doit resoudre.
Test-Connection 10.10.30.10 -Count 2
nslookup ad.epsilon-lab.fr

# --- 3. Jonction au domaine ----------------------------------
# Cree un objet ordinateur dans l'annuaire et etablit la
# relation d'approbation entre le poste et le controleur. Une
# fenetre demande les identifiants d'un compte autorise a
# joindre des machines (EPSILON\Administrator).

Add-Computer -DomainName "ad.epsilon-lab.fr" `
    -Credential "EPSILON\Administrator" -Restart
# >>> Le poste redemarre. Se connecter ensuite avec un compte
#     du domaine : "Other user" -> EPSILON\bruce.admin

# --- 4. Verification (apres redemarrage) ---------------------
# whoami                                  -> epsilon\bruce.admin
# (Get-WmiObject Win32_ComputerSystem).Domain        -> ad.epsilon-lab.fr
# (Get-WmiObject Win32_ComputerSystem).PartOfDomain  -> True