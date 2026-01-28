/// Configurações globais da API
///
/// Mantém um único lugar para alterar ambiente (Render/Local) e timeouts.
library api_config;

const String apiBaseUrl = 'https://projetoagendamento-n20v.onrender.com';
const Duration apiTimeout = Duration(seconds: 15);
