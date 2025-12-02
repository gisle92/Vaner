import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Header with avatar, greeting and date
class HomeHeader extends StatelessWidget {
  final User user;
  final String todayFormatted;

  const HomeHeader({
    super.key,
    required this.user,
    required this.todayFormatted,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = (user.displayName ?? 'venn').split(' ').first;
    final initials = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundImage:
              user.photoURL != null ? NetworkImage(user.photoURL!) : null,
          child: user.photoURL == null
              ? Text(
                  initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hei, $firstName 👋',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              todayFormatted,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
