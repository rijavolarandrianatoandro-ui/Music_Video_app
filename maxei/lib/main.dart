import 'package:flutter/material.dart';

const _ink = Color(0xFF202820);
const _canvas = Color(0xFFF4F5EF);
const _accent = Color(0xFFC8F169);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maxei AI',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _canvas,
        colorScheme: const ColorScheme.light(
          primary: _ink,
          onPrimary: _canvas,
          secondary: _accent,
          surface: _canvas,
          onSurface: _ink,
        ),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum _Section { chat, notebooks, history }

class _Conversation {
  _Conversation(this.title, this.messages);

  final String title;
  final List<_Message> messages;
}

class _Message {
  const _Message(this.text, {required this.fromUser});

  final String text;
  final bool fromUser;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _conversations = <_Conversation>[
    _Conversation('Planifier un lancement produit', [
      const _Message(
        'Aide-moi à structurer un lancement produit sur 6 semaines.',
        fromUser: true,
      ),
      const _Message(
        'Bien sûr. On peut organiser le lancement en trois temps : préparer le positionnement, créer l’attente, puis coordonner la sortie et les retours.',
        fromUser: false,
      ),
    ]),
    _Conversation('Synthèse du rapport trimestriel', [
      const _Message(
        'Comment rendre une synthèse plus claire pour la direction ?',
        fromUser: true,
      ),
      const _Message(
        'Commence par la décision attendue, puis présente trois indicateurs clés et les actions proposées.',
        fromUser: false,
      ),
    ]),
    _Conversation('Idées pour un atelier créatif', [
      const _Message(
        'Propose un format d’atelier d’équipe de 45 minutes.',
        fromUser: true,
      ),
      const _Message(
        'Un format simple : 5 minutes de cadrage, 10 minutes d’idées individuelles, 20 minutes de regroupement, et 10 minutes pour choisir les prochaines étapes.',
        fromUser: false,
      ),
    ]),
  ];

  _Section _section = _Section.chat;
  int? _activeConversation;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _selectSection(_Section section) {
    setState(() => _section = section);
    if (MediaQuery.sizeOf(context).width < 900) Navigator.of(context).pop();
  }

  void _startConversation() {
    setState(() {
      _section = _Section.chat;
      _activeConversation = null;
      _inputController.clear();
    });
    if (MediaQuery.sizeOf(context).width < 900 && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  void _openConversation(int index) {
    setState(() {
      _activeConversation = index;
      _section = _Section.chat;
    });
    if (MediaQuery.sizeOf(context).width < 900) Navigator.of(context).pop();
  }

  void _sendMessage([String? prompt]) {
    final text = (prompt ?? _inputController.text).trim();
    if (text.isEmpty) return;
    setState(() {
      if (_activeConversation == null) {
        _conversations.insert(0, _Conversation(text, []));
        _activeConversation = 0;
      }
      final conversation = _conversations[_activeConversation!];
      conversation.messages.add(_Message(text, fromUser: true));
      conversation.messages.add(
        const _Message(
          'Je peux vous aider à explorer cette idée. Pour commencer, voici une structure claire et quelques pistes concrètes à adapter à votre contexte.',
          fromUser: false,
        ),
      );
      if (conversation.messages.length == 2) {
        _conversations.removeAt(_activeConversation!);
        _conversations.insert(0, conversation);
        _activeConversation = 0;
      }
      _inputController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      drawer: isWide
          ? null
          : Drawer(
              child: _Sidebar(
                section: _section,
                conversations: _conversations,
                activeConversation: _activeConversation,
                onNewChat: _startConversation,
                onSectionSelected: _selectSection,
                onConversationSelected: _openConversation,
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (isWide)
              SizedBox(
                width: 264,
                child: _Sidebar(
                  section: _section,
                  conversations: _conversations,
                  activeConversation: _activeConversation,
                  onNewChat: _startConversation,
                  onSectionSelected: _selectSection,
                  onConversationSelected: _openConversation,
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  _TopBar(section: _section, isWide: isWide),
                  Expanded(child: _buildPage()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage() {
    switch (_section) {
      case _Section.chat:
        return _ChatPage(
          conversation: _activeConversation == null
              ? null
              : _conversations[_activeConversation!],
          inputController: _inputController,
          scrollController: _scrollController,
          onSend: _sendMessage,
        );
      case _Section.notebooks:
        return const _NotebookPage();
      case _Section.history:
        return _HistoryPage(
          conversations: _conversations,
          onOpen: _openConversation,
        );
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.section,
    required this.conversations,
    required this.activeConversation,
    required this.onNewChat,
    required this.onSectionSelected,
    required this.onConversationSelected,
  });

  final _Section section;
  final List<_Conversation> conversations;
  final int? activeConversation;
  final VoidCallback onNewChat;
  final ValueChanged<_Section> onSectionSelected;
  final ValueChanged<int> onConversationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _ink,
      padding: const EdgeInsets.fromLTRB(18, 22, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _ink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'maxei',
                style: TextStyle(
                  color: _canvas,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Nouvelle conversation',
                onPressed: onNewChat,
                icon: const Icon(Icons.edit_square, color: _canvas, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _SidebarAction(
            icon: Icons.add_rounded,
            label: 'Nouvelle conversation',
            selected: false,
            onTap: onNewChat,
          ),
          const SizedBox(height: 10),
          _SidebarAction(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Assistant',
            selected: section == _Section.chat,
            onTap: () => onSectionSelected(_Section.chat),
          ),
          _SidebarAction(
            icon: Icons.auto_stories_outlined,
            label: 'Mes notebooks',
            selected: section == _Section.notebooks,
            onTap: () => onSectionSelected(_Section.notebooks),
          ),
          _SidebarAction(
            icon: Icons.schedule_rounded,
            label: 'Historique',
            selected: section == _Section.history,
            onTap: () => onSectionSelected(_Section.history),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 25, 0, 12),
            child: Text(
              'RÉCENT',
              style: TextStyle(
                color: _canvas,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) => InkWell(
                onTap: () => onConversationSelected(index),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: activeConversation == index
                        ? _canvas.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    conversations[index].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _canvas.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: _canvas.withValues(alpha: 0.16)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _canvas.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'M',
                      style: TextStyle(
                        color: _canvas,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mon espace',
                        style: TextStyle(
                          color: _canvas,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Offre gratuite',
                        style: TextStyle(color: _canvas, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.more_horiz,
                  color: _canvas.withValues(alpha: 0.75),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarAction extends StatelessWidget {
  const _SidebarAction({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected ? _canvas.withValues(alpha: 0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: selected ? _accent : _canvas, size: 18),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _canvas,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.section, required this.isWide});

  final _Section section;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final title = switch (section) {
      _Section.chat => 'Assistant',
      _Section.notebooks => 'Mes notebooks',
      _Section.history => 'Historique',
    };
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            if (!isWide)
              Builder(
                builder: (context) => IconButton(
                  tooltip: 'Ouvrir le menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
              ),
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            const Icon(Icons.circle, color: _accent, size: 8),
            const SizedBox(width: 7),
            const Text(
              'Maxei 1.0',
              style: TextStyle(color: _ink, fontSize: 11),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _ink,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatPage extends StatelessWidget {
  const _ChatPage({
    required this.conversation,
    required this.inputController,
    required this.scrollController,
    required this.onSend,
  });

  final _Conversation? conversation;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final messages = conversation?.messages ?? const <_Message>[];
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? _Welcome(onPrompt: onSend)
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 34, 20, 28),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _MessageBubble(message: messages[index]),
                ),
        ),
        _Composer(controller: inputController, onSend: onSend),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 9, 12, 14),
          child: Text(
            'Maxei peut se tromper. Vérifiez les informations importantes.',
            style: TextStyle(color: _ink, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPrompt});

  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _ink,
                  size: 25,
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                'Bonjour, que souhaitez-vous explorer ?',
                style: TextStyle(
                  color: _ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Posez une question, partagez une idée ou démarrez avec une suggestion.',
                style: TextStyle(
                  color: _ink.withValues(alpha: 0.72),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PromptChip(
                    icon: Icons.lightbulb_outline,
                    label: 'Trouver des idées',
                    onTap: () => onPrompt(
                      'Aide-moi à trouver des idées pour un nouveau projet.',
                    ),
                  ),
                  _PromptChip(
                    icon: Icons.edit_note_rounded,
                    label: 'Écrire un texte',
                    onTap: () => onPrompt(
                      'Aide-moi à rédiger un texte clair et convaincant.',
                    ),
                  ),
                  _PromptChip(
                    icon: Icons.summarize_outlined,
                    label: 'Faire une synthèse',
                    onTap: () => onPrompt(
                      'Comment faire une synthèse efficace d’un document ?',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17, color: _ink),
      label: Text(label, style: const TextStyle(color: _ink, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: _ink.withValues(alpha: 0.18)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(15, 6, 7, 6),
        decoration: BoxDecoration(
          color: _canvas,
          border: Border.all(color: _ink.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              Icons.add_rounded,
              color: _ink.withValues(alpha: 0.75),
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: onSend,
                style: const TextStyle(color: _ink, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Écrivez votre message…',
                  hintStyle: TextStyle(color: _ink, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Envoyer le message',
              onPressed: () => onSend(controller.text),
              style: IconButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _ink,
                minimumSize: const Size(38, 38),
              ),
              icon: const Icon(Icons.arrow_upward_rounded, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _Message message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: message.fromUser ? _accent : _canvas,
            borderRadius: BorderRadius.circular(12),
            border: message.fromUser
                ? null
                : Border.all(color: _ink.withValues(alpha: 0.14)),
          ),
          child: Text(
            message.text,
            style: const TextStyle(color: _ink, fontSize: 14, height: 1.5),
          ),
        ),
      ),
    );
  }
}

class _NotebookPage extends StatelessWidget {
  const _NotebookPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vos sources, réunies.',
                style: TextStyle(
                  color: _ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Créez un espace de travail à partir de vos documents.',
                style: TextStyle(
                  color: _ink.withValues(alpha: 0.72),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  border: Border.all(color: _ink.withValues(alpha: 0.25)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.upload_file_rounded,
                      color: _ink,
                      size: 31,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ajouter des sources',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'PDF, notes ou liens web',
                      style: TextStyle(
                        color: _ink.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Import de documents bientôt disponible',
                              ),
                            ),
                          ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Importer un document'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _ink,
                        foregroundColor: _canvas,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'DÉMARRER AVEC UN EXEMPLE',
                style: TextStyle(
                  color: _ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const _NotebookExample(
                icon: Icons.menu_book_outlined,
                title: 'Guide de recherche',
                detail: 'Questions et notes organisées autour de vos sources',
              ),
              const SizedBox(height: 9),
              const _NotebookExample(
                icon: Icons.work_outline_rounded,
                title: 'Espace projet',
                detail: 'Centralisez les documents et les décisions de votre équipe',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotebookExample extends StatelessWidget {
  const _NotebookExample({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: _ink.withValues(alpha: 0.17)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(icon, color: _ink, size: 22),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    color: _ink.withValues(alpha: 0.72),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: _ink, size: 17),
        ],
      ),
    );
  }
}

class _HistoryPage extends StatelessWidget {
  const _HistoryPage({required this.conversations, required this.onOpen});

  final List<_Conversation> conversations;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reprenez le fil.',
                style: TextStyle(
                  color: _ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vos conversations récentes sont ici.',
                style: TextStyle(
                  color: _ink.withValues(alpha: 0.72),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),
              for (var index = 0; index < conversations.length; index++)
                InkWell(
                  onTap: () => onOpen(index),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: _ink.withValues(alpha: 0.17)),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: _ink,
                          size: 19,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                conversations[index].title,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                conversations[index].messages.isEmpty
                                    ? 'Nouvelle conversation'
                                    : conversations[index].messages.last.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _ink.withValues(alpha: 0.72),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: _ink,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
