import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// About screen – links to website & privacy
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _siteUrl = 'https://gisle92.github.io/Vaner/';
  static const _privacyUrl = 'https://gisle92.github.io/Vaner/privacy.html';

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Om Vaner'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const Text(
                'Vaner',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'En enkel app for å bygge små, gode vaner på noen sekunder om dagen. '
                'Fokuser på 1–3 viktige vaner, logg dem kjapt, og få ærlige statistikker.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nettside'),
                subtitle: const Text('Åpne Vaner-landing på github.io'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open(_siteUrl),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Personvernerklæring'),
                subtitle: const Text('Les hvordan vi behandler dataene dine'),
                trailing: const Icon(Icons.privacy_tip_outlined),
                onTap: () => _open(_privacyUrl),
              ),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Utviklet av Gisle Aarhus.\n'
                'Hvis du oppdager feil eller har forslag, si gjerne fra 😊',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
