<#
================================================================
 02-setup-annuaire.ps1
 Structure d'annuaire (OU), groupes de securite et utilisateurs.

 A executer sur DC01 en PowerShell administrateur, apres la
 promotion en controleur de domaine.

 Note : Windows bloque par defaut l'execution de scripts. Lever
 la restriction pour la session courante uniquement (plus prudent
 qu'une modification permanente) :
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
================================================================
#>

$dn = "DC=ad,DC=epsilon-lab,DC=fr"

# --- 1. Arborescence d'unites d'organisation -----------------
# On n'utilise JAMAIS les conteneurs par defaut (CN=Users,
# CN=Computers) : ce ne sont pas des OU, on ne peut pas leur
# lier de GPO. Toute la structure est donc creee explicitement.

New-ADOrganizationalUnit -Name "EPSILON" -Path $dn -ProtectedFromAccidentalDeletion $true
$root = "OU=EPSILON,$dn"

New-ADOrganizationalUnit -Name "Utilisateurs" -Path $root -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Groupes"      -Path $root -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Ordinateurs"  -Path $root -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Serveurs"     -Path $root -ProtectedFromAccidentalDeletion $true

$users = "OU=Utilisateurs,$root"
New-ADOrganizationalUnit -Name "IT"         -Path $users -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "RH"         -Path $users -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Commercial" -Path $users -ProtectedFromAccidentalDeletion $true

# --- 2. Groupes de securite globaux --------------------------
# Convention : prefixe GG = Global Group. Une nomenclature
# stricte rend les droits lisibles et auditables.

$ouGroupes = "OU=Groupes,$root"
New-ADGroup -Name "GG_IT_Admins"        -GroupScope Global -GroupCategory Security -Path $ouGroupes -Description "Administrateurs IT"
New-ADGroup -Name "GG_RH_Users"         -GroupScope Global -GroupCategory Security -Path $ouGroupes -Description "Utilisateurs RH"
New-ADGroup -Name "GG_Commercial_Users" -GroupScope Global -GroupCategory Security -Path $ouGroupes -Description "Utilisateurs Commercial"

# --- 3. Utilisateurs -----------------------------------------
# bruce.admin est un compte d'ADMINISTRATION distinct du compte
# quotidien : recommandation ANSSI centrale (ne jamais naviguer
# ou lire ses mails avec un compte a privileges).

$pwd = ConvertTo-SecureString "Epsilon2026!" -AsPlainText -Force

New-ADUser -Name "Bruce Admin" -GivenName "Bruce" -Surname "Admin" `
    -SamAccountName "bruce.admin" -UserPrincipalName "bruce.admin@ad.epsilon-lab.fr" `
    -Path "OU=IT,$users" -AccountPassword $pwd -Enabled $true `
    -Description "Compte d'administration"

New-ADUser -Name "Marie Dupont" -GivenName "Marie" -Surname "Dupont" `
    -SamAccountName "marie.dupont" -UserPrincipalName "marie.dupont@ad.epsilon-lab.fr" `
    -Path "OU=RH,$users" -AccountPassword $pwd -Enabled $true

New-ADUser -Name "Jean Martin" -GivenName "Jean" -Surname "Martin" `
    -SamAccountName "jean.martin" -UserPrincipalName "jean.martin@ad.epsilon-lab.fr" `
    -Path "OU=Commercial,$users" -AccountPassword $pwd -Enabled $true

New-ADUser -Name "Sophie Leroy" -GivenName "Sophie" -Surname "Leroy" `
    -SamAccountName "sophie.leroy" -UserPrincipalName "sophie.leroy@ad.epsilon-lab.fr" `
    -Path "OU=Commercial,$users" -AccountPassword $pwd -Enabled $true

# --- 4. Affectation aux groupes ------------------------------
Add-ADGroupMember -Identity "GG_IT_Admins"        -Members "bruce.admin"
Add-ADGroupMember -Identity "GG_RH_Users"         -Members "marie.dupont"
Add-ADGroupMember -Identity "GG_Commercial_Users" -Members "jean.martin","sophie.leroy"

# --- 5. Verifications ----------------------------------------
Get-ADUser  -Filter * -SearchBase $root | Select-Object Name, SamAccountName
Get-ADGroup -Filter * -SearchBase $ouGroupes | Select-Object Name, GroupScope
Get-ADGroupMember "GG_Commercial_Users" | Select-Object Name

Write-Host "=== Annuaire cree ===" -ForegroundColor Green