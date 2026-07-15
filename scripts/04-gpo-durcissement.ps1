<#
================================================================
 04-gpo-durcissement.ps1
 Durcissement du domaine par strategies de groupe, aligne sur
 les recommandations ANSSI :
   - politique de mot de passe
   - GPO de restriction des utilisateurs (avec exclusion admins)
   - GPO d'audit des connexions

 A executer sur DC01 en PowerShell administrateur.

 IMPORTANT : la partie PowerShell couvre la politique de mot de
 passe et l'audit. Les restrictions d'interface (Panneau de
 configuration, invite de commandes, registre) reposent sur des
 templates administratifs qui se configurent via la GPMC ; les
 etapes graphiques sont documentees en commentaire (bloc 2).
================================================================
#>

# ============================================================
#  1. POLITIQUE DE MOT DE PASSE (ANSSI)
# ============================================================
# S'applique au domaine entier via la Default Domain Policy.

Set-ADDefaultDomainPasswordPolicy -Identity "ad.epsilon-lab.fr" `
    -MinPasswordLength 12 `          # longueur mini (resistance au cassage hors ligne)
    -PasswordHistoryCount 24 `       # empeche la reutilisation cyclique
    -MaxPasswordAge "90.00:00:00" `  # expiration 90 j (fenetre d'exploitation limitee)
    -MinPasswordAge "1.00:00:00" `   # empeche de contourner l'historique
    -ComplexityEnabled $true `       # 3 des 4 categories (maj/min/chiffre/special)
    -LockoutThreshold 5 `            # verrouillage apres 5 echecs -> ANTI BRUTE-FORCE
    -LockoutDuration "00:30:00" `    # verrouille 30 min
    -LockoutObservationWindow "00:30:00"

# ReversibleEncryption reste a False (jamais de stockage
# reversible des mots de passe) - valeur par defaut, verifiee.

Get-ADDefaultDomainPasswordPolicy


# ============================================================
#  2. GPO DE RESTRICTION DES UTILISATEURS
# ============================================================
# Creation et liaison a l'OU Utilisateurs :

New-GPO -Name "GPO_Restrictions_Utilisateurs" | `
    New-GPLink -Target "OU=Utilisateurs,OU=EPSILON,DC=ad,DC=epsilon-lab,DC=fr"

# --- Reglages a activer dans la GPMC (Edit) ------------------
# User Configuration > Policies > Administrative Templates
#   Control Panel
#     "Prohibit access to Control Panel and PC settings"  -> Enabled
#   System
#     "Prevent access to the command prompt"              -> Enabled
#     "Prevent access to registry editing tools"          -> Enabled
#
# --- Exclusion des administrateurs IT -----------------------
# But : appliquer la restriction a TOUS sauf aux admins, pour
# demontrer un comportement differencie sur le meme poste.
#
# GPMC > GPO_Restrictions_Utilisateurs > onglet Delegation >
#   Advanced > ajouter GG_IT_Admins >
#   permission "Apply group policy" = DENY (coche)
#
# Un Deny explicite prime toujours sur un Allow : les membres
# de GG_IT_Admins echappent donc a la GPO.
#
# Equivalent PowerShell de l'exclusion (au lieu du clic GPMC) :
#   Set-GPPermission -Name "GPO_Restrictions_Utilisateurs" `
#     -TargetName "GG_IT_Admins" -TargetType Group `
#     -PermissionLevel None -Replace
# (retire le groupe du filtrage ; pour un Deny strict, passer
#  par la delegation avancee de la GPMC.)


# ============================================================
#  3. GPO D'AUDIT DES CONNEXIONS
# ============================================================
# Liee au domaine entier : l'audit doit couvrir toutes les
# machines, pas un seul departement.

New-GPO -Name "GPO_Audit_Connexions" | `
    New-GPLink -Target "DC=ad,DC=epsilon-lab,DC=fr"

# --- Reglages a activer dans la GPMC (Edit) ------------------
# Computer Configuration > Policies > Windows Settings >
#   Security Settings > Advanced Audit Policy Configuration >
#   Audit Policies
#     Logon/Logoff > Audit Logon   -> Success and Failure
#     Logon/Logoff > Audit Logoff  -> Success and Failure
#
# Evenements generes :
#   4624 = connexion reussie   (qui, quand, d'ou)
#   4625 = connexion echouee   -> signature de brute-force
#   4634 = deconnexion
#
# Les echecs de comptes de domaine sont journalises sur le DC
# (c'est lui qui valide via Kerberos), pas sur le poste client.

# Appliquer immediatement :
gpupdate /force

# Verifier l'etat effectif de l'audit :
auditpol /get /category:"Logon/Logoff"


# ============================================================
#  4. TEST DE L'AUDIT (generer puis retrouver un 4625)
# ============================================================
# Provoquer un echec volontaire :
#   $cred = Get-Credential   # EPSILON\marie.dupont + MAUVAIS mot de passe
#   Start-Process notepad.exe -Credential $cred
#
# Retrouver l'evenement :
#   Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625} `
#     -MaxEvents 5 | Format-List TimeCreated, Message