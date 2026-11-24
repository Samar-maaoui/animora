# Animora — Rapport des intégrations API, étape 9

## Bilan vérifié

Six enrichissements sont implémentés et raccordés aux écrans existants. Les tests automatiques passent : **339 réussis**, dont les **310 préexistants**. Trois intégrations ont reçu des réponses dans les services Flutter réels : Nominatim, taux et météo. REST Countries et les deux API de races attendent leurs clés. Overpass reste à confirmer depuis le service Flutter, malgré un diagnostic indépendant réussi. **La démonstration réelle de toutes les gestions n’est donc pas encore entièrement validée.**

SQLite reste v6 : aucune table, migration, classe de base ou modèle métier modifié. Logo officiel inchangé. Aucun repository métier remplacé, backend développé, paiement réel ou changement global de navigation.

| Gestion | API | Service / modèle | État réel |
|---|---|---|---|
| Utilisateurs | REST Countries v5 | [CountriesApi / CountryInfo](lib/features/users/services/countries_api.dart) | Clé absente ; appels réels non validés. |
| Adoptions | The Dog API / The Cat API | [BreedsApi / BreedInfo](lib/features/adoption/services/breeds_api.dart) | Deux clés absentes ; appels réels non validés. |
| Signalements | Nominatim OpenStreetMap | [GeocodingApi / ApproximateAddress](lib/features/reports/services/geocoding_api.dart) | Appel Flutter réel réussi : Tunis / Gouvernorat Tunis, Tunisie. |
| Vétérinaires / pet-sitting | Overpass OpenStreetMap | [ClinicsApi / ExternalClinic](lib/features/veterinary/services/clinics_api.dart) | HTTP indépendant : 200 et quatre établissements. Service Flutter : erreurs HTTP / timeouts ; démonstration réseau applicative à confirmer. |
| Dons | ExchangeRate-API | [ExchangeRatesApi / ExchangeRates](lib/features/donations/services/exchange_rates_api.dart) | Appel Flutter réel réussi ; taux datés reçus. |
| Événements | Open-Meteo | [WeatherApi / EventWeather](lib/features/events/services/weather_api.dart) | Appel Flutter réel réussi, fuseau Africa/Tunis et jour demandé. |

## Couche réseau, injection et états

ApiClient utilise http 1.6.0, HTTPS, JSON UTF-8, timeouts, erreurs HTTP et mutualisation des requêtes en cours. ApiScope possède et injecte le client ; les widgets ne font aucun appel HTTP direct. ApiPanel affiche chargement, succès, liste vide, erreur et Réessayer / Actualiser. Les réponses en cache et hors ligne portent une mention explicite et la date de réception.

Le cache persiste dans SharedPreferences sous animora.external.v1, sans toucher aux données métier : pays/races/géocodage 7 jours ; cliniques 1 heure ; taux 24 heures ; météo 1 heure. Les réponses anciennes utilisables hors ligne sont datées ; météo limitée à 6 heures. Une date fournisseur reste distincte de la date de réception. Les clés restent dans les headers, pas dans les URL ou le cache. Aucun taux ou résultat fictif ne remplace une réponse manquante. Les seuls accès externes préexistants étaient les tuiles OSM.

## 1. Utilisateurs — REST Countries v5

Choix international avec recherche, nom, ISO, drapeau emoji et indicatif. La Tunisie (+216) est un choix local par défaut explicitement étiqueté. Sans API, la saisie téléphonique manuelle reste disponible. Le pays ne crée pas de champ User supplémentaire ; il sert à formater le téléphone. Ce sélecteur n’est pas une bibliothèque complète de règles nationales de numérotation.

