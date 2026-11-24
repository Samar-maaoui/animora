# Animora — Validation de l’étape 7

## État initial

Avant modification, flutter analyze était propre et les 206 tests de l’étape 6 réussissaient. Une sauvegarde lib/test/pubspec/README a été conservée dans work/step7-before.

## Vérifications automatisées

- flutter pub get : réussi ; qr 3.0.3 passe de dépendance transitive à directe, sans nouveau paquet transitif.
- dart format . : exécuté sur le projet.
- flutter analyze : No issues found.
- flutter test : 256 tests réussis, aucun supprimé ou désactivé ; les 206 tests précédents restent réussis.
- Nouveaux tests : 34 tests métier et 16 tests d’interface, soit 50 au total.
- flutter build web --no-web-resources-cdn : réussi. La compilation JavaScript est la version vérifiée ; le mode Wasm n’a pas fait l’objet d’un parcours manuel.

La suite vérifie création/modification/publication, dates/coordonnées/capacité, inscriptions participants/bénévoles, refus des doublons, consentement à l’attente, promotion FIFO et comptes bloqués, billets privés/uniques, pointage au bon événement pendant ses horaires, double utilisation concurrente, activités, affectation et progression des tâches, publication des vrais compteurs de présence, photos de bilan, rechargement, données corrompues, rollback sur écriture échouée et changement de session pendant une attente. Sept routes ADMIN, les pages à 360 px et le changement direct d’identifiant entre deux événements (détails et formulaire) sont testés.

Les premiers échecs UI provenaient de l’attente de deux titres identiques « Accès refusé » et d’une animation de fermeture de message encore en cours au démontage. Les attentes ont été précisées et le module remplace immédiatement le message précédent ; aucun test n’a été retiré. Les erreurs métier initiales de copie des coordonnées numériques et de retour asynchrone ont été corrigées.

## Vérification Web réelle

Sur localhost:8765, avec les données fictives locales et un compte ADMIN existant : ouverture du catalogue, accès au tableau de bord, création d’un brouillon de capacité 1, publication après confirmation, consultation et inscription comme bénévole. L’inscription est CONFIRMED et un billet gratuit avec QR et code unique est affiché.

Après rechargement sur la même origine, l’inscription et le billet restent disponibles. Le billet présente l’événement fictif, le nom de démonstration, les horaires, le lieu, le type Bénévole et « Valide • non utilisé ». Le QR est produit localement. Capture : [billet Web](docs/screenshots/step7-events.jpg).

Un symbole non couvert par la police a été détecté entre les horaires sur la première capture. Les plages de dates utilisent désormais le texte « au » ; le code sélectionnable dispose aussi d’un libellé sémantique. Après cette correction, la suite complète réussit à nouveau (256 tests), l’analyse est propre et le build Web réussit. La capture finale renouvelée confirme les dates lisibles et le code présent dans l’arbre d’accessibilité.

Le pointage et la clôture après la fin ne sont pas forcés dans les données du navigateur : ils sont couverts par les tests avec horloge injectée. Aucun événement réel ni notification distante n’est créé.

## Préservation

Le logo officiel conserve le SHA-256 B5F45FACFFCC664D7BAD0A1552040ADB48C485F78F789D2A494528860A7D4A86. Le modèle User est identique à la sauvegarde (SHA-256 32EB964092F72DACE19B18588F1DFF84DD242D5047B0505C9F527B707B1481D1). Aucun modèle ni logique métier des animaux, adoptions, signalements, soins, gardes ou dons n’est modifié. L’authentification ajoute uniquement une lecture booléenne d’éligibilité pour les opérations événements ; les protections existantes restent appliquées.

## Limites de validation

Les tests à 360 px et le parcours Web sont réussis ; l’exécution sur appareil Android/iOS reste à réaliser. Le fond de carte OpenStreetMap en ligne et le décodage avec une caméra physique ne sont pas validés par ce parcours. Le QR utilise la bibliothèque qr et un code textuel reste disponible.

La persistance est locale, non chiffrée et sans synchronisation multiappareil. La sérialisation protège une instance d’application, sans garantie interprocessus. Les données Web dépendent du profil et de l’origine, et peuvent être effacées par le navigateur. Pas de notification externe, tâche de fond, API réelle ou autorisation serveur.

Le [guide](EVENTS_STEP_7.md) contient le scénario manuel complet et les règles. L’[inventaire](FILES_7.md) liste les fichiers. Aucune intégration backend ou nouvelle base distante n’est commencée.
