class UserEntity {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? profilePhoto;
  final String? city;
  final String? area;
  final String verificationStatus;
  final double trustScore;
  final bool availability;
  final List<String> helpCategories;
  final int helpGivenCount;
  final int helpReceivedCount;
  final int helpBalance;
  final String restrictionStatus;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.profilePhoto,
    this.city,
    this.area,
    required this.verificationStatus,
    required this.trustScore,
    required this.availability,
    required this.helpCategories,
    required this.helpGivenCount,
    required this.helpReceivedCount,
    required this.helpBalance,
    required this.restrictionStatus,
  });
}
