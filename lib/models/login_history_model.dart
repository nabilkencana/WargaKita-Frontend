class LoginHistory {
  final String deviceType;
  final String deviceName;
  final String? city;
  final String? ipAddress;
  final DateTime createdAt;

  LoginHistory({
    required this.deviceType,
    required this.deviceName,
    this.city,
    this.ipAddress,
    required this.createdAt,
  });

  factory LoginHistory.fromJson(Map<String, dynamic> json) {
    return LoginHistory(
      deviceType: json['deviceType'] ?? '-',
      deviceName: json['deviceName'] ?? '-',
      city: json['city'],
      ipAddress: json['ipAddress'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