**Documentation officielle :** [REST Countries v5](https://restcountries.com/docs/countries).

**HTTP :** GET https://api.restcountries.com/countries/v5

**Paramètres :** limit=100, offset paginé, response_fields=names.common,codes.alpha_2,flag.emoji,calling_codes.

**Authentification :** Authorization: Bearer REST_COUNTRIES_KEY

**Modèle Dart :** CountryInfo. **Service :** [CountriesApi](lib/features/users/services/countries_api.dart). **Affichage :** RegisterScreen → AuthForm → CountryPicker.

**Exemple JSON : structure réduite utilisée pour expliquer le parsing ; les valeurs ci-dessous sont des fixtures, pas la preuve d’un appel réel.**

~~~json
{"data":{"objects":[{"names":{"common":"Tunisia"},"codes":{"alpha_2":"TN"},"flag":{"emoji":"🇹🇳"},"calling_codes":["216"]}]}}
~~~

**Tests :** countries_api_test.dart, api_widgets_test.dart.

**Démonstration au professeur :** Ouvrir /register, cliquer Choisir un pays, rechercher un pays et sélectionner son indicatif. Un numéro déjà international commençant par + est conservé.

**État et limites :** Clé absente ; appels réels non validés.

## 2. Adoptions — The Dog API / The Cat API

Race recherchable et caractéristiques disponibles : tempérament, origine, poids, longévité, description. La fiche cherche une correspondance exacte du nom local, sans deviner une traduction. La saisie manuelle reste possible pour les croisés ou sans API. Aucune photo animale et aucun score de compatibilité ne sont remplacés.

**Documentation officielle :** [The Dog API / The Cat API](https://docs.thedogapi.com/docs/examples/breeds).

**HTTP :** GET https://api.thedogapi.com/v1/breeds et https://api.thecatapi.com/v1/breeds

**Paramètres :** Liste de races ; recherche locale dans la liste réellement reçue. Pas de requête à chaque frappe..

**Authentification :** x-api-key: DOG_API_KEY ou CAT_API_KEY

**Modèle Dart :** BreedInfo. **Service :** [BreedsApi](lib/features/adoption/services/breeds_api.dart). **Affichage :** AnimalFormScreen et AnimalDetailsScreen → BreedInformation.

**Exemple JSON : structure réduite utilisée pour expliquer le parsing ; les valeurs ci-dessous sont des fixtures, pas la preuve d’un appel réel.**

~~~json
[{"id":1,"name":"Beagle","temperament":"Curious","life_span":"10 - 12","weight":{"metric":"3 - 6"}}]
~~~

**Tests :** breeds_api_test.dart, api_widgets_test.dart.

**Démonstration au professeur :** Administrateur → ajouter un animal → choisir Chien ou Chat → rechercher une race externe → choisir une race et lire ses caractéristiques. Dans une fiche animale, consulter Informations sur la race.

**État et limites :** Deux clés absentes ; appels réels non validés.

## 3. Signalements — Nominatim OpenStreetMap

Le clic GPS autorise aussi le géocodage annoncé dans l’interface. Les coordonnées sont arrondies avant transmission. Rue et numéro privé ne sont pas affichés ; la ville et la zone approximative restent informatives, non persistées dans le signalement. Cache et file séquentielle espacée d’au moins 1,1 seconde. Aucun autocomplete ni polling. Attribution OSM / ODbL. Un fournisseur HTTPS compatible peut être changé à l’exécution et conservé localement.

**Documentation officielle :** [Nominatim OpenStreetMap](https://nominatim.org/release-docs/latest/api/Reverse/).

**HTTP :** GET https://nominatim.openstreetmap.org/reverse

**Paramètres :** lat/lon arrondis à deux décimales ; format=jsonv2 ; zoom=12 ; addressdetails=1 ; accept-language=fr.

**Authentification :** Aucune clé. User-Agent AnimoraAcademic natif ; Referer du navigateur sur Web.

**Modèle Dart :** ApproximateAddress. **Service :** [GeocodingApi](lib/features/reports/services/geocoding_api.dart). **Affichage :** LocationFields dans les formulaires de signalement et annonce.

**Exemple JSON : structure réduite utilisée pour expliquer le parsing ; les valeurs ci-dessous sont des fixtures, pas la preuve d’un appel réel.**

~~~json
{"address":{"city":"Tunis","state":"Gouvernorat Tunis","country":"Tunisie"}}
~~~

**Tests :** geocoding_api_test.dart, api_widgets_test.dart ; anciens tests de localisation.

**Démonstration au professeur :** Ouvrir /reports/new, lire l’information d’envoi, cliquer Utiliser ma position GPS ; ou saisir 36.80 / 10.18 puis Rechercher / Réessayer la ville de ces coordonnées. Montrer la ville, puis continuer même sans réponse externe.

**État et limites :** Appel Flutter réel réussi : Tunis / Gouvernorat Tunis, Tunisie.

## 4. Vétérinaires / pet-sitting — Overpass OpenStreetMap

Position manuelle possible sans GPS. node utilise lat/lon ; way et relation utilisent center ; pas de carte sans coordonnées. Nom français accepté quand le champ name manque. Aucun User ni créneau créé, aucune réservation Animora auprès de ces établissements externes. Données OSM parfois incomplètes ; attribution ODbL. Un échec impose une pause de 30 secondes avant une nouvelle requête. Endpoint compatible configurable, sans basculement automatique en rafale.

**Documentation officielle :** [Overpass OpenStreetMap](https://wiki.openstreetmap.org/wiki/Overpass_API).

**HTTP :** GET https://overpass-api.de/api/interpreter

**Paramètres :** data=[out:json][timeout:20];nwr["amenity"="veterinary"](around:5000,36.80,10.18);out center; — rayon limité à 5 km.

**Authentification :** Aucune clé ; identification applicative native.

**Modèle Dart :** ExternalClinic. **Service :** [ClinicsApi](lib/features/veterinary/services/clinics_api.dart). **Affichage :** VeterinariansScreen → section dépliable NearbyClinics.

**Exemple JSON : structure réduite utilisée pour expliquer le parsing ; les valeurs ci-dessous sont des fixtures, pas la preuve d’un appel réel.**

~~~json
{"elements":[{"type":"node","id":1,"lat":36.8,"lon":10.18,"tags":{"amenity":"veterinary","name":"Clinique"}}]}
~~~

**Tests :** clinics_api_test.dart, api_widgets_test.dart.

**Démonstration au professeur :** Ouvrir /veterinary, déplier Cliniques vétérinaires à proximité — OSM, saisir une position ou utiliser le GPS, rechercher puis ouvrir une position sur la carte.

**État et limites :** HTTP indépendant : 200 et quatre établissements. Service Flutter : erreurs HTTP / timeouts ; démonstration réseau applicative à confirmer.

## 5. Dons — ExchangeRate-API

Contrôle du succès, de la base TND et des deux taux finis, positifs et présents. Conversion informative uniquement ; aucun changement du contrôleur TND ni du montant SQL. Cache quotidien de 24 heures ; données invalides non mises en cache. Attribution cliquable Rates By Exchange Rate API. Aucun paiement réel.

**Documentation officielle :** [ExchangeRate-API](https://www.exchangerate-api.com/docs/free).

**HTTP :** GET https://open.er-api.com/v6/latest/TND

**Paramètres :** Base TND ; extraction EUR et USD ; aucune requête supplémentaire lors de l’édition du montant..

**Authentification :** Aucune clé pour cet endpoint ouvert ; attribution obligatoire.

**Modèle Dart :** ExchangeRates. **Service :** [ExchangeRatesApi](lib/features/donations/services/exchange_rates_api.dart). **Affichage :** FinancialDonationScreen → CurrencyConversion.

**Exemple JSON : structure réduite utilisée pour expliquer le parsing ; les valeurs ci-dessous sont des fixtures, pas la preuve d’un appel réel.**

~~~json
{"result":"success","base_code":"TND","rates":{"EUR":0.3,"USD":0.32},"time_last_update_unix":1794268800}
~~~

**Tests :** exchange_rates_api_test.dart, api_transport_test.dart, api_widgets_test.dart.

**Démonstration au professeur :** Dans une campagne active, ouvrir la contribution financière, saisir 100 TND, consulter les équivalents puis modifier le montant. Montrer date des taux et source. Le don reste simulé et enregistré en TND.

**État et limites :** Appel Flutter réel réussi ; taux datés reçus.

## 6. Événements — Open-Meteo

Sélection de l’entrée daily.time correspondant exactement au jour de début de l’événement. Un événement passé n’affiche jamais la prévision actuelle comme historique. Hors horizon : message explicite, sans appel réseau ; coordonnées absentes et champs manquants traités. Cache 1 heure, secours hors ligne limité à 6 heures. Conseils pluie/chaleur/vent informatifs, sans valeur d’alerte officielle. Le modèle métier n’a pas de champ intérieur/extérieur : consultation facultative pour une sortie.

**Documentation officielle :** [Open-Meteo](https://open-meteo.com/en/docs).

**HTTP :** GET https://api.open-meteo.com/v1/forecast

**Paramètres :** latitude, longitude, timezone=auto, forecast_days=16 ; daily=temperature_2m_min,temperature_2m_max,precipitation_probability_max,precipitation_sum,wind_speed_10m_max,weather_code ; unités °C, mm, km/h.

**Authentification :** Aucune clé pour cet usage public non commercial ; attribution Open-Meteo / CC BY 4.0.

**Modèle Dart :** EventWeather. **Service :** [WeatherApi](lib/features/events/services/weather_api.dart). **Affichage :** EventDetailsScreen → EventWeatherPanel.

**Exemple JSON : structure réduite utilisée pour expliquer le parsing ; les valeurs ci-dessous sont des fixtures, pas la preuve d’un appel réel.**

~~~json
{"timezone":"Africa/Tunis","daily":{"time":["2026-11-10"],"temperature_2m_min":[20],"temperature_2m_max":[35],"precipitation_probability_max":[70],"precipitation_sum":[6],"wind_speed_10m_max":[45],"weather_code":[61]}}
~~~

**Tests :** weather_api_test.dart, api_widgets_test.dart ; timeout dans le transport commun.

**Démonstration au professeur :** Ouvrir un événement avec coordonnées dans les quinze prochains jours, consulter les prévisions, montrer date/fuseau, températures, pluie et vent. Ouvrir ensuite un événement éloigné : Prévisions pas encore disponibles.

**État et limites :** Appel Flutter réel réussi, fuseau Africa/Tunis et jour demandé.

## Conditions vérifiées et configuration

La [documentation REST Countries actuelle](https://restcountries.com/docs) et le [dépôt officiel](https://github.com/restcountries/restcountries/blob/master/README.md) indiquent le retrait des anciens endpoints hébergés. Le code utilise v5 et refuse une réponse de démonstration comme liste complète. Solution normale : obtenir une clé de développement auprès du fournisseur. Alternative autorisée : auto-héberger son ancien code MPL-2.0 officiel, désormais non maintenu ; cette mise en place n’a pas été réalisée et reste hors périmètre. Aucun contournement de clé ou d’abonnement.

La [documentation Cat](https://docs.thecatapi.com/docs/authorization) et [Dog](https://docs.thedogapi.com/docs/examples/breeds) demandent x-api-key. Les champs absents ne sont pas inventés. Les caractéristiques peuvent être en anglais ; une race locale sans correspondance exacte est conservée.

La [politique Nominatim](https://operations.osmfoundation.org/policies/nominatim/) impose identification, cache, attribution et quota. Le limiteur à 1,1 seconde est partagé dans un processus, pas entre plusieurs installations : pour diffuser largement, configurer un fournisseur dédié ou un service coordonnant le quota global. La démonstration actuelle reste à faible trafic. Le Web utilise son Referer réel, à vérifier sur l’origine d’hébergement. Le fournisseur de géocodage peut être changé à l’exécution via le formulaire. Pas de coordonnées privées précises envoyées.

Overpass public est sujet à surcharge. Le diagnostic GET indépendant a obtenu quatre résultats ; les services Flutter ont reçu 406/502 ou un timeout. L’instance alternative [Private.coffee répertoriée par OSM](https://wiki.openstreetmap.org/wiki/Overpass_API) a aussi expiré. Ne pas présenter ces tentatives comme une démonstration applicative réussie. Attendre au moins 30 secondes avant de réessayer. Les noms/positions ne garantissent pas ouverture ou disponibilité.

[Taux ouverts](https://www.exchangerate-api.com/docs/free) : attribution affichée, usage indicatif et cache quotidien ; ne pas redistribuer le flux. [Conditions Open-Meteo](https://open-meteo.com/en/terms) : usage non commercial pour l’endpoint public, attribution affichée ; revoir le contrat avant une diffusion commerciale. Les prévisions ne dépassent pas les jours réellement retournés.

Copier config/api-keys.example.json vers **config/api-keys.json**, ignoré par Git, et fournir uniquement des clés de développement autorisées : REST_COUNTRIES_KEY, DOG_API_KEY, CAT_API_KEY. NOMINATIM_ENDPOINT et OVERPASS_ENDPOINT permettent un fournisseur compatible autorisé.

~~~powershell
flutter run -d chrome --web-port=8765 --dart-define-from-file=config/api-keys.json
~~~

Autoriser l’origine Web chez REST Countries. Une clé embarquée dans une application Web/mobile reste récupérable : un fichier ignoré par Git ne protège pas un secret de production. Limiter quotas et origines, révoquer les clés compromises ; un proxy sécurisé serait à prévoir avant de diffuser avec des clés privées, hors de cette étape. Ne jamais publier le fichier de clés.

## Preuves, validation et plateformes

Voir [VALIDATION_9.md](VALIDATION_9.md), [FILES_9.md](FILES_9.md) et [output/api/live-results.json](output/api/live-results.json). Les tests automatiques utilisent MockClient ; ils ne prouvent pas des appels réels. Les exemples JSON de ce rapport sont explicitement des fixtures ; les résultats réellement reçus sont dans les fichiers de preuve séparés.

~~~powershell
flutter test tool/api_smoke_test.dart
# Avec les clés locales :
flutter test --dart-define-from-file=config/api-keys.json tool/api_smoke_test.dart
~~~

Le test smoke réussit quand il produit un rapport ; il **ne certifie pas que chaque API a réussi**. Examiner chaque status. Les appels réels ont été exécutés depuis Flutter VM, pas depuis une session Chrome déployée. La compilation Web et les interactions widget sont vérifiées ; CORS, clés et permissions réelles sont à confirmer sur l’origine et l’appareil de démonstration.

Android possède les permissions Internet et localisation. Les textes de permissions iOS étaient imbriqués dans la configuration de scènes : ils ont été déplacés à la racine de Info.plist et le fichier est vérifié par plistlib. SDK Android absent et Windows sans Xcode : aucune compilation ou exécution Android/iOS validée. Aucun début d’étape 10.

Les anciens tests, données locales, interfaces métier, logo et charte sont conservés. Attendre la validation utilisateur avant la suite.
