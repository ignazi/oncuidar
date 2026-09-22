/// Semana de entrega inyectada en compilación: --dart-define=SEMANA=N.
/// Sin el define, el valor por defecto es 3 (app completa actual).
const int semanaEntrega = int.fromEnvironment('SEMANA', defaultValue: 3);

/// True cuando la semana de entrega actual ya incluye la semana [n].
bool habilitadaDesdeSemana(int n) => semanaEntrega >= n;
