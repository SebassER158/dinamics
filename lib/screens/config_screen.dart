import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:mysql1/mysql1.dart';

class ConfigScreen extends StatefulWidget {
  @override
  _ConfigScreenState createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final TextEditingController _projectIdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _formatosFormularios = [];
  Map<int, TextEditingController> _respuestasControllers = {};

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _respuestasControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadProjects() async {
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

      var results = await conn.query('SELECT * FROM proyectos');

      setState(() {
        _projects = results.map((row) => {
          'id': row['id'],
          'nombre': row['nombre_proyecto'],
        }).toList();
        _isLoading = false;
      });

      await conn.close();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar los proyectos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProjectConfig() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String projectId = _projectIdController.text;

    if (projectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('El ID del proyecto no puede estar vacío')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final conn = await MySqlConnection.connect(ConnectionSettings(
        host: '72.167.33.202',
        port: 3306,
        user: 'alfred',
        db: 'idinamicsdb',
        password: 'aaabcde1409',
      ));

      var results = await conn.query('SELECT * FROM FormatosFormularios WHERE proyecto_id = ?', [projectId]);

      setState(() {
        _formatosFormularios = results.map((row) => {
          'id': row['id'],
          'proyecto_id': row['proyecto_id'],
          'pregunta': row['pregunta'],
          'tipo_dato': row['tipo_dato'],
        }).toList();

        // Crear controladores para cada pregunta
        _respuestasControllers = Map.fromEntries(
          _formatosFormularios.map((formato) => MapEntry(formato['id'], TextEditingController()))
        );
      });

      var box = await Hive.openBox('project_data');
      await box.put('form_data', _formatosFormularios);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('project_id', projectId);

      await conn.close();

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Datos cargados exitosamente')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al conectarse a la base de datos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _enviarRespuestas() async {
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

      for (var formato in _formatosFormularios) {
        int id = formato['id'];
        int proyectoId = formato['proyecto_id'];
        String respuesta = _respuestasControllers[id]?.text ?? '';

        await conn.query(
          'INSERT INTO respuestas (proyecto_id, formulario_id, respuesta) VALUES (?, ?, ?)',
          [proyectoId, id, respuesta]
        );
      }

      await conn.close();

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Respuestas enviadas exitosamente')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al enviar las respuestas: $e';
        _isLoading = false;
      });
    }
  }

  TextInputType _getKeyboardType(String tipo_dato) {
    switch (tipo_dato.toLowerCase()) {
      case 'int':
      case 'float':
        return TextInputType.number;
      default:
        return TextInputType.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración del Proyecto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _projectIdController,
              decoration: InputDecoration(labelText: 'ID del Proyecto'),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveProjectConfig,
                    child: Text('Cargar Datos del Proyecto'),
                  ),
            if (_errorMessage != null) ...[
              SizedBox(height: 20),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            ],
            SizedBox(height: 20),
            Text('Proyectos disponibles:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: _projects.length,
                itemBuilder: (context, index) {
                  final project = _projects[index];
                  return ListTile(
                    title: Text('ID: ${project['id']} - Nombre: ${project['nombre']}'),
                    onTap: () {
                      _projectIdController.text = project['id'].toString();
                    },
                  );
                },
              ),
            ),
            if (_formatosFormularios.isNotEmpty) ...[
              SizedBox(height: 20),
              Text('Preguntas del Formulario:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: _formatosFormularios.length,
                  itemBuilder: (context, index) {
                    final formato = _formatosFormularios[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formato['pregunta'], style: TextStyle(fontWeight: FontWeight.bold)),
                        TextField(
                          controller: _respuestasControllers[formato['id']],
                          decoration: InputDecoration(labelText: 'Respuesta'),
                          keyboardType: _getKeyboardType(formato['tipo_dato']),
                        ),
                        SizedBox(height: 10),
                      ],
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: _enviarRespuestas,
                child: Text('Enviar Respuestas'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
