# Plan d'adressage — Projet A2

## Domaine

| Paramètre | Valeur |
|---|---|
| Domaine (FQDN) | `ad.epsilon-lab.fr` |
| Nom NetBIOS | `EPSILON` |
| Niveau fonctionnel forêt/domaine | Windows Server 2016 (WinThreshold) |

## Machines

| Machine | Rôle | IP | Masque | Passerelle | DNS |
|---|---|---|---|---|---|
| **DC01** | Contrôleur de domaine + DNS | `10.10.30.10` | /24 | `10.10.30.1` | `127.0.0.1` |
| **WKS01** | Poste client (membre) | `10.10.30.20` | /24 | `10.10.30.1` | `10.10.30.10` |

## Réseau

| Élément | Valeur |
|---|---|
| Segment (VLAN Serveurs) | `10.10.30.0/24` |
| Domaine de diffusion | Switch-Serveurs (L2 unique) |

## Points de conception

- **DC01 est son propre serveur DNS** (`127.0.0.1`) : Active Directory publie
  ses services via des enregistrements SRV dans le DNS. Le contrôleur doit donc
  s'interroger lui-même.
- **WKS01 utilise DC01 comme DNS** (`10.10.30.10`) : sans cela, le client ne peut
  pas localiser le domaine pour le rejoindre.
- **Adressage cohérent avec le projet A1** : le VLAN Serveurs `10.10.30.0/24`
  correspond au segment Serveurs de l'infrastructure réseau A1. Les deux labs
  sont conçus pour s'intégrer.
- **Topologie volontairement minimale** : un DC et un client suffisent à démontrer
  l'annuaire, les GPO et l'audit. En production, on ajouterait un second contrôleur
  pour la redondance.