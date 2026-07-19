import '../models/faq_item.dart';

/// Datos de FAQ basados en fuentes científicas para cuidadores de pacientes
/// oncológicos pediátricos.
///
/// Fuentes:
/// - POHEMA Foundation: "Fiebre en el niño con cáncer" (2018)
/// - SEOP Protocolo: "Fiebre y neutropenia en el paciente oncológico" (2019)
/// - MSKCC: "Managing Neutropenia for Pediatric Patients" (2024)
/// - IDSA/Pediatric Fever and Neutropenia Guidelines (Lehrnbecher et al., 2023)
/// - AEPap: "Guía de detección temprana - Cáncer en niños y adolescentes"
/// - PAHO/OMS: "Iniciativa Mundial contra el Cáncer Infantil" (2025)
/// - Memorial Sloan Kettering Cancer Center patient education materials
/// - Fundación POHEMA: Protoclos de atención en oncología pediátrica

const List<FaqItem> defaultFaqItems = [
  // ── Fiebre ──
  FaqItem(
    id: 'faq-1',
    category: 'Fiebre',
    question: '¿Qué temperatura se considera fiebre?',
    answer:
        'Se considera fiebre en pacientes oncológicos pediátricos cuando la '
        'temperatura axilar es ≥38,3 °C en una sola toma, o ≥38 °C mantenida '
        'durante una hora en dos determinaciones. La medición debe realizarse por '
        'vía axilar; no se recomienda la vía rectal en estos pacientes. Recuerde '
        'que la temperatura corporal varía a lo largo del día, siendo más alta en '
        'horas de la tarde.',
  ),
  FaqItem(
    id: 'faq-2',
    category: 'Fiebre',
    question: '¿Cuándo debo llamar al médico por fiebre?',
    answer:
        'Contacte al equipo médico de inmediato si la temperatura supera los '
        '38 °C, si la fiebre persiste por más de 24 horas, o si el niño presenta '
        'otros síntomas como dificultad para respirar, vómitos persistentes, '
        'dolor intenso, escalofríos, confusión o signos de deshidratación. '
        'En pacientes neutropénicos, la fiebre puede ser el ÚNICO signo de una '
        'infección grave, por lo que siempre debe ser evaluada urgentemente.',
  ),

  // ── Medicamentos ──
  FaqItem(
    id: 'faq-3',
    category: 'Medicamentos',
    question: '¿Cómo administro los medicamentos correctamente?',
    answer:
        'Siga siempre las indicaciones exactas del equipo médico. Administre los '
        'medicamentos a las horas prescritas, respetando las dosis y la vía de '
        'administración (oral, intravenosa, etc.). Nunca ajuste las dosis por su '
        'cuenta, ni suspenda un tratamiento sin indicación médica. Mantenga un '
        'registro de cada dosis administrada con la fecha y hora exactas. Si el '
        'niño vomita dentro de las 2 horas después de una dosis oral, consulte '
        'al médico.',
  ),
  FaqItem(
    id: 'faq-4',
    category: 'Medicamentos',
    question: '¿Qué hago si olvido una dosis?',
    answer:
        'Si olvida una dosis, administre el medicamento tan pronto como lo '
        'recuerde, a menos que esté muy cerca de la siguiente dosis programada '
        '(menos de la mitad del intervalo). Nunca duplique la dosis para '
        'compensar la olvidada. En caso de duda, contacte al equipo médico. '
        'Si el niño está bajo tratamiento con quimioterapia, es especialmente '
        'importante no perder dosis, ya que el esquema terapéutico depende de '
        'la adherencia al tratamiento.',
  ),

  // ── Controles ──
  FaqItem(
    id: 'faq-5',
    category: 'Controles',
    question: '¿Con qué frecuencia debo medir la temperatura?',
    answer:
        'Se recomienda medir la temperatura al menos 2 a 3 veces al día: por la '
        'mañana, al mediodía y por la noche, especialmente durante los períodos '
        'de neutropenia (cuando los glóbulos blancos están bajos después de la '
        'quimioterapia). Si el niño presenta síntomas, se siente caliente o '
        'presenta malestar general, aumente la frecuencia a cada 4 horas. '
        'Utilice siempre termómetro digital y registre los valores en la app.',
  ),

  // ── Señales de alerta ──
  FaqItem(
    id: 'faq-6',
    category: 'Señales de alerta',
    question: '¿Cuáles son las señales de alerta que requieren atención urgente?',
    answer:
        'Contacte de inmediato al equipo médico si observa: fiebre ≥38 °C, '
        'sangrado inusual (encías, nariz, orina con sangre), dificultad para '
        'respirar, vómitos persistentes que no permiten la hidratación, '
        'deshidratación (orina escasa, sin lágrimas, boca seca), dolor intenso '
        'que no cede, cambios en el estado de conciencia (somnolencia '
        'excesiva, confusión), convulsiones, o signos de infección en heridas '
        'o catéter (enrojecimiento, hinchazón, pus). En pacientes neutropénicos, '
        'estas señales pueden aparecer súbitamente y evolucionar rápidamente.',
  ),

  // ── Alimentación ──
  FaqItem(
    id: 'faq-7',
    category: 'Alimentación',
    question: '¿Qué alimentos son seguros durante el tratamiento?',
    answer:
        'Ofrezca alimentos bien cocidos y lavados adecuadamente. Evite alimentos '
        'crudos o poco cocidos (carnes, pescados, huevos, frutas sin pelar, '
        'ensaladas crudas). Lave bien las frutas y verduras que se consuman '
        'crudas. Mantenga una hidratación adecuada con agua y líquidos '
        'seguros. Evite alimentos de vendedores ambulantes o con higiene '
        'dudosa. Consulte con el nutricionista del equipo médico para un plan '
        'alimentario personalizado según el tratamiento del niño.',
  ),

  // ── Higiene ──
  FaqItem(
    id: 'faq-8',
    category: 'Higiene',
    question: '¿Qué cuidados de higiene debo tener con mi hijo?',
    answer:
        'Lave sus manos frecuentemente (tanto el cuidador como el niño), '
        'especialmente antes de comer y después de ir al baño. Mantenga las '
        'superficies de la casa limpias. Bañe al niño diariamente con productos '
        'suaves, evitando heridas abiertas. Cuide la higiene bucal con cepillo '
        'de cerdas suaves. Evite el contacto con personas enfermas y asegúrese '
        'de que el niño use mascarilla en espacios públicos si el médico lo '
        'indica. Evite el contacto con mascotas y sus excretas. Mantenga las '
        'uñas del niño cortas y limpias.',
  ),
];
