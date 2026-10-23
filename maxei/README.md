# maxei

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Stockage des médias importés

Les médias importés sont copiés dans le stockage local de l’application, tandis
que la bibliothèque et les playlists sont enregistrées séparément.

- Sur le Web, les fichiers sont conservés dans IndexedDB pour éviter la petite
  capacité de `localStorage`. Maxei demande au navigateur un stockage persistant,
  mais Edge peut refuser cette demande. Les données restent propres à l’origine
  et au profil du navigateur ; effacer les données du site ou utiliser une
  fenêtre InPrivate peut les supprimer. Pour les détails, voir la
  [documentation IndexedDB](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API)
  et [le stockage persistant du navigateur](https://developer.mozilla.org/en-US/docs/Web/API/StorageManager/persist).
- Sur les plateformes natives, les fichiers résident dans le répertoire privé
  de l’application. Ils survivent aux redémarrages, mais la désinstallation ou
  l’effacement des données de l’application les supprime.

Les anciennes importations Web encore présentes dans `localStorage` sont
migrées vers IndexedDB lors de la restauration de la bibliothèque.

## Lecture audio native

Sur Android, iOS et macOS, Maxei publie le titre et l’artiste aux commandes
média du système et peut continuer la lecture audio en arrière-plan. Les
notifications/commandes système ne sont pas disponibles pour l’aperçu Web.

## Préparation de la synchronisation Supabase

Le schéma de `supabase/migrations/20261023000100_library_metadata.sql` ne
contient que des métadonnées de bibliothèque, favoris, historique et playlists :
les fichiers audio, URI locales, chemins et cookies n’y sont pas stockés.
Chaque table a la sécurité RLS activée et limite les lignes au compte connecté.

Le projet Supabase n’étant pas encore créé, l’app reste locale et aucune donnée
n’est envoyée. Après création du projet, appliquer la migration et configurer
le client avec l’URL du projet et sa clé publishable/anon. Ne jamais intégrer
une clé `service_role` au client Flutter. L’activation de la synchronisation
nécessitera aussi un identifiant de média stable partagé entre appareils ; les
chemins de fichiers locaux ne peuvent pas servir d’identifiants cloud.
