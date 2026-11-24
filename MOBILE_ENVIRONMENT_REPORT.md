# Animora — Diagnostic de l’environnement mobile, étape 10A

Diagnostic effectué le 10 novembre 2026 depuis Windows. Aucune installation, acceptation de licence, modification de configuration Flutter/Java/SDK ou modification des sources du projet n’a été effectuée. Seul ce rapport est ajouté.

## Conclusion

**Android : compilation actuellement bloquée par l’environnement**, principalement l’absence de SDK Android détectable. Java existe déjà mais n’est pas configuré dans le terminal ou Flutter. Android Studio, ADB et les émulateurs ne sont pas détectés dans les emplacements vérifiés.

**iPhone : les fichiers iOS existent mais la compilation native nécessite un Mac avec Xcode.** Aucune compilation iOS tentée sous Windows et aucune signature Apple modifiée.

Aucun APK n’a été compilé pendant ce diagnostic, les prérequis Android étant absents. Les 339 tests et le build Web de l’étape 9 ne constituent pas une validation Android/iOS.

## 1. Flutter, Dart et commandes exécutées

| Vérification | Résultat observé |
| --- | --- |
| flutter doctor -v | Flutter stable 3.47.5, révision 6a19cca564 ; Android SDK introuvable |
| Dart | 3.13.4 ; DevTools 2.60.0 |
| where.exe flutter | C:\flutter\bin\flutter et C:\flutter\bin\flutter.bat, même SDK |
| flutter devices | Windows, Chrome et Edge ; aucun téléphone Android ou iPhone détecté comme cible Flutter |
| flutter emulators | Aucun fournisseur/source d’émulateur trouvé |
| java -version | Commande non reconnue dans le PATH du terminal |
| adb version | Non exécutée : adb absent du PATH et aucun platform-tools trouvé dans les SDK usuels |
| flutter config --list | Aucun jdk-dir/android-sdk personnalisé affiché ; SwiftPM non fixé explicitement |
| Système | Windows 11, version 10.0.26300.9818 |

flutter doctor signale aussi des composants C++ Visual Studio manquants : ils concernent la cible **Windows desktop**, pas la compilation Android ou iOS. Ne pas les installer uniquement pour tester sur téléphone.

Les contrôles ont inclus les chemins Windows réels, après constat que LOCALAPPDATA est virtualisé dans le sandbox de Codex. Les conclusions ne reposent donc pas uniquement sur cette variable virtualisée.

## 2. Java : déjà présent, à configurer

Les exécutables suivants ont été lancés directement avec -version :

| JDK trouvé | Version réelle |
| --- | --- |
| C:\Users\Lenovo\.jdks\jbr-17.0.12 | OpenJDK JBR 17.0.12 |
| C:\Users\Lenovo\.jdks\jbr-17.0.14 | OpenJDK JBR 17.0.14 |
| C:\Users\Lenovo\.jdks\ms-21.0.10 | Microsoft OpenJDK 21.0.10 LTS |

JAVA_HOME, ANDROID_HOME et ANDROID_SDK_ROOT sont vides dans les portées processus, utilisateur et machine consultées. Java absent du PATH **ne signifie donc pas Java absent de l’ordinateur**.

Pour limiter les installations, le JDK 17.0.14 existant peut servir de premier choix explicite pour cette configuration Java 17. Aucun nouveau JDK n’est nécessaire au stade du diagnostic. Android Studio fournit également son propre runtime si la voie Studio est choisie.

## 3. Android Studio, SDK, outils, licences et émulateur

Android Studio n’est pas détecté par Flutter, ni dans les dossiers usuels inspectés, ni dans les entrées de désinstallation consultées. Deux installations IntelliJ IDEA sont présentes ; elles ne remplacent pas à elles seules un SDK Android configuré.

SDK absent notamment de :
- C:\Users\Lenovo\AppData\Local\Android\Sdk ;
- C:\Program Files\Android\Android Studio ;
- C:\Users\Lenovo\AppData\Local\Programs\Android Studio ;
- C:\Android, C:\Android\Sdk, C:\android-sdk ;
- C:\Users\Lenovo\Android\Sdk.

Une installation dans un autre emplacement personnalisé reste possible mais n’est pas connue des outils. Si un tel dossier existe ailleurs, le réutiliser après vérification plutôt qu’installer un deuxième SDK.

| Élément | État |
| --- | --- |
| SDK Platforms | Aucun SDK détecté : plateformes non disponibles pour cette compilation |
| Platform-Tools / adb | Non détectés |
| Build-Tools | Non détectés dans les SDK vérifiés |
| Command-line Tools / sdkmanager | Non détectés dans les SDK vérifiés |
| NDK / CMake Android | Non détectés dans les SDK vérifiés |
| Licences Android | **État non vérifiable sans SDK**, et non « licences refusées » |
| AVD / image système | Aucun AVD détecté ; .android contient cache et analytics, pas de répertoire avd observé |
| Téléphone Android connecté | Aucun dans flutter devices |

Aucune commande d’acceptation des licences n’a été lancée.

## 4. Configuration Android du projet

Les fichiers android/settings.gradle.kts, build.gradle.kts, app/build.gradle.kts, gradle.properties, les manifests, le wrapper Gradle et MainActivity.kt sont présents.

| Paramètre | Valeur constatée |
| --- | --- |
| Android Gradle Plugin | 9.1.0 |
| Gradle wrapper | 9.3.1, distribution déjà présente dans le cache utilisateur |
| Kotlin déclaré | 2.4.0 |
| Java source/cible et Kotlin JVM | 17 |
| compileSdk / targetSdk | 36, résolus dans le SDK Flutter installé |
| minSdk | 24 : Android 7.0 minimum pour cette configuration |
| NDK demandé par Flutter | 28.2.13676358 |
| namespace / applicationId | com.example.animora |
| AndroidX | activé |
| Compatibilité AGP 9 | android.newDsl=false et android.builtInKotlin=false présents |
| local.properties | flutter.sdk=C:\flutter ; pas de sdk.dir |
| Signature release | utilise encore la signature debug du template |

Le SDK Flutter local définit ces niveaux dans FlutterExtension.kt ; ils ne sont pas déduits d’une version générique de documentation. La combinaison AGP 9.1 / Gradle 9.3.1 / Java 17 est cohérente avec les [exigences Android publiées](https://developer.android.com/build/releases/agp-9-1-0-release-notes). Cela ne prouve pas encore que tous les plugins compileront.

MainActivity est une FlutterActivity et son package concorde avec com.example.animora. Le plugin Kotlin externe est déclaré dans settings ; le code Gradle de ce Flutter prévoit son application lorsque le Kotlin intégré est désactivé. Ne pas modifier ces options sur la seule base d’un template d’une autre version.

**Plateformes SDK supplémentaires repérées dans les dépendances :**
- printing 5.15.1 compile son module Android avec SDK 34 ;
- jni_flutter 1.0.4+1 compile avec SDK 35 ;
- l’application et plusieurs autres plugins utilisent le SDK 36.

Ces versions de plateformes peuvent coexister. Les installer évite que Gradle tente de les télécharger au premier build ; ne pas modifier les plugins pour supprimer leurs exigences. Les licences et d’autres composants précis seront définitivement confirmés par le premier build.

La signature debug suffit pour un premier APK de test. Une signature de distribution et un identifiant définitif seront à préparer séparément ; rien n’a été changé ici.

### Permissions Android

Le manifest principal contient :
- INTERNET ;
- ACCESS_COARSE_LOCATION ;
- ACCESS_FINE_LOCATION.

Le service de localisation existant vérifie le service GPS, demande l’autorisation à l’exécution et gère le refus. Il effectue une localisation à la demande ; aucun suivi en arrière-plan n’a été repéré. Ne pas ajouter de permission de localisation en arrière-plan pour ce besoin.

Les appels HTTP et les tuiles cartographiques utilisent HTTPS ; aucune exception générale de trafic HTTP en clair n’est nécessaire pour les endpoints actuels.

## 5. Installations Android minimales, à effectuer seulement après validation

### Voie recommandée avec Android Studio, en gardant VS Code

1. Installer [Android Studio stable depuis Google](https://developer.android.com/studio). Il peut servir uniquement au SDK Manager et au Device Manager ; continuer à coder dans VS Code.
2. Dans SDK Manager, choisir un seul dossier SDK, par exemple C:\Users\Lenovo\AppData\Local\Android\Sdk.
3. Installer :
   - Android SDK Command-line Tools (latest) ;
   - Android SDK Platform-Tools ;
   - SDK Platforms Android API 36, 35 et 34, pour les modules inspectés ;
   - Android SDK Build-Tools 36.0.0 pour AGP 9.1 ;
   - NDK (Side by side) 28.2.13676358, demandé par Flutter.
4. CMake figure dans la liste d’outils recommandés par Flutter. Aucun numéro de CMake n’est fixé dans l’application : ne pas choisir arbitrairement une version ancienne. L’ajouter via SDK Manager si le contrôle de l’outillage ou la compilation des dépendances natives/JNI le demande.
5. Configurer Flutter pour le SDK et le JDK **existants**, puis revoir les licences.

Commandes futures, **non exécutées** :

~~~powershell
flutter config --jdk-dir="C:\Users\Lenovo\.jdks\jbr-17.0.14"
flutter config --android-sdk="C:\Users\Lenovo\AppData\Local\Android\Sdk"

# Facultatif pour rendre java disponible dans ce terminal seulement :
$env:JAVA_HOME = "C:\Users\Lenovo\.jdks\jbr-17.0.14"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

flutter doctor --android-licenses
flutter doctor -v
~~~

Lire les licences avant de les accepter ; aucune acceptation automatique n’est proposée.

Les mêmes paquets peuvent être installés avec sdkmanager si l’on choisit une installation sans Studio. Studio n’est pas indispensable au moteur Flutter ; dans ce cas il faut installer les Command-line Tools Google et organiser leur dossier correctement. Le choix d’une seule voie évite les doublons.

Liste sdkmanager correspondante, à utiliser seulement après installation et validation de l’outil :

~~~powershell
sdkmanager --sdk_root="C:\Users\Lenovo\AppData\Local\Android\Sdk" "platform-tools" "platforms;android-36" "platforms;android-35" "platforms;android-34" "build-tools;36.0.0" "ndk;28.2.13676358"
~~~

Ne pas réinstaller Flutter, Dart, un Gradle global ou un nouveau JDK par défaut. Le wrapper Gradle du projet gère sa version.

### Téléphone Android ou émulateur : choisir selon le besoin

**Téléphone physique :** pas d’émulateur ni d’image système à installer. Activer Options développeur et Débogage USB, connecter par câble de données, autoriser l’ordinateur. Installer un pilote USB du constructeur seulement si Windows ne reconnaît pas l’appareil.

**Émulateur, facultatif :** installer Android Emulator et une image système correspondant à l’architecture de l’ordinateur, puis créer un AVD dans Device Manager. Vérifier la virtualisation matérielle et l’hyperviseur Windows si l’accélération échoue ; leur état n’a pas été validé ici. Aucun HAXM ou autre hyperviseur n’a été installé.

### Première validation, après installation autorisée

~~~powershell
flutter devices
flutter emulators
& "C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe" version
flutter build apk --debug
flutter run -d <identifiant-android>
~~~

Avec les clés API locales, ajouter --dart-define-from-file=config/api-keys.json à la compilation/exécution. Leur absence n’empêche pas de compiler, mais bloque les enrichissements API correspondants.

Le premier lancement devra vérifier : SQLite natif et persistance après redémarrage, GPS accordé/refusé, photos, liens externes, reçus PDF, API et cartes. **Aucune de ces validations sur appareil n’a été réalisée pendant ce diagnostic.**

## 6. Préparation iOS existante

- Runner.xcodeproj, Runner.xcworkspace, Runner.xcscheme, AppDelegate.swift et SceneDelegate.swift présents.
- Déploiement iOS 15.0 dans les configurations Xcode inspectées.
- Swift 5.0 dans le projet ; plusieurs plugins utilisent des manifestes Swift tools 5.9 : prévoir un Xcode compatible avec ces dépendances et avec la version iOS réelle de l’iPhone.
- Identifiant provisoire com.example.animora ; aucune DEVELOPMENT_TEAM trouvée.
- Intégration FlutterGeneratedPluginSwiftPackage référencée, avec pré-action Run Prepare Flutter Framework Script.
- Aucun Podfile ni fichier de configuration Pods présent ; Debug/Release incluent Generated.xcconfig.
- Le fichier généré .flutter-plugins-dependencies mentionne SwiftPM ios=false, mais a été produit sur Windows. Cela ne suffit pas à conclure que la résolution native iOS échouera ou fonctionnera. Flutter config ne fixe pas explicitement SwiftPM.

Le [Flutter actuel privilégie Swift Package Manager et peut recourir à CocoaPods pour des plugins non compatibles](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers). Les plugins iOS natifs inspectés — géolocalisation, SQFlite, image_picker, printing, shared_preferences, url_launcher et package_info_plus — possèdent des Package.swift dans le cache. path_provider_foundation est une implémentation Dart/FFI via objective_c, pas un pod natif classique.

**L’absence de Podfile n’est donc pas, seule, un défaut à corriger sous Windows.** Confirmer la résolution des packages sur Mac avant de créer ou migrer une intégration CocoaPods. Les chemins Windows de Generated.xcconfig devront être régénérés sur Mac, pas copiés comme configuration utilisable.

### Permissions iOS et dépendances à surveiller

| Dépendance | Constat et contrôle nécessaire sur Mac/iPhone |
| --- | --- |
| SQFlite 2.4.5+1 / sqflite_darwin 2.4.6 | Support iOS et SwiftPM présent ; pas de permission utilisateur de stockage requise pour la base privée. Tester plugin natif, migrations et persistance réelles. |
| geolocator 14.1.2 / geolocator_apple 2.4.3 | NSLocationWhenInUseUsageDescription présent à la racine. Application à usage ponctuel : vérifier BYPASS_PERMISSION_LOCATION_ALWAYS=1 selon le gestionnaire de dépendances avant compilation/distribution ; aucun besoin métier de localisation Always identifié. |
| http 1.6.0 | HTTPS : pas de permission INTERNET iOS ni d’exception ATS générale à ajouter pour ces endpoints. Tester accès réel aux fournisseurs. |
| flutter_map / latlong2 | Pas de SDK Apple Maps ou Google Maps utilisé ; aucune clé de ces SDK à installer. HTTPS et attribution OSM déjà présents. Tester chargement et gestes sur iPhone. |
| image_picker | NSPhotoLibraryUsageDescription présent à la racine. image_picker_ios installé exige iOS 15, cohérent avec la cible. Pas d’usage caméra/vidéo repéré : ne pas ajouter de permissions caméra/micro sans ce besoin. |
| printing / pdf | Plugin SwiftPM présent ; vérifier partage/aperçu PDF sur iPhone. Si un chemin CocoaPods devient nécessaire, examiner sa configuration propre sur Mac, sans appliquer aveuglément un Podfile générique. |
| path_provider / shared_preferences | Dépendances natives/FFI et manifestes de confidentialité à résoudre avec Xcode ; tester les répertoires privés et préférences. |
| url_launcher | Liens HTTPS actuels ; vérifier ouverture Safari. Pas d’usage canLaunchUrl ou de schéma privé repéré nécessitant une liste de schémas supplémentaire. |

Le [guide geolocator](https://pub.dev/packages/geolocator) décrit le drapeau permettant d’écarter l’autorisation Always pour un usage uniquement au premier plan. Avec le Package.swift de geolocator_apple installé, il est lu depuis l’environnement du build. Aucun drapeau, entitlement ou texte de permission n’a été modifié ici.

La version iOS réelle de l’iPhone et l’accès à un Mac n’ont pas été fournis : compatibilité matérielle finale encore à vérifier. iOS 15 est le minimum du projet actuel.

## 7. Procédure future sur Mac avec Xcode

Instructions à exécuter **sur le Mac et après validation**, pas sur ce Windows :

1. Installer/configurer Flutter, idéalement la même version 3.47.5 pour reproduire l’environnement, et un Xcode compatible avec le Mac et la version iOS de l’iPhone.
2. Sélectionner Xcode et terminer sa préparation ; lire/accepter sa licence et télécharger la prise en charge iOS requise.
3. Copier le projet avec pubspec.lock, assets, sources et dossiers natifs. Régénérer les dépendances et fichiers de build locaux ; ne pas réutiliser .dart_tool ou les chemins générés Windows.
4. Exécuter flutter doctor -v et flutter pub get. Vérifier SwiftPM et sa résolution. Installer CocoaPods seulement si un fallback effectivement nécessaire ou doctor le demande pour le chemin choisi.
5. Ouvrir ios/Runner.xcworkspace dans Xcode. Sélectionner Runner puis Signing & Capabilities : choisir sa propre équipe Apple, un identifiant de bundle approprié et la signature automatique selon ce compte. Aucune valeur d’équipe ou certificat ne peut être inventée.
6. Connecter l’iPhone par câble, le déverrouiller, accepter Faire confiance et activer Mode développeur lorsque demandé. Un compte personnel peut convenir au test local ; une distribution TestFlight/App Store demande les conditions du programme Apple correspondant.
7. Vérifier d’abord une compilation sans signature si souhaité, puis compiler et lancer avec la signature réelle sur l’iPhone.

Exemples de commandes macOS futures :

~~~sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license
xcodebuild -downloadPlatform iOS

flutter doctor -v
flutter pub get
open ios/Runner.xcworkspace
flutter devices

# Pour le chemin SwiftPM / géolocalisation au premier plan :
BYPASS_PERMISSION_LOCATION_ALWAYS=1 flutter build ios --debug --no-codesign
BYPASS_PERMISSION_LOCATION_ALWAYS=1 flutter run -d <identifiant-iphone>
~~~

La compilation --no-codesign ne suffit pas à installer sur un iPhone : la signature doit être correctement configurée pour le lancement. Avec CocoaPods, le drapeau geolocator doit être appliqué selon son mécanisme de compilation propre, pas supposé actif via une variable SwiftPM.

Ne pas réutiliser ou modifier ici les certificats, profils de provisioning, identifiants d’équipe ou fichiers de signature. Aucune compilation iOS sous Windows n’a été tentée.

## 8. Sources et limites du diagnostic

Constats : commandes Flutter/Java exécutées, fichiers du projet, SDK Flutter local et versions réellement présentes dans le cache Pub. Aucun téléchargement de SDK ou de dépendance supplémentaire, aucun lancement Gradle susceptible d’installer des composants et aucune acceptation de licence.

Références officielles :
- [Configuration Android Flutter](https://docs.flutter.dev/platform-integration/android/setup)
- [Compatibilité AGP 9.1](https://developer.android.com/build/releases/agp-9-1-0-release-notes)
- [Configuration iOS Flutter](https://docs.flutter.dev/platform-integration/ios/setup)
- [Swift Package Manager Flutter](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)
- [Géolocalisation](https://pub.dev/packages/geolocator)
- [Printing](https://pub.dev/packages/printing)
- [Installation sur appareil Apple](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device)

**Arrêt après diagnostic.** La seule création de projet pendant cette étape est MOBILE_ENVIRONMENT_REPORT.md. Les modules métier, SQLite, API externes, UI/UX et signatures restent inchangés. Attendre la validation utilisateur avant toute installation ou configuration.

