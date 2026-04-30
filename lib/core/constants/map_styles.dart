// lib/core/constants/map_styles.dart
// Centralized map styles — used by both user and driver screens

const String kLightMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#EEF2F7"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#4A6080"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#FFFFFF"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#DCE6F0"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#F5F8FC"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#E4EDF8"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#C8D8E8"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#7A8FA8"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#B4D0E8"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#6A8FAA"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#C4D4E4"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#E0EAF2"}]}
]
''';

const String kDarkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0B1120"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6B8DB0"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#060C18"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1A2E4A"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#0D1E35"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#1E3A60"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#253E5C"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#182C44"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#7490B0"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#051020"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3A5A7A"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#1A2E4A"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#0D1A2A"}]}
]
''';
