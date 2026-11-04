class MusicArtist {
  const MusicArtist({
    required this.id,
    required this.name,
    required this.genres,
  });

  final String id;
  final String name;
  final List<String> genres;
}

class MusicRegion {
  const MusicRegion(this.code, this.name);

  final String code;
  final String name;
}

const featuredArtists = <MusicArtist>[
  MusicArtist(id: 'taylor-swift', name: 'Taylor Swift', genres: ['pop']),
  MusicArtist(id: 'the-weeknd', name: 'The Weeknd', genres: ['pop', 'r&b']),
  MusicArtist(
    id: 'bad-bunny',
    name: 'Bad Bunny',
    genres: ['latin', 'reggaeton'],
  ),
  MusicArtist(id: 'drake', name: 'Drake', genres: ['hip-hop', 'r&b']),
  MusicArtist(id: 'billie-eilish', name: 'Billie Eilish', genres: ['pop']),
  MusicArtist(id: 'bts', name: 'BTS', genres: ['k-pop', 'pop']),
  MusicArtist(id: 'dua-lipa', name: 'Dua Lipa', genres: ['pop', 'dance']),
  MusicArtist(
    id: 'kendrick-lamar',
    name: 'Kendrick Lamar',
    genres: ['hip-hop'],
  ),
  MusicArtist(id: 'rihanna', name: 'Rihanna', genres: ['pop', 'r&b']),
  MusicArtist(id: 'ed-sheeran', name: 'Ed Sheeran', genres: ['pop']),
  MusicArtist(id: 'coldplay', name: 'Coldplay', genres: ['rock', 'pop']),
  MusicArtist(id: 'beyonce', name: 'Beyonce', genres: ['pop', 'r&b']),
  MusicArtist(id: 'bruno-mars', name: 'Bruno Mars', genres: ['pop', 'funk']),
  MusicArtist(
    id: 'ariana-grande',
    name: 'Ariana Grande',
    genres: ['pop', 'r&b'],
  ),
  MusicArtist(id: 'eminem', name: 'Eminem', genres: ['hip-hop']),
  MusicArtist(id: 'wizkid', name: 'Wizkid', genres: ['afrobeats', 'r&b']),
  MusicArtist(id: 'burna-boy', name: 'Burna Boy', genres: ['afrobeats']),
  MusicArtist(id: 'tems', name: 'Tems', genres: ['afrobeats', 'r&b']),
  MusicArtist(id: 'rosalia', name: 'Rosalia', genres: ['latin', 'pop']),
  MusicArtist(id: 'shakira', name: 'Shakira', genres: ['latin', 'pop']),
  MusicArtist(id: 'blackpink', name: 'BLACKPINK', genres: ['k-pop', 'pop']),
  MusicArtist(
    id: 'imagine-dragons',
    name: 'Imagine Dragons',
    genres: ['rock', 'pop'],
  ),
  MusicArtist(id: 'miley-cyrus', name: 'Miley Cyrus', genres: ['pop', 'rock']),
  MusicArtist(
    id: 'ayra-starr',
    name: 'Ayra Starr',
    genres: ['afrobeats', 'pop'],
  ),
  MusicArtist(id: 'stromae', name: 'Stromae', genres: ['pop', 'electronic']),
  MusicArtist(id: 'adele', name: 'Adele', genres: ['pop', 'soul']),
  MusicArtist(id: 'queen', name: 'Queen', genres: ['rock']),
  MusicArtist(
    id: 'daft-punk',
    name: 'Daft Punk',
    genres: ['electronic', 'dance'],
  ),
  MusicArtist(id: 'sza', name: 'SZA', genres: ['r&b', 'pop']),
  MusicArtist(id: 'future', name: 'Future', genres: ['hip-hop']),
  MusicArtist(
    id: 'luis-fonsi',
    name: 'Luis Fonsi',
    genres: ['latin', 'reggaeton'],
  ),
  MusicArtist(id: 'j-balvin', name: 'J Balvin', genres: ['latin', 'reggaeton']),
];

const musicRegions = <MusicRegion>[
  MusicRegion('US', 'États-Unis'),
  MusicRegion('GB', 'Royaume-Uni'),
  MusicRegion('FR', 'France'),
  MusicRegion('MG', 'Madagascar'),
  MusicRegion('AT', 'Autriche'),
  MusicRegion('CA', 'Canada'),
  MusicRegion('AU', 'Australie'),
  MusicRegion('BR', 'Brésil'),
  MusicRegion('MX', 'Mexique'),
  MusicRegion('AR', 'Argentine'),
  MusicRegion('CO', 'Colombie'),
  MusicRegion('BO', 'Bolivie'),
  MusicRegion('CR', 'Costa Rica'),
  MusicRegion('DO', 'République dominicaine'),
  MusicRegion('EC', 'Équateur'),
  MusicRegion('GT', 'Guatemala'),
  MusicRegion('PA', 'Panama'),
  MusicRegion('PY', 'Paraguay'),
  MusicRegion('UY', 'Uruguay'),
  MusicRegion('VE', 'Venezuela'),
  MusicRegion('ES', 'Espagne'),
  MusicRegion('PT', 'Portugal'),
  MusicRegion('DE', 'Allemagne'),
  MusicRegion('IT', 'Italie'),
  MusicRegion('BE', 'Belgique'),
  MusicRegion('CH', 'Suisse'),
  MusicRegion('CZ', 'Tchéquie'),
  MusicRegion('DK', 'Danemark'),
  MusicRegion('FI', 'Finlande'),
  MusicRegion('GR', 'Grèce'),
  MusicRegion('HU', 'Hongrie'),
  MusicRegion('IE', 'Irlande'),
  MusicRegion('NO', 'Norvège'),
  MusicRegion('PL', 'Pologne'),
  MusicRegion('RO', 'Roumanie'),
  MusicRegion('SE', 'Suède'),
  MusicRegion('UA', 'Ukraine'),
  MusicRegion('NL', 'Pays-Bas'),
  MusicRegion('RU', 'Russie'),
  MusicRegion('TR', 'Turquie'),
  MusicRegion('IL', 'Israël'),
  MusicRegion('AE', 'Émirats arabes unis'),
  MusicRegion('SA', 'Arabie saoudite'),
  MusicRegion('EG', 'Égypte'),
  MusicRegion('MA', 'Maroc'),
  MusicRegion('DZ', 'Algérie'),
  MusicRegion('TN', 'Tunisie'),
  MusicRegion('NG', 'Nigeria'),
  MusicRegion('ZA', 'Afrique du Sud'),
  MusicRegion('KE', 'Kenya'),
  MusicRegion('GH', 'Ghana'),
  MusicRegion('CI', 'Côte d’Ivoire'),
  MusicRegion('SN', 'Sénégal'),
  MusicRegion('UG', 'Ouganda'),
  MusicRegion('TZ', 'Tanzanie'),
  MusicRegion('ET', 'Éthiopie'),
  MusicRegion('CM', 'Cameroun'),
  MusicRegion('MU', 'Maurice'),
  MusicRegion('MZ', 'Mozambique'),
  MusicRegion('ZM', 'Zambie'),
  MusicRegion('ZW', 'Zimbabwe'),
  MusicRegion('JP', 'Japon'),
  MusicRegion('KR', 'Corée du Sud'),
  MusicRegion('IN', 'Inde'),
  MusicRegion('ID', 'Indonésie'),
  MusicRegion('PH', 'Philippines'),
  MusicRegion('TH', 'Thaïlande'),
  MusicRegion('BD', 'Bangladesh'),
  MusicRegion('HK', 'Hong Kong'),
  MusicRegion('KZ', 'Kazakhstan'),
  MusicRegion('MY', 'Malaisie'),
  MusicRegion('NP', 'Népal'),
  MusicRegion('PK', 'Pakistan'),
  MusicRegion('SG', 'Singapour'),
  MusicRegion('LK', 'Sri Lanka'),
  MusicRegion('TW', 'Taïwan'),
  MusicRegion('VN', 'Vietnam'),
  MusicRegion('NZ', 'Nouvelle-Zélande'),
  MusicRegion('CL', 'Chili'),
  MusicRegion('PE', 'Pérou'),
  MusicRegion('JM', 'Jamaïque'),
  MusicRegion('PR', 'Porto Rico'),
];

MusicArtist? artistById(String id) {
  for (final artist in featuredArtists) {
    if (artist.id == id) return artist;
  }
  return null;
}

MusicRegion? regionByCode(String? code) {
  for (final region in musicRegions) {
    if (region.code == code) return region;
  }
  return null;
}
