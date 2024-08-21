import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mysql1/mysql1.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class FormScreen extends StatefulWidget {
  final String projectId;

  FormScreen({required this.projectId});

  @override
  _FormScreenState createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _formatosFormularios = [];
  Map<int, TextEditingController> _respuestasControllers = {};
  late Box responseBox;
  late Box projectBox;
  final String apiUrl = 'https://www.pythonanywhere.com/user/aaalfred/shares/c37b1dc2d5094eb481e39c962918e426/';
  String projectName = '';
  final _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    openBoxes();
    _loadProjectData();
  }

  @override
  void dispose() {
    _respuestasControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> openBoxes() async {
    responseBox = await Hive.openBox('offline_responses_${widget.projectId}');
    projectBox = await Hive.openBox('project_data');
    projectName = projectBox.get('project_name', defaultValue: 'Proyecto Desconocido');
    setState(() {});
  }

  Future<void> _loadProjectData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final conn = await MySqlConnection.connect(ConnectionSettings(
        host: '72.167.33.202',
        port: 3306,
        user: 'alfred',
        db: 'idinamicsdb',
        password: 'aaabcde1409',
      ));

      var results = await conn.query('SELECT * FROM FormatosFormularios WHERE proyecto_id = ?', [widget.projectId]);

      setState(() {
        _formatosFormularios = results.map((row) => {
          'id': row['id'],
          'pregunta': row['pregunta'],
          'tipo_dato': row['tipo_dato'],
        }).toList();

        _respuestasControllers = Map.fromEntries(
          _formatosFormularios.map((formato) => MapEntry(formato['id'], TextEditingController()))
        );

        _isLoading = false;
      });

      await conn.close();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar los datos del proyecto: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> checkInternetConnection() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _enviarRespuestas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    bool isConnected = await checkInternetConnection();

    if (isConnected) {
      try {
        final conn = await MySqlConnection.connect(ConnectionSettings(
          host: '72.167.33.202',
          port: 3306,
          user: 'alfred',
          db: 'idinamicsdb',
          password: 'aaabcde1409',
        ));

        for (var formato in _formatosFormularios) {
          int id = formato['id'];
          String respuesta = _respuestasControllers[id]?.text ?? '';

          await conn.query(
            'INSERT INTO respuestas (respuesta) VALUES (?)',
            [respuesta]
          );
        }

        await conn.close();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Respuestas enviadas exitosamente')),
        );

        _limpiarFormulario();
      } catch (e) {
        setState(() {
          _errorMessage = 'Error al enviar las respuestas: $e';
        });
      }
    } else {
      await _guardarRespuestasLocalmente();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _guardarRespuestasLocalmente() async {
    List<Map<String, dynamic>> respuestas = [];
    for (var formato in _formatosFormularios) {
      int id = formato['id'];
      String respuesta = _respuestasControllers[id]?.text ?? '';
      respuestas.add({
        'id': id,
        'respuesta': respuesta,
      });
    }

    await responseBox.add(respuestas);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Respuestas guardadas localmente')),
    );

    _limpiarFormulario();
  }

  void _limpiarFormulario() {
    for (var controller in _respuestasControllers.values) {
      controller.clear();
    }
    setState(() {}); // Actualizar la UI para reflejar los campos vacíos
  }

  Future<void> _sincronizarRespuestasLocales() async {
    bool isConnected = await checkInternetConnection();
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay conexión a internet')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final conn = await MySqlConnection.connect(ConnectionSettings(
        host: '72.167.33.202',
        port: 3306,
        user: 'alfred',
        db: 'idinamicsdb',
        password: 'aaabcde1409',
      ));

      for (var i = 0; i < responseBox.length; i++) {
        List<Map<String, dynamic>> respuestas = responseBox.getAt(i);
        for (var respuesta in respuestas) {
          await conn.query(
            'INSERT INTO respuestas (respuesta) VALUES (?)',
            [respuesta['respuesta']]
          );
        }
        await responseBox.deleteAt(i);
        i--; // Ajustar el índice ya que eliminamos un elemento
      }

      await conn.close();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Respuestas sincronizadas exitosamente')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al sincronizar las respuestas: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Formulario - $projectName'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('ID del Proyecto: ${widget.projectId}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),
                    if (_errorMessage != null)
                      Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                    ..._formatosFormularios.map((formato) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formato['pregunta'], style: TextStyle(fontWeight: FontWeight.bold)),
                        TextField(
                          controller: _respuestasControllers[formato['id']],
                          decoration: InputDecoration(labelText: 'Respuesta'),
                        ),
                        SizedBox(height: 10),
                      ],
                    )).toList(),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _enviarRespuestas,
                      child: Text('Enviar Respuestas'),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _sincronizarRespuestasLocales,
                      child: Text('Sincronizar Respuestas Locales'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}