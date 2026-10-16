import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../media/media_link.dart';
import '../media/media_link_parser.dart';
import '../theme/maxei_theme.dart';
import '../widgets/liquid_surface.dart';

class LinkImportScreen extends StatefulWidget {
  const LinkImportScreen({super.key});

  @override
  State<LinkImportScreen> createState() => _LinkImportScreenState();
}

class _LinkImportScreenState extends State<LinkImportScreen> {
  final _controller = TextEditingController();
  final _parser = const MediaLinkParser();
  MediaLink? _link;
  String? _error;
  bool _isFavorite = false;
  bool _isOpening = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _analyze() {
    try {
      final link = _parser.parse(_controller.text);
      setState(() {
        _link = link;
        _error = null;
        _isFavorite = false;
      });
    } on FormatException catch (error) {
      setState(() {
        _link = null;
        _error = error.message;
      });
    }
  }

  Future<void> _openSource() async {
    final link = _link;
    if (link == null || _isOpening) return;
    setState(() => _isOpening = true);
    try {
      final opened = await launchUrl(
        link.uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _showMessage('Aucune application ne peut ouvrir ce lien.');
      }
    } catch (_) {
      if (mounted) _showMessage('Impossible d’ouvrir ce lien pour le moment.');
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: canvas,
    appBar: AppBar(
      title: const Text('Ouvrir un lien'),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    body: LiquidBackdrop(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text(
            'Un lien, sans détour.',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            'Reconnaissance locale pour YouTube, Facebook, Instagram et les fichiers média directs.',
            style: TextStyle(color: ink.withValues(alpha: 0.7), height: 1.45),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _analyze(),
            decoration: InputDecoration(
              hintText: 'Collez un lien ici',
              prefixIcon: const Icon(Icons.link_rounded),
              suffixIcon: IconButton(
                tooltip: 'Effacer le lien',
                onPressed: () => setState(() {
                  _controller.clear();
                  _link = null;
                  _error = null;
                }),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _analyze,
            icon: const Icon(Icons.travel_explore_rounded),
            label: const Text('Analyser le lien'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _Notice(
              icon: Icons.info_outline_rounded,
              title: 'Lien non reconnu',
              detail: _error!,
            ),
          ],
          if (_link case final link?) ...[
            const SizedBox(height: 18),
            _LinkResult(
              link: link,
              isFavorite: _isFavorite,
              isOpening: _isOpening,
              onFavorite: () => setState(() => _isFavorite = !_isFavorite),
              onOpen: _openSource,
            ),
          ],
          const SizedBox(height: 18),
          _Notice(
            icon: Icons.shield_outlined,
            title: 'Vos comptes restent à vous',
            detail: 'Les liens de réseaux sociaux s’ouvrent dans leur application officielle. Maxei ne lit pas les cookies, ne contourne pas les connexions et ne récupère pas les flux protégés. Pour un contenu privé, connectez-vous directement au service.',
          ),
          const SizedBox(height: 10),
          _Notice(
            icon: Icons.verified_user_outlined,
            title: 'Téléchargement responsable',
            detail: 'Enregistrez uniquement vos propres médias ou les contenus explicitement libres de droits. L’import local reste disponible depuis le bouton + de la bibliothèque. Aucun abonnement caché ni publicité agressive.',
          ),
          const SizedBox(height: 22),
          Text(
            'L’analyse est effectuée sur cet appareil. Elle identifie le domaine et, lorsqu’il est présent dans l’URL, l’identifiant public du contenu; elle ne vérifie pas les droits ni l’accès au média.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: ink.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LinkResult extends StatelessWidget {
  const _LinkResult({
    required this.link,
    required this.isFavorite,
    required this.isOpening,
    required this.onFavorite,
    required this.onOpen,
  });

  final MediaLink link;
  final bool isFavorite;
  final bool isOpening;
  final VoidCallback onFavorite;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    radius: 16,
    tint: aqua.withValues(alpha: 0.28),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                link.platformName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: isFavorite
                  ? 'Retirer des favoris'
                  : 'Ajouter aux favoris',
              onPressed: onFavorite,
              icon: Icon(
                isFavorite
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
            ),
          ],
        ),
        if (link.contentId != null) ...[
          const SizedBox(height: 2),
          Text('Identifiant public : ${link.contentId}'),
        ],
        const SizedBox(height: 10),
        Text(
          link.platform == MediaPlatform.directFile
              ? 'Lien direct reconnu. La lecture distante dépend du serveur et de vos droits d’accès.'
              : 'Ouverture officielle uniquement. Les flux vidéo/audio ne sont pas extraits.',
          style: TextStyle(color: ink.withValues(alpha: 0.75), height: 1.4),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isOpening ? null : onOpen,
            icon: isOpening
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_new_rounded),
            label: Text(isOpening ? 'Ouverture…' : 'Ouvrir la source'),
          ),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ink.withValues(alpha: 0.08)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: ink),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(detail, style: const TextStyle(fontSize: 12, height: 1.45)),
            ],
          ),
        ),
      ],
    ),
  );
}
