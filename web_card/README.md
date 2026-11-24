# Carte de membre Animora — page Web statique

Page autonome (HTML/CSS/JS, aucune dépendance) affichée quand on scanne le QR
de la carte de membre avec l’appareil photo de n’importe quel téléphone.

Fichiers à publier : `index.html`, `card.css`, `card.js`, `logo.png`.

## Comment ça marche

L’application génère une adresse de la forme :

```
https://<votre-site>/#eyJ2IjoxLCJmIjoiSW7DqHMi…
```

Tout ce qui suit `#` (le **fragment**) contient la carte encodée en base64url
(prénom, nom, profil, statut, n° de membre, date d’inscription, ville, URL de
l’avatar DiceBear). Le navigateur **n’envoie jamais le fragment au serveur** :
l’hébergeur ne voit que la demande de `index.html`. Aucun e-mail, téléphone,
identifiant interne, mot de passe ou jeton n’est dans le QR.

## Tester en local

```bash
cd web_card
python -m http.server 8000
```

Ouvrez `http://localhost:8000/#<payload>` (copiez l’URL depuis l’app :
Profil → Ma carte de membre → « Voir la carte Web »).

## Publier gratuitement — option A : Netlify (le plus rapide, 2 minutes)

1. Allez sur https://app.netlify.com/drop (connectez-vous avec GitHub ou un e-mail).
2. Glissez-déposez **le dossier `web_card`** dans la page.
3. Netlify donne une adresse du type `https://nom-aleatoire-123.netlify.app/`.
   (Optionnel : *Site configuration → Change site name* → `animora-carte`.)
4. Copiez cette adresse (avec le `/` final).

## Publier gratuitement — option B : GitHub Pages

1. Sur https://github.com/new, créez un dépôt **public** nommé `animora-carte`.
2. *Add file → Upload files* : déposez `index.html`, `card.css`, `card.js`, `logo.png`
   (le contenu du dossier, pas le dossier lui-même) → *Commit changes*.
3. *Settings → Pages* → *Source : Deploy from a branch* → branche `main`, dossier `/ (root)`
   → *Save*.
4. Après 1 à 2 minutes, l’adresse apparaît : `https://<votre-pseudo>.github.io/animora-carte/`.

## Brancher l’application

Dans `config/api-keys.json` :

```json
"MEMBER_CARD_BASE_URL": "https://<votre-pseudo>.github.io/animora-carte/"
```

Relancez l’app avec `--dart-define-from-file=config/api-keys.json` (configuration
VS Code « Animora (clés + comptes démo) »). Le QR de la carte contient alors l’URL ;
sans cette clé, l’app garde l’ancien QR (`ANIMORA|MEMBRE|ANI-…`).

## Limite (à dire en soutenance)

La page affiche « Carte de membre Animora — démonstration » : **elle ne peut pas
prouver qu’une carte est authentique**. Les données viennent du QR lui-même ;
n’importe qui pourrait fabriquer un lien avec un autre nom. Pour une vraie
vérification, il faudrait un serveur qui **signe** la carte (signature numérique,
ex. Ed25519, avec une clé privée gardée côté serveur) ou qui renvoie le statut à
jour à partir d’un identifiant opaque — et qui permette de révoquer une carte
(compte bloqué).
