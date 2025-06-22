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

class _PipeScreenState extends State<PipeScreen> with TickerProviderStateMixin {
  // Variables existantes
  String mode = 'Sender';
  String transferMode = 'Bluetooth';
  String? selectedFileName;
  String? selectedFilePath;
  String? connectedEndpointId;
  String statusMessage = 'Non connecté';
  String? receivedFileName;
  bool isSending = false;

  // Contrôleurs d'animation
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialisation des animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
    
    // Démarrer les animations
    _fadeController.forward();
    _pulseController.repeat(reverse: true);
    
    requestPermissions();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
    super.dispose();
  }

  // Toutes vos méthodes existantes restent identiques
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
        });
        _bounceController.forward().then((_) => _bounceController.reverse());
      }
    } catch (e) {
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
        
        if (selectedFileName != null) {
          await Nearby().sendBytesPayload(
            connectedEndpointId!,
            utf8.encode(selectedFileName!),
          );
        }
        
        await Nearby().sendFilePayload(connectedEndpointId!, selectedFilePath!);
        
        setState(() {
          statusMessage = 'Fichier envoyé !';
        });
      } catch (e) {
        setState(() {
          statusMessage = 'Erreur lors de l\'envoi : $e';
        });
      } finally {
        await Future.delayed(Duration(seconds: 2));
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
    await onSendButtonPressed();
  }

  Future<void> startSender() async {
    try {
      await Nearby().startAdvertising(
        'FileZoorUser',
        Strategy.P2P_STAR,
        onConnectionInitiated: (String endpointId, ConnectionInfo info) {
          Nearby().acceptConnection(
            endpointId,
            onPayLoadRecieved: (String end, Payload payload) {},
            onPayloadTransferUpdate: (String end, PayloadTransferUpdate update) {
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
      setState(() {
        statusMessage = 'Erreur Sender : $e';
      });
    }
  }

  Future<void> startReceiver() async {
    try {
      await Nearby().startDiscovery(
        'FileZoorUser',
        Strategy.P2P_STAR,
        onEndpointFound: (String endpointId, String endpointName, String serviceId) {
          Nearby().requestConnection(
            'FileZoorUser',
            endpointId,
            onConnectionInitiated: (String id, ConnectionInfo info) {
              Nearby().acceptConnection(
                endpointId,
                onPayLoadRecieved: (String end, Payload payload) async {
                  if (payload.type == PayloadType.BYTES) {
                    try {
                      setState(() {
                        receivedFileName = utf8.decode(payload.bytes!);
                        statusMessage = 'Nom du fichier reçu : $receivedFileName';
                      });
                    } catch (e) {
                      setState(() {
                        statusMessage = 'Erreur nom fichier : $e';
                      });
                    }
                  } else if (payload.type == PayloadType.FILE) {
                    try {
                      final dir = Directory('/storage/emulated/0/Download/FileZoor');
                      await dir.create(recursive: true);
                      final fileName = receivedFileName ?? 'file_${payload.id}';
                      final file = File('${dir.path}/received_${payload.id}_$fileName');
                      
                      if (payload.uri != null) {
                        try {
                          final inputStream = await MethodChannel(
                            'com.example.filezoor/content_resolver',
                          ).invokeMethod('openInputStream', {
                            'uri': payload.uri,
                          });
                          if (inputStream != null) {
                            await file.create(recursive: true);
                            final sink = file.openWrite();
                            sink.add(inputStream as List<int>);
                            await sink.flush();
                            await sink.close();
                            
                            if (await file.exists()) {
                              setState(() {
                                statusMessage = 'Fichier reçu : ${file.path}';
                              });
                            } else {
                              setState(() {
                                statusMessage = 'Erreur : Fichier non sauvegardé';
                              });
                            }
                          } else {
                            setState(() {
                              statusMessage = 'Erreur : Impossible d\'ouvrir l\'URI';
                            });
                          }
                        } catch (e) {
                          setState(() {
                            statusMessage = 'Erreur lecture URI : $e';
                          });
                        }
                      } else {
                        setState(() {
                          statusMessage = 'Erreur : URI non fourni';
                        });
                      }
                    } catch (e) {
                      setState(() {
                        statusMessage = 'Erreur réception fichier : $e';
                      });
                    }
                  }
                },
                onPayloadTransferUpdate: (String end, PayloadTransferUpdate update) {
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
              setState(() {
                connectedEndpointId = null;
                statusMessage = 'Déconnecté';
              });
            },
          );
        },
        onEndpointLost: (String? endpointId) {
          setState(() {
            statusMessage = 'Appareil perdu';
          });
        },
      );
      setState(() {
        statusMessage = 'En attente de connexion...';
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Erreur Receiver : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFF4F8EFF),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Header avec icône et titre
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Partage Instantané',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance pour centrer le titre
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Indicateur de statut animé
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            connectedEndpointId != null 
                                ? Icons.check_circle_rounded 
                                : mode == 'Sender' 
                                    ? Icons.send_rounded 
                                    : Icons.download_rounded,
                            size: 60,
                            color: connectedEndpointId != null 
                                ? Colors.green[300] 
                                : Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Message de statut
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      statusMessage,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Sélecteur de mode avec style moderne
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mode de fonctionnement',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Mode de transfert
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Type de connexion',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: TransferMode(
                            transferMode: transferMode,
                            onTransferModeChanged: (newMode) =>
                                setState(() => transferMode = newMode),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Bouton de sélection de fichier
                  AnimatedBuilder(
                    animation: _bounceAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _bounceAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF4ECDC4),
                                Color(0xFF44A08D),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4ECDC4).withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(
                              Icons.folder_rounded,
                              size: 24,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Choisir un fichier',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: pickFile,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Affichage du fichier sélectionné
                  if (selectedFileName != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedFileName!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Bouton d'envoi
                  if (mode == 'Sender' && 
                      selectedFilePath != null && 
                      connectedEndpointId != null)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF6B6B),
                            Color(0xFFFFE66D),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B6B).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: isSending 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                size: 24,
                                color: Colors.white,
                              ),
                        label: Text(
                          isSending ? 'Envoi en cours...' : 'Envoyer le fichier',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: isSending ? null : onSendButtonPressed,
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Bouton de permissions en cas de problème
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      backgroundColor: Colors.white.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    icon: Icon(
                      Icons.security_rounded,
                      size: 20,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    label: Text(
                      'Vérifier les permissions',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: requestPermissions,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // ShakeDetector (invisible)
                  ShakeDetector(onShake: onShake),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}