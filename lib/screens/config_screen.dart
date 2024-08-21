import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysql1/mysql1.dart';
import 'package:dinamics_app/screens/form_screen.dart';

class ConfigScreen extends StatefulWidget {
  @override
  _ConfigScreenState createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
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

  Future<void> _selectProject(String projectId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('project_id', projectId);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => FormScreen(projectId: projectId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuración del Proyecto'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ID del Proyecto', style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadProjects,
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
                    onTap: () => _selectProject(project['id'].toString()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}