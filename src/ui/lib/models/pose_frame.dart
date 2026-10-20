import 'rep_counter.dart';

enum PoseKey {
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

class PoseFrame {
  final Map<PoseKey, Joint> joints;
  final double width;
  final double height;
  const PoseFrame(this.joints, {required this.width, required this.height});

  Joint? at(PoseKey key) => joints[key];

  bool sees(PoseKey key) => (joints[key]?.likelihood ?? 0) >= repMinLikelihood;
}

const poseBones = <(PoseKey, PoseKey)>[
  (PoseKey.leftShoulder, PoseKey.rightShoulder),
  (PoseKey.leftShoulder, PoseKey.leftElbow),
  (PoseKey.leftElbow, PoseKey.leftWrist),
  (PoseKey.rightShoulder, PoseKey.rightElbow),
  (PoseKey.rightElbow, PoseKey.rightWrist),
  (PoseKey.leftShoulder, PoseKey.leftHip),
  (PoseKey.rightShoulder, PoseKey.rightHip),
  (PoseKey.leftHip, PoseKey.rightHip),
  (PoseKey.leftHip, PoseKey.leftKnee),
  (PoseKey.leftKnee, PoseKey.leftAnkle),
  (PoseKey.rightHip, PoseKey.rightKnee),
  (PoseKey.rightKnee, PoseKey.rightAnkle),
];
