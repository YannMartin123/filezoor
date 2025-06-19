import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:filezoor/widgets/mode_selector.dart';
import 'package:filezoor/widgets/transfer_mode.dart';
import 'package:filezoor/utils/shake_detector.dart';

class PipeScreen extends StatefulWidget {
  const PipeScreen({super.key});

  @override
  _PipeScreenState createState() => _PipeScreenState();
}

class _PipeScreenState extends State<PipeScreen> {
  String mode = 'Sender'; // Sender ou Receiver
  String transferMode = 'Bluetooth'; // WiFi, Bluetooth, Infrarouge
  String? selectedFileName; // Nom du fichier sélectionné
  String? selectedFilePath; // Chemin du fichier sélectionné
  String? connectedEndpointId; // ID de l'appareil connecté
  String statusMessage = 'Non connecté'; // Message de statut
  String? receivedFileName; // Nom du fichier reçu
  bool isSending = false; // Éviter envois multiples

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    List<Permission> permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
      Permission.nearbyWifiDevices,
    ];

    if (Platform.isAndroid &&
        (await DeviceInfoPlugin().androidInfo).version.sdkInt >= 33) {
      permissions.addAll([
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ]);
    } else {
      permissions.add(Permission.storage);
    }

    if (Platform.isAndroid &&
        (await DeviceInfoPlugin().androidInfo).version.sdkInt < 30) {
      permissions.add(Permission.storage);
    }

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    List<String> deniedPermissions = [];
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        deniedPermissions.add(permission.toString().split('.').last);
      }
    });

    if (deniedPermissions.isNotEmpty) {
      setState(() {
        statusMessage =
            'Permissions manquantes : ${deniedPermissions.join(', ')}. Accorde-les dans les paramètres.';
      });
    } else {
      setState(() {
        statusMessage = 'Étape permissions réussie';
      });
    }
  }

  Future<void> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        setState(() {
          selectedFileName = result.files.single.name;
          selectedFilePath = result.files.single.path;
          print(
            'Fichier choisi : $selectedFileName, Chemin : $selectedFilePath',
          );
        });
      }
    } catch (e) {
      print('Erreur lors de la sélection du fichier : $e');
      setState(() {
        statusMessage = 'Erreur sélection : $e';
      });
    }
  }

  Future<void> onSendButtonPressed() async {
    if (mode == 'Sender' &&
        selectedFilePath != null &&
        connectedEndpointId != null &&
        !isSending) {
      try {
        setState(() {
          isSending = true;
          statusMessage = 'Envoi en cours...';
        });
        print('Envoi du nom du fichier : $selectedFileName');
        if (selectedFileName != null) {
          await Nearby().sendBytesPayload(
            connectedEndpointId!,
            utf8.encode(selectedFileName!),
          );
          print('Nom du fichier envoyé');
        }
        print('Envoi du fichier : $selectedFilePath');
        await Nearby().sendFilePayload(connectedEndpointId!, selectedFilePath!);
        print('Fichier envoyé');
        setState(() {
          statusMessage = 'Fichier envoyé !';
        });
      } catch (e) {
        print('Erreur lors de l\'envoi : $e');
        setState(() {
          statusMessage = 'Erreur lors de l\'envoi : $e';
        });
      } finally {
        await Future.delayed(
          Duration(seconds: 2),
        ); // Délai pour éviter clics/secousses rapides
        setState(() {
          isSending = false;
        });
      }
    } else if (mode == 'Sender') {
      setState(() {
        statusMessage = 'Aucun fichier ou connexion !';
      });
    }
  }

  Future<void> onShake() async {
    await onSendButtonPressed(); // Réutiliser la même logique
  }

  Future<void> startSender() async {
    try {
      print('Démarrage de l\'advertising');
      await Nearby().startAdvertising(
        'FileZoorUser',
        Strategy.P2P_STAR,
        onConnectionInitiated: (String endpointId, ConnectionInfo info) {
          print('Connexion initiée avec $endpointId');
          Nearby().acceptConnection(
            endpointId,
            onPayLoadRecieved: (String end, Payload payload) {
              print('Payload reçu (Sender) : Type=${payload.type}');
            },
            onPayloadTransferUpdate: (
              String end,
              PayloadTransferUpdate update,
            ) {
              print('Mise à jour transfert (Sender) : Statut=${update.status}');
              if (update.status == PayloadStatus.SUCCESS) {
                setState(() {
                  statusMessage = 'Envoi réussi';
                });
              } else if (update.status == PayloadStatus.FAILURE) {
                setState(() {
                  statusMessage = 'Échec de l\'envoi';
                });
              }
            },
          );
          setState(() {
            connectedEndpointId = endpointId;
            statusMessage = 'Connecté à ${info.endpointName}';
          });
        },
        onConnectionResult: (String endpointId, Status status) {
          print('Résultat connexion : $status');
          if (status == Status.CONNECTED) {
            setState(() {
              statusMessage = 'Connexion établie';
            });
          } else {
            setState(() {
              statusMessage = 'Connexion échouée';
            });
          }
        },
        onDisconnected: (String endpointId) {
          print('Déconnexion : $endpointId');
          setState(() {
            connectedEndpointId = null;
            statusMessage = 'Déconnecté';
          });
        },
      );
      setState(() {
        statusMessage = 'Recherche d\'appareils...';
      });
    } catch (e) {
      print('Erreur Sender : $e');
      setState(() {
        statusMessage = 'Erreur Sender : $e';
      });
    }
  }

  Future<void> startReceiver() async {
    try {
      print('Démarrage de la découverte');
      await Nearby().startDiscovery(
        'FileZoorUser',
        Strategy.P2P_STAR,
        onEndpointFound: (
          String endpointId,
          String endpointName,
          String serviceId,
        ) {
          print('Appareil trouvé : $endpointName ($endpointId)');
          Nearby().requestConnection(
            'FileZoorUser',
            endpointId,
            onConnectionInitiated: (String id, ConnectionInfo info) {
              print('Connexion initiée avec $id');
              Nearby().acceptConnection(
                endpointId,
                onPayLoadRecieved: (String end, Payload payload) async {
                  print(
                    'Payload reçu : Type=${payload.type}, ID=${payload.id}',
                  );
                  if (payload.type == PayloadType.BYTES) {
                    try {
                      setState(() {
                        receivedFileName = utf8.decode(payload.bytes!);
                        statusMessage =
                            'Nom du fichier reçu : $receivedFileName';
                        print('Nom du fichier reçu : $receivedFileName');
                      });
                    } catch (e) {
                      print('Erreur décodage nom fichier : $e');
                      setState(() {
                        statusMessage = 'Erreur nom fichier : $e';
                      });
                    }
                  } else if (payload.type == PayloadType.FILE) {
                    try {
                      final dir = Directory(
                        '/storage/emulated/0/Download/FileZoor',
                      );
                      print('Création dossier : ${dir.path}');
                      await dir.create(recursive: true);
                      final fileName = receivedFileName ?? 'file_${payload.id}';
                      final file = File(
                        '${dir.path}/received_${payload.id}_$fileName',
                      );
                      print('Préparation sauvegarde : ${file.path}');
                      if (payload.uri != null) {
                        print('URI temporaire : ${payload.uri}');
                        try {
                          // Utiliser ContentResolver pour lire l'URI
                          final uri = Uri.parse(payload.uri!);
                          final inputStream = await MethodChannel(
                            'com.example.filezoor/content_resolver',
                          ).invokeMethod('openInputStream', {
                            'uri': payload.uri,
                          });
                          if (inputStream != null) {
                            print('InputStream obtenu pour ${payload.uri}');
                            await file.create(recursive: true);
                            final sink = file.openWrite();
                            sink.add(inputStream as List<int>);
                            await sink.flush();
                            await sink.close();
                            print(
                              'Fichier écrit via InputStream : ${file.path}',
                            );
                            if (await file.exists()) {
                              print('Fichier final existe : ${file.path}');
                              setState(() {
                                statusMessage = 'Fichier reçu : ${file.path}';
                              });
                            } else {
                              print(
                                'Fichier final n\'existe pas : ${file.path}',
                              );
                              setState(() {
                                statusMessage =
                                    'Erreur : Fichier non sauvegardé';
                              });
                            }
                          } else {
                            print('InputStream null pour ${payload.uri}');
                            setState(() {
                              statusMessage =
                                  'Erreur : Impossible d\'ouvrir l\'URI';
                            });
                          }
                        } catch (e) {
                          print('Erreur lecture URI : $e');
                          setState(() {
                            statusMessage = 'Erreur lecture URI : $e';
                          });
                        }
                      } else {
                        print('URI null pour payload FILE');
                        setState(() {
                          statusMessage = 'Erreur : URI non fourni';
                        });
                      }
                    } catch (e) {
                      print('Erreur réception fichier : $e');
                      setState(() {
                        statusMessage = 'Erreur réception fichier : $e';
                      });
                    }
                  }
                },
                onPayloadTransferUpdate: (
                  String end,
                  PayloadTransferUpdate update,
                ) {
                  print(
                    'Mise à jour transfert : Statut=${update.status}, Bytes=${update.bytesTransferred}/${update.totalBytes}',
                  );
                  if (update.status == PayloadStatus.SUCCESS) {
                    setState(() {
                      statusMessage = 'Réception réussie';
                    });
                  } else if (update.status == PayloadStatus.FAILURE) {
                    setState(() {
                      statusMessage = 'Échec de la réception';
                    });
                  }
                },
              );
              setState(() {
                connectedEndpointId = endpointId;
                statusMessage = 'Connecté à $endpointName';
              });
            },
            onConnectionResult: (String id, Status status) {
              print('Résultat connexion : $status');
              if (status == Status.CONNECTED) {
                setState(() {
                  statusMessage = 'Connexion établie';
                });
              } else {
                setState(() {
                  statusMessage = 'Connexion échouée';
                });
              }
            },
            onDisconnected: (String id) {
              print('Déconnexion : $id');
              setState(() {
                connectedEndpointId = null;
                statusMessage = 'Déconnecté';
              });
            },
          );
        },
        onEndpointLost: (String? endpointId) {
          print('Appareil perdu : $endpointId');
          setState(() {
            statusMessage = 'Appareil perdu';
          });
        },
      );
      setState(() {
        statusMessage = 'En attente de connexion...';
      });
    } catch (e) {
      print('Erreur Receiver : $e');
      setState(() {
        statusMessage = 'Erreur Receiver : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FileZoor Pipe')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Pipe Interface',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ModeSelector(
              mode: mode,
              onModeChanged: (newMode) {
                setState(() {
                  mode = newMode;
                  connectedEndpointId = null;
                  statusMessage = 'Non connecté';
                  isSending = false;
                });
                if (newMode == 'Sender') {
                  startSender();
                } else {
                  startReceiver();
                }
              },
            ),
            const SizedBox(height: 20),
            TransferMode(
              transferMode: transferMode,
              onTransferModeChanged:
                  (newMode) => setState(() => transferMode = newMode),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: pickFile,
              child: const Text('Sélectionner un fichier'),
            ),
            const SizedBox(height: 20),
            if (mode == 'Sender' &&
                selectedFilePath != null &&
                connectedEndpointId != null)
              ElevatedButton(
                onPressed: isSending ? null : onSendButtonPressed,
                child:
                    isSending
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Envoyer'),
              ),
            const SizedBox(height: 20),
            Text(
              selectedFileName != null
                  ? 'Fichier : $selectedFileName'
                  : 'Aucun fichier sélectionné',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              'Statut : $statusMessage',
              style: const TextStyle(fontSize: 16, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: requestPermissions,
              child: const Text('Redemander les permissions'),
            ),
            ShakeDetector(onShake: onShake),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
    super.dispose();
  }
}
