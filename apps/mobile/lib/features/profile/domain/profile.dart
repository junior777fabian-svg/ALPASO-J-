/// Perfil de la cuenta, tal como lo guarda `public.profiles`.
class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.adultConfirmedAt,
    required this.isBlocked,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    fullName: (json['full_name'] as String?) ?? '',
    adultConfirmedAt: switch (json['adult_confirmed_at']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
    isBlocked: (json['is_blocked'] as bool?) ?? false,
  );

  final String id;
  final String fullName;

  /// Momento en que la cuenta declaró ser mayor de 18. Nulo si aún no.
  final DateTime? adultConfirmedAt;
  final bool isBlocked;

  bool get isAdultConfirmed => adultConfirmedAt != null;

  Profile copyWith({String? fullName, DateTime? adultConfirmedAt}) => Profile(
    id: id,
    fullName: fullName ?? this.fullName,
    adultConfirmedAt: adultConfirmedAt ?? this.adultConfirmedAt,
    isBlocked: isBlocked,
  );
}
