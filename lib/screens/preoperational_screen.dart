import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../repositories/inspection_repository.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../widgets/app_background.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

// Modelo para una pregunta del quiz
enum QuestionType { yesNo, textInput, checklist }

class QuizQuestion {
  String key;
  String label;
  String? initialValue;
  TextEditingController controller;
  bool isEditing = false;
  QuestionType type;

  QuizQuestion({
    required this.key,
    required this.label,
    this.initialValue,
    this.type = QuestionType.yesNo,
  }) : controller = TextEditingController(text: initialValue ?? '');
}

class PreoperationalScreen extends StatefulWidget {
  const PreoperationalScreen({super.key});

  @override
  _PreoperationalScreenState createState() => _PreoperationalScreenState();
}

class _PreoperationalScreenState extends State<PreoperationalScreen> {
  final PageController _pageController = PageController();
  bool _isLoading = true;
  bool _hasVehicle = true;

  final Map<String, dynamic> _inspectionData = {};
  List<QuizQuestion> _allQuestions = [];
  int _currentIndex = 0;

  // índice para navegar entre subsecciones del checklist
  int _checklistSectionIndex = 0;

  final Map<String, List<String>> _inspectionItems = {
    'NIVELES': [
      'nivel_refrigerante',
      'nivel_frenos',
      'nivel_aceite_motor',
      'nivel_hidraulico',
      'nivel_limpiavidrios'
    ],
    'LUCES': [
      'luces_altas',
      'luces_bajas',
      'luces_direccionales',
      'luces_freno',
      'luces_reversa',
      'luces_parqueo'
    ],
    'EQUIPO DE CARRETERA': [
      'equipo_extintor',
      'equipo_tacos',
      'equipo_herramienta',
      'equipo_linterna',
      'equipo_gato',
      'equipo_botiquin'
    ],
    'VARIOS': [
      'varios_llantas',
      'varios_bateria',
      'varios_rines',
      'varios_cinturon',
      'varios_pito',
      'varios_freno_emergencia',
      'varios_espejos',
      'varios_plumillas',
      'varios_panoramico'
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    // Inicializar checklist sin valores por defecto
    for (var section in _inspectionItems.values) {
      for (var item in section) {
        _inspectionData[item] = null; // No seleccionado
      }
    }
  }

  final InspectionRepository _inspectionRepo = InspectionRepository();

  Future<void> _loadInitialData() async {
    try {
      final apiService = ApiService();
      final user = await apiService.getProfile();

      // 🚨 Verificar si el usuario tiene vehículo asignado
      if (user.vehicle == null) {
        setState(() {
          _hasVehicle = false;
          _isLoading = false;
        });
        Future.microtask(() => _showNoVehicleDialog());
        return;
      }

      setState(() {
        _allQuestions = _buildQuestions(user);
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

  void _showNoVehicleDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Vehículo no asignado"),
        content: const Text(
            "Actualmente no tienes un vehículo asignado. Solicita a tu supervisor que te asigne uno para poder continuar con la inspección."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const NoVehicleScreen()),
              );
            },
            child: const Text("Entendido"),
          ),
        ],
      ),
    );
  }

  List<QuizQuestion> _buildQuestions(User user) {
    return [
      QuizQuestion(
          key: 'kilometraje_actual',
          label: '¿Cuál es el kilometraje actual?',
          type: QuestionType.textInput),
      QuizQuestion(
          key: 'licencia_conductor',
          label: 'Número de Licencia',
          initialValue: user.licenciaConduccion),
      QuizQuestion(
          key: 'placa_vehiculo',
          label: 'Placa del Vehículo',
          initialValue: user.vehicle?.placa),
      QuizQuestion(
          key: 'modelo_vehiculo',
          label: 'Modelo del Vehículo',
          initialValue: user.vehicle?.modelo),
      QuizQuestion(
          key: 'marca_vehiculo',
          label: 'Tipo de Vehículo',
          initialValue: user.vehicle?.marca),
      QuizQuestion(
          key: 'tarjeta_propiedad',
          label: 'N° Tarjeta de Propiedad',
          initialValue: user.vehicle?.tarjetaPropiedad),
      QuizQuestion(
          key: 'fecha_tecnomecanica',
          label: 'Vencimiento Tecnomecánica',
          initialValue: _formatDate(user.vehicle?.fechaTecnomecanica)),
      QuizQuestion(
          key: 'fecha_soat',
          label: 'Vencimiento SOAT',
          initialValue: _formatDate(user.vehicle?.fechaSoat)),
      QuizQuestion(
          key: 'mantenimiento_preventivo_taller',
          label: 'Taller Mantenimiento',
          initialValue: user.vehicle?.mantenimientoPreventivoTaller),
      QuizQuestion(
          key: 'fecha_mantenimiento',
          label: 'Próximo Mantenimiento',
          initialValue: _formatDate(user.vehicle?.fechaMantenimiento)),
      QuizQuestion(
          key: 'fecha_ultimo_aceite',
          label: 'Último Cambio de Aceite',
          initialValue: _formatDate(user.vehicle?.fechaUltimoAceite)),
      QuizQuestion(
          key: 'checklist',
          label: 'Revisión de Componentes',
          type: QuestionType.checklist),
      QuizQuestion(
          key: 'observaciones',
          label: 'Observaciones Finales',
          type: QuestionType.textInput),
    ];
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return DateFormat('dd/MM/yyyy').format(date);
  }
  void _nextQuestion() {
    final question = _allQuestions[_currentIndex];

    // Validar kilometraje_actual obligatorio
    if (question.key == 'kilometraje_actual' &&
        question.controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El kilometraje actual es obligatorio'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // 🚨 Validación del checklist
    if (question.type == QuestionType.checklist) {
      String currentSection =
          _inspectionItems.keys.elementAt(_checklistSectionIndex);
      List<String> items = _inspectionItems[currentSection]!;

      // Revisar si hay ítems sin responder en la sección actual
      bool hayPendientes =
          items.any((item) => _inspectionData[item] == null);

      if (hayPendientes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Debes responder todos los ítems de la sección "$currentSection" antes de continuar'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Si no es la última sección → avanzar a la siguiente
      if (_checklistSectionIndex < _inspectionItems.length - 1) {
        setState(() => _checklistSectionIndex++);
        return;
      }

      // 🚨 Validación final: todo el checklist debe estar completo
      bool hayNulos = _inspectionItems.values
          .expand((list) => list)
          .any((item) => _inspectionData[item] == null);

      if (hayNulos) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Debes responder todos los ítems del checklist antes de finalizar'),
              backgroundColor: Colors.red),
        );
        return;
      }
    }

    // Avanzar al siguiente paso
    if (_currentIndex < _allQuestions.length - 1) {
      setState(() {
        _currentIndex++;
        if (_allQuestions[_currentIndex].type == QuestionType.checklist) {
          _checklistSectionIndex = 0;
        }
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      _submitForm();
    }
  }

  Future<void> _submitForm() async {
    setState(() => _isLoading = true);

    for (var question in _allQuestions) {
      if (question.type != QuestionType.checklist) {
        _inspectionData[question.key] = question.controller.text;
      }
    }

    try {
      await _inspectionRepo.submitInspection(_inspectionData);
      SyncService.instance.sync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Inspección guardada exitosamente.'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Inspección guardada localmente. Se sincronizará cuando haya conexión.'),
              backgroundColor: Colors.orange),
        );
        SyncService.instance.sync();
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()));
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
            : !_hasVehicle
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _allQuestions.length,
                          itemBuilder: (context, index) {
                            return _buildQuestionCard(_allQuestions[index]);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: LinearProgressIndicator(
                          value: (_currentIndex + 1) / _allQuestions.length,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildQuestionCard(QuizQuestion question) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildQuestionContent(question),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionContent(QuizQuestion question) {
    if (question.type == QuestionType.textInput) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(question.label,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextFormField(
            controller: question.controller,
            decoration: InputDecoration(
                labelText: 'Ingresar ${question.label}',
                border: const OutlineInputBorder()),
            keyboardType: question.key == 'kilometraje_actual'
                ? TextInputType.number
                : TextInputType.text,
            maxLines: question.key == 'observaciones' ? 5 : 1,
            onFieldSubmitted: (_) => _nextQuestion(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _nextQuestion,
            child: const Text('Siguiente'),
          ),
        ],
      );
    }

    if (question.type == QuestionType.checklist) {
      String currentSection =
          _inspectionItems.keys.elementAt(_checklistSectionIndex);
      List<String> items = _inspectionItems[currentSection]!;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$currentSection",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: ListView(
              children: items.map((itemKey) => _buildInspectionRow(itemKey)).toList(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _nextQuestion,
            child: Text(_checklistSectionIndex == _inspectionItems.length - 1
                ? "Finalizar Checklist"
                : "Siguiente Sección"),
          ),
        ],
      );
    }

    // Sí/No
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
            '¿${question.label} sigue siendo "${question.initialValue ?? 'N/A'}"?',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        if (question.isEditing)
          TextFormField(
            controller: question.controller,
            decoration: InputDecoration(
                labelText: 'Nuevo valor para ${question.label}',
                border: const OutlineInputBorder()),
            onFieldSubmitted: (_) => _nextQuestion(),
          ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => setState(() => question.isEditing = true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(100, 100),
                  shape: const CircleBorder()),
              child: const Text('NO',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () {
                question.controller.text = question.initialValue ?? '';
                _nextQuestion();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(100, 100),
                  shape: const CircleBorder()),
              child: const Text('SI',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (question.isEditing)
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: FilledButton(
              onPressed: _nextQuestion,
              child: const Text('Confirmar y Siguiente'),
            ),
          ),
      ],
    );
  }

  Widget _buildInspectionRow(String key) {
    final label = key
        .replaceAll('_', ' ')
        .split(' ')
        .map((str) => str[0].toUpperCase() + str.substring(1))
        .join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
            borderRadius: BorderRadius.circular(8),
            children: const [
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('B')),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('M')),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('N/A')),
            ],
          ),
        ],
      ),
    );
  }
}

/// 🚨 Nueva pantalla cuando no hay vehículo asignado
class NoVehicleScreen extends StatelessWidget {
  const NoVehicleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
             const Icon(Icons.directions_car, size: 48, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text(
                "No tienes un vehículo asignado",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (_) => const PreoperationalScreen()),
                  );
                },
                label: const Text("Refrescar"),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await AuthService.instance.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                label: const Text("Cerrar Sesión"),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
