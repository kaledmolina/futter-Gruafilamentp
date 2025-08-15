import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/app_background.dart';

// Modelo para una pregunta del quiz
class QuizQuestion {
  String key;
  String label;
  String? initialValue;
  TextEditingController controller;
  bool isEditing = false;
  bool isConfirmed = false;

  QuizQuestion({
    required this.key,
    required this.label,
    this.initialValue,
  }) : controller = TextEditingController(text: initialValue ?? '');
}

class PreoperationalScreen extends StatefulWidget {
  const PreoperationalScreen({super.key});

  @override
  _PreoperationalScreenState createState() => _PreoperationalScreenState();
}

class _PreoperationalScreenState extends State<PreoperationalScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  User? _user;
  
  final Map<String, String> _inspectionData = {};
  final TextEditingController _kilometrajeController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();

  late List<QuizQuestion> _generalInfoQuestions;
  
  final Map<String, List<String>> _inspectionItems = {
    'NIVELES': ['nivel_refrigerante', 'nivel_frenos', 'nivel_aceite_motor', 'nivel_hidraulico', 'nivel_limpiavidrios'],
    'LUCES': ['luces_altas', 'luces_bajas', 'luces_direccionales', 'luces_freno', 'luces_reversa', 'luces_parqueo'],
    'EQUIPO DE CARRETERA': ['equipo_extintor', 'equipo_tacos', 'equipo_herramienta', 'equipo_linterna', 'equipo_gato', 'equipo_botiquin'],
    'VARIOS': ['varios_llantas', 'varios_bateria', 'varios_rines', 'varios_cinturon', 'varios_pito', 'varios_freno_emergencia', 'varios_espejos', 'varios_plumillas', 'varios_panoramico'],
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    for (var section in _inspectionItems.values) {
      for (var item in section) {
        _inspectionData[item] = 'B'; // Por defecto 'Bueno'
      }
    }
  }

  Future<void> _loadInitialData() async {
    try {
      final user = await ApiService().getProfile();
      setState(() {
        _user = user;
        _generalInfoQuestions = [
          QuizQuestion(key: 'licencia_conductor', label: 'Número de Licencia', initialValue: user.licenciaConduccion),
          QuizQuestion(key: 'placa_vehiculo', label: 'Placa del Vehículo', initialValue: user.vehicle?.placa),
          QuizQuestion(key: 'modelo_vehiculo', label: 'Modelo del Vehículo', initialValue: user.vehicle?.modelo),
          QuizQuestion(key: 'tipo_vehiculo', label: 'Tipo de Vehículo', initialValue: user.vehicle?.marca),
          QuizQuestion(key: 'tarjeta_propiedad', label: 'N° Tarjeta de Propiedad', initialValue: user.vehicle?.tarjetaPropiedad),
          QuizQuestion(key: 'fecha_tecnomecanica', label: 'Vencimiento Tecnomecánica', initialValue: _formatDate(user.vehicle?.fechaTecnomecanica)),
          QuizQuestion(key: 'fecha_soat', label: 'Vencimiento SOAT', initialValue: _formatDate(user.vehicle?.fechaSoat)),
          QuizQuestion(key: 'mantenimiento_preventivo_taller', label: 'Taller Mantenimiento', initialValue: user.vehicle?.mantenimientoPreventivoTaller),
          QuizQuestion(key: 'fecha_mantenimiento', label: 'Próximo Mantenimiento', initialValue: _formatDate(user.vehicle?.fechaMantenimiento)),
          QuizQuestion(key: 'fecha_ultimo_aceite', label: 'Último Cambio de Aceite', initialValue: _formatDate(user.vehicle?.fechaUltimoAceite)),
        ];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos del perfil: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return DateFormat('dd/MM/yyyy').format(date);
  }
  
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    // Recolecta los datos del quiz
    for (var question in _generalInfoQuestions) {
      _inspectionData[question.key] = question.controller.text;
    }
    _inspectionData['kilometraje_actual'] = _kilometrajeController.text;
    _inspectionData['observaciones'] = _observacionesController.text;

    try {
      await ApiService().submitInspection(_inspectionData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspección guardada exitosamente.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Inspección Preoperacional'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildGeneralInfoSection(),
                    ..._inspectionItems.entries.map((entry) => _buildChecklistSection(entry.key, entry.value)).toList(),
                    _buildFinalSection(),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _isLoading ? const CircularProgressIndicator() : const Text('Guardar Inspección'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGeneralInfoSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: const Text('INFORMACIÓN GENERAL', style: TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextFormField(
                  controller: _kilometrajeController,
                  decoration: const InputDecoration(labelText: 'Kilometraje Actual', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (value) => (value?.isEmpty ?? true) ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 16),
                ..._generalInfoQuestions.map((q) => _buildQuizQuestion(q)).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizQuestion(QuizQuestion question) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿${question.label} sigue siendo "${question.initialValue ?? 'N/A'}"?'),
          const SizedBox(height: 8),
          if (!question.isEditing)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => question.isEditing = true),
                    child: const Text('No'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => setState(() => question.isConfirmed = true),
                    style: FilledButton.styleFrom(
                      backgroundColor: question.isConfirmed ? Colors.green : null,
                    ),
                    child: const Text('Sí'),
                  ),
                ),
              ],
            ),
          if (question.isEditing)
            TextFormField(
              controller: question.controller,
              decoration: InputDecoration(labelText: 'Nuevo valor', border: const OutlineInputBorder()),
            ),
        ],
      ),
    );
  }
  
  Widget _buildChecklistSection(String title, List<String> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: items.map((key) => _buildInspectionRow(key)).toList(),
      ),
    );
  }

  Widget _buildInspectionRow(String key) {
    final label = key.replaceAll('_', ' ').split(' ').map((str) => str[0].toUpperCase() + str.substring(1)).join(' ');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          ToggleButtons(
            isSelected: [
              _inspectionData[key] == 'B',
              _inspectionData[key] == 'M',
              _inspectionData[key] == 'N/A',
            ],
            onPressed: (index) {
              setState(() {
                _inspectionData[key] = ['B', 'M', 'N/A'][index];
              });
            },
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('B')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('M')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('N/A')),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFinalSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextFormField(
          controller: _observacionesController,
          decoration: const InputDecoration(
            labelText: 'Observaciones',
            hintText: 'Describa cualquier anomalía encontrada...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
      ),
    );
  }
}
