class IncidentPolicy {
  final int openConsecutiveFails;
  final int openSeconds;
  final int closeConsecutiveOKs;
  final int alertCooldownSec;

  IncidentPolicy({
    required this.openConsecutiveFails,
    required this.openSeconds,
    required this.closeConsecutiveOKs,
    required this.alertCooldownSec,
  });

  factory IncidentPolicy.fromJson(Map<String, dynamic> json) {
    return IncidentPolicy(
      openConsecutiveFails: json['openConsecutiveFails'] as int,
      openSeconds: json['openSeconds'] as int,
      closeConsecutiveOKs: json['closeConsecutiveOKs'] as int,
      alertCooldownSec: json['alertCooldownSec'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'openConsecutiveFails': openConsecutiveFails,
    'openSeconds': openSeconds,
    'closeConsecutiveOKs': closeConsecutiveOKs,
    'alertCooldownSec': alertCooldownSec,
  };
}
