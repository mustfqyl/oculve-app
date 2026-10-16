import 'package:flutter/widgets.dart';

/// Reviewed interface translations. User-defined server and account values are
/// passed through unchanged unless they exactly match a product label.
class AppStrings {
  static const _es = <String, String>{
    'Tray & Window': 'Bandeja y Ventana',
    'CLICK ACTIONS': 'ACCIONES DE CLIC',
    'Left click': 'Clic izquierdo',
    'Right click': 'Clic derecho',
    'Open or hide app': 'Abrir u ocultar la aplicación',
    'Show tray menu': 'Mostrar menú de la bandeja',
    'On Linux, click behavior depends on the desktop environment.':
        'En Linux, el comportamiento del clic depende del entorno de escritorio.',
    'WINDOW BEHAVIOR': 'COMPORTAMIENTO DE LA VENTANA',
    'Hide when focus is lost': 'Ocultar al perder el foco',
    'Keep the app running in the tray.': 'Mantén la aplicación en la bandeja.',
    'When closing the window': 'Al cerrar la ventana',
    'Hide to tray': 'Ocultar en la bandeja',
    'TRAY APPEARANCE': 'ASPECTO DE LA BANDEJA',
    'Status indicator': 'Indicador de estado',
    'Connection state': 'Estado de conexión',
    'App icon': 'Icono de la aplicación',
    'MENU PREVIEW': 'VISTA PREVIA DEL MENÚ',
    'Preview of the tray menu.': 'Vista previa del menú de la bandeja.',
    'Could not save tray settings. Please try again.':
        'No se pudieron guardar los ajustes de la bandeja. Inténtalo de nuevo.',
    'Connection error': 'Error de conexión',
    'Loading statistics': 'Cargando estadísticas',
    'Loading': 'Cargando',
    'Preparing your account and servers…':
        'Preparando tu cuenta y tus servidores…',
    'Saving…': 'Guardando…',

    'macOS tunnel uses IPv4.': 'El túnel macOS utiliza IPv4.',
    'Retry interrupted sessions. Manual Disconnect cancels retries.':
        'Reintenta sesiones interrumpidas. Desconectar manualmente cancela los reintentos.',
    'Could not start LAN sharing. Check your address, port and password.':
        'No se pudo iniciar la compartición. Comprueba la dirección, puerto y contraseña.',

    'Provider': 'Proveedor',
    'Custom': 'Personalizado',
    'Custom DNS over HTTPS URL': 'URL DNS personalizada por HTTPS',
    'IP lookup': 'Consulta de IP',
    'Network-aware': 'Según la red',
    'Uses the address types available on your network.':
        'Consulta los tipos de dirección disponibles en tu red.',
    'Queries both IPv4 and IPv6 records.': 'Consulta registros IPv4 e IPv6.',
    'Queries IPv4 records only.': 'Consulta solo registros IPv4.',
    'Queries IPv6 records only.': 'Consulta solo registros IPv6.',
    'SPLIT TUNNELING': 'TÚNEL DIVIDIDO',
    'Domain routing': 'Enrutamiento de dominios',
    'Route these domains': 'Enrutar estos dominios',
    'Route domains': 'Enrutar dominios',
    'Except selected': 'Excepto los seleccionados',
    'Only selected': 'Solo los seleccionados',
    'Except selected domains': 'Excepto los dominios seleccionados',
    'Only selected domains': 'Solo los dominios seleccionados',
    'Choose domains for VPN routing.':
        'Elige dominios para enrutar con la VPN.',
    'Websites outside VPN': 'Sitios fuera de la VPN',
    'No websites added': 'No hay sitios añadidos',
    'websites': 'sitios',
    'domains': 'dominios',
    'Domain': 'Dominio',
    'Add website': 'Añadir sitio',
    'These websites bypass the VPN. Changes apply after reconnecting.':
        'Estos sitios quedan fuera de la VPN. Los cambios se aplican al reconectar.',
    'CONNECTION': 'CONEXIÓN',
    'Automatic reconnect': 'Reconexión automática',
    'Retry an interrupted session. Manual Disconnect cancels retries. System tunnel recovery stays enabled.':
        'Reintenta sesiones interrumpidas. Desconectar manualmente cancela los reintentos. La recuperación del sistema sigue activa.',
    'Kill switch': 'Protección de conexión',
    'System-managed': 'Gestionada por el sistema',
    'Platform dependent': 'Depende de la plataforma',
    'System protection is armed.': 'La protección del sistema está activa.',
    'System protection activates when you connect.':
        'La protección del sistema se activa al conectar.',
    'Traffic protection stays enabled during tunnel recovery. Disconnecting manually ends the VPN session and its protection. Certain essential system traffic is exempted by macOS.':
        'La protección continúa durante la recuperación. Desconectar manualmente termina la sesión y su protección. macOS excluye cierto tráfico esencial del sistema.',
    'Traffic protection depends on your platform. System-level verification is required before this feature can be enabled.':
        'La protección depende de la plataforma. Requiere verificación a nivel del sistema antes de activarse.',
    'Windows installs system traffic protection before the VPN starts. It stays active during tunnel recovery and ends when you disconnect.':
        'Windows activa la protección de tráfico del sistema antes de iniciar la VPN. Se mantiene durante la recuperación del túnel y termina al desconectarte.',
    'Linux installs a firewall guard before VPN routing starts. It stays active during recovery and is removed when you stop the VPN.':
        'Linux activa un cortafuegos antes de iniciar el enrutamiento VPN. Se mantiene durante la recuperación y se retira al detener la VPN.',
    'TLS fragmentation': 'Fragmentación TLS',
    'For compatible connections': 'Para conexiones compatibles',
    'Available for VLESS Reality over TCP.':
        'Disponible para VLESS Reality sobre TCP.',
    'Fragmentation settings': 'Ajustes de fragmentación',
    'Only the TLS hello is fragmented. Smaller fragments or longer delays may reduce speed.':
        'Solo se fragmenta el saludo TLS. Los fragmentos pequeños o retrasos largos pueden reducir la velocidad.',
    'Only the TLS hello is fragmented. Settings save automatically; reconnect to apply. Smaller fragments or longer delays may reduce speed.':
        'Solo se fragmenta el saludo TLS. Los ajustes se guardan automáticamente y se aplican al reconectar. Los fragmentos pequeños o retrasos largos pueden reducir la velocidad.',
    'Fragment length (bytes)': 'Tamaño del fragmento (bytes)',
    'Delay (milliseconds)': 'Retraso (milisegundos)',
    'Maximum splits': 'Máximo de divisiones',
    '1–16384, for example 100-200': '1–16384, por ejemplo 100-200',
    '0–1000, for example 10-20': '0–1000, por ejemplo 10-20',
    '1–32, for example 3-6': '1–32, por ejemplo 3-6',
    'LOCAL NETWORK': 'RED LOCAL',
    'LAN proxy sharing': 'Compartir proxy en la red local',
    'Share VPN connection': 'Compartir conexión VPN',
    'HTTP and SOCKS5 proxy with password authentication.':
        'Proxy HTTP y SOCKS5 con contraseña.',
    'Local address': 'Dirección local',
    'Proxy port': 'Puerto del proxy',
    'Username': 'Usuario',
    'New password': 'Nueva contraseña',
    'Sharing is active.': 'Compartición activa.',
    'Sharing starts after the VPN connects. Reconnect after changes.':
        'La compartición comienza al conectar la VPN. Reconecta después de cambiar los ajustes.',
    'Sharing is off.': 'Compartición desactivada.',
    'Ready after reconnect': 'Disponible al reconectar',
    'LAN proxy sharing is currently available on macOS.':
        'La compartición del proxy está disponible actualmente en macOS.',
    'Set this address and port as the proxy on your other device. Both devices must be on the same local network. TCP traffic only; this does not create a Wi-Fi hotspot.':
        'Configura esta dirección y puerto como proxy en el otro dispositivo. Ambos deben estar en la misma red local. Solo tráfico TCP; no crea un punto de acceso Wi-Fi.',
    'When your computer starts': 'Al iniciar el equipo',
    'Oculve will not start automatically.':
        'Oculve no se iniciará automáticamente.',
    'Open Oculve without connecting to the VPN.':
        'Abrir Oculve sin conectar la VPN.',
    'Open Oculve and connect to the VPN automatically.':
        'Abrir Oculve y conectar la VPN automáticamente.',
    'Could not update startup settings.':
        'No se pudo cambiar el inicio automático.',
    'Could not load startup settings. Tap to retry.':
        'No se pudo cargar el inicio automático. Toca para reintentar.',
    'Could not connect at startup.': 'No se pudo conectar al iniciar.',
    'Off': 'Apagado',
    'Open': 'Abrir',
    'Connect': 'Conectar',
    'On': 'Activado',
    'ACCOUNT USAGE': 'USO DE LA CUENTA',
    'DATA USED': 'DATOS USADOS',
    'Data used in the current account period.':
        'Datos usados en el período actual de la cuenta.',
    'Active days (all time)': 'Días activos (histórico)',
    'Auto': 'Automático',
    'CURRENT PERIOD': 'PERIODO ACTUAL',
    'SESSION COUNTERS': 'CONTADORES DE SESIÓN',
    'SERVER USAGE': 'USO POR SERVIDOR',
    'active days, all time': 'días activos en total',
    'CURRENT SESSION': 'SESIÓN ACTUAL',
    '30 days': '30 días',
    '12 months': '12 meses',
    '30d': '30d',
    '12m': '12m',
    'Daily data usage': 'Uso diario de datos',
    'Monthly data usage': 'Uso mensual de datos',
    'Server usage': 'Uso por servidor',
    'View all servers': 'Ver todos los servidores',
    'Show fewer servers': 'Mostrar menos servidores',
    'No server usage yet.': 'Aún no hay uso por servidor.',
    'No usage recorded for this period.':
        'No hay uso registrado en este período.',
    'Startup': 'Inicio',
    'STARTUP': 'INICIO',
    'Launch at login': 'Abrir al iniciar sesión',
    'Open Oculve in the menu bar when you sign in. This does not connect the VPN.':
        'Abre Oculve en la barra de menús al iniciar sesión. No conecta la VPN.',
    'Approve Oculve in System Settings → General → Login Items.':
        'Autoriza Oculve en Ajustes del Sistema → General → Ítems de inicio.',
    'Refresh status': 'Actualizar estado',
    'Login startup is currently available on macOS.':
        'El inicio automático está disponible actualmente en macOS.',
    'Could not update login startup. Check System Settings.':
        'No se pudo actualizar el inicio automático. Comprueba los Ajustes del Sistema.',
    'DIAGNOSTICS': 'DIAGNÓSTICO',
    'Errors': 'Errores',
    'Warnings': 'Advertencias',
    'Detailed': 'Detallado',
    'Troubleshooting report': 'Informe de diagnóstico',
    'Export without account codes or credentials.':
        'Exportar sin códigos de cuenta ni credenciales.',
    'Export troubleshooting report': 'Exportar informe de diagnóstico',
    'Changes apply after reconnecting.':
        'Los cambios se aplican al reconectar.',
    'Restore defaults': 'Restaurar valores predeterminados',
    'Restore connection defaults?': '¿Restaurar los ajustes de conexión?',
    'This resets DNS, bypass websites, fragmentation, reconnect preferences and LAN sharing. Login startup stays unchanged.':
        'Restablece DNS, sitios excluidos, fragmentación, reconexión y compartición local. El inicio automático se conserva.',
    'Save DNS': 'Guardar DNS',
    'DNS saved. Reconnect to apply.': 'DNS guardado. Reconecta para aplicarlo.',
    'Could not load LAN sharing settings.':
        'No se pudieron cargar los ajustes de compartición local.',
    'Could not save connection settings. Check your input and try again.':
        'No se pudieron guardar los ajustes. Comprueba los datos e inténtalo de nuevo.',
    'Could not save the troubleshooting report.':
        'No se pudo guardar el informe de diagnóstico.',
    'Check your LAN address, port, username and password. Use at least 12 characters for the password.':
        'Comprueba la dirección local, puerto, usuario y contraseña. La contraseña debe tener al menos 12 caracteres.',
    'LAN sharing saved. Reconnect to apply these settings.':
        'Compartición guardada. Reconecta para aplicar los ajustes.',
    'LAN sharing stopped.': 'Compartición local detenida.',
    'LAN sharing stopped. Check your local network.':
        'La compartición se detuvo. Comprueba la red local.',
    'Proxy address copied.': 'Dirección del proxy copiada.',
    'Enter valid numeric ranges for fragment length, delay and splits.':
        'Introduce rangos válidos para tamaño, retraso y divisiones.',
    'Enter a valid HTTPS DNS URL without credentials or a fragment.':
        'Introduce una URL DNS HTTPS válida sin credenciales ni fragmento.',
    'macOS currently carries IPv4 only. IPv6 lookups are unavailable in this tunnel.':
        'El túnel macOS actualmente solo transporta IPv4. Las consultas IPv6 no están disponibles.',

    'Created on': 'Creada el',
    'Two-factor authentication on': 'Autenticación de dos factores activada',
    'Two-factor authentication off':
        'Autenticación de dos factores desactivada',

    'SUBSCRIPTION': 'SUSCRIPCIÓN',
    'Expires on': 'Vence el',
    'Data usage': 'Uso de datos',
    'Manage subscription': 'Gestionar suscripción',
    'ACCOUNT SETTINGS': 'AJUSTES DE CUENTA',
    'Show access code': 'Mostrar código de acceso',
    'Hide access code': 'Ocultar código de acceso',
    'Copy access code': 'Copiar código de acceso',

    'Statistics unavailable': 'Estadísticas no disponibles',
    'Could not reach the service securely. Check your connection.':
        'No se pudo conectar con el servicio de forma segura. Comprueba tu conexión.',
    'Could not generate an access code.':
        'No se pudo generar un código de acceso.',
    'Your access code or session is invalid. Please sign in again.':
        'Tu código de acceso o sesión no es válido. Vuelve a iniciar sesión.',
    'Access denied. Check your account status.':
        'Acceso denegado. Comprueba el estado de tu cuenta.',
    'Subscription access was rejected. Your device limit may be reached.':
        'Se rechazó el acceso a la suscripción. Es posible que hayas alcanzado el límite de dispositivos.',
    'Could not read your device identity. Please restart the app and try again.':
        'No se pudo leer la identidad de tu dispositivo. Reinicia la aplicación e inténtalo de nuevo.',
    'The service rejected this request. Check your details and try again.':
        'El servicio rechazó la solicitud. Comprueba tus datos e inténtalo de nuevo.',
    'Enter valid website domains, such as example.com.':
        'Introduce dominios válidos, como example.com.',
    'Choose a supported DNS provider.': 'Elige un proveedor DNS compatible.',
    'Add at most 32 bypass domains.':
        'Añade como máximo 32 dominios fuera de la VPN.',
    'Choose at most 100 apps to bypass.':
        'Elige como máximo 100 aplicaciones fuera de la VPN.',
    'Something went wrong. Please try again.':
        'Algo salió mal. Inténtalo de nuevo.',
    'Too many attempts. Please wait and try again.':
        'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
    'The service is temporarily unavailable. Please try again.':
        'El servicio no está disponible temporalmente. Inténtalo de nuevo.',
    'Could not connect to the service. Check your internet connection and try again.':
        'No se pudo conectar con el servicio. Comprueba tu conexión a internet e inténtalo de nuevo.',
    'The service returned an invalid response. Please try again.':
        'El servicio devolvió una respuesta no válida. Inténtalo de nuevo.',
    'Unable to load your account': 'No se pudo cargar tu cuenta',
    'Could not load app routing settings.':
        'No se pudo cargar la configuración de las aplicaciones.',
    'Statistics are currently unavailable. Try again shortly.':
        'Las estadísticas no están disponibles. Inténtalo de nuevo más tarde.',
    'Your account was created, but server setup is still finishing. Sign in again shortly.':
        'Tu cuenta se creó, pero la configuración del servidor aún está en curso. Inicia sesión de nuevo en unos momentos.',
    'Could not create your sign-in key. Please try again.':
        'No se pudo crear tu clave de acceso. Inténtalo de nuevo.',
    'Could not load connection settings.':
        'No se pudo cargar la configuración de conexión.',
    'The request could not be completed. Please try again.':
        'No se pudo completar la solicitud. Inténtalo de nuevo.',
    'Could not establish the VPN. Please try again.':
        'No se pudo establecer la VPN. Inténtalo de nuevo.',
    'SEE THE UNSEEN': 'Descubre lo que no se ve',
    'Your private connection starts here.': 'Tu conexión privada empieza aquí.',
    'Set up your access key, save it somewhere safe, then choose a location for your first private connection.':
        'Configura tu clave de acceso, guárdala en un lugar seguro y elige una ubicación para tu primera conexión privada.',
    'Already have an account?': '¿Ya tienes una cuenta?',
    'Create your Oculve account in three quick steps.':
        'Crea tu cuenta de Oculve en tres pasos sencillos.',
    'No email or password required.': 'No necesitas correo ni contraseña.',
    'Your sign-in key': 'Tu clave de acceso',
    'Generating your access code': 'Generando tu código de acceso',
    'This is your access code. Tap it to copy; continuing saves it to your device.':
        'Este es tu código de acceso. Tócalo para copiarlo; al continuar, se guardará en tu dispositivo.',
    'Ready to create your account?': '¿Todo listo para crear tu cuenta?',
    'Your access code is saved. Keep the file private; you’ll need it each time you sign in.':
        'Tu código de acceso está guardado. Mantén el archivo en privado; lo necesitarás cada vez que inicies sesión.',
    'Access code saved to this device':
        'Código de acceso guardado en este dispositivo',
    'Choose a place to save your code before continuing.':
        'Elige dónde guardar el código antes de continuar.',
    'Could not save your code. Choose a location and try again.':
        'No se pudo guardar el código. Elige una ubicación e inténtalo de nuevo.',
    'Saving code…': 'Guardando código…',
    'oculve-access-code.txt': 'oculve-access-code.txt',
    'Use this code every time you sign in to Oculve.':
        'Usa este código cada vez que inicies sesión en Oculve.',
    'YOUR ACCESS CODE': 'TU CÓDIGO DE ACCESO',
    'Copied': 'Copiado',
    'Saved to file': 'Guardado en un archivo',
    'Save code': 'Guardar código',
    'Oculve can’t recover a lost code.':
        'Oculve no puede recuperar un código perdido.',
    'Keep your code safe': 'Guarda tu código en un lugar seguro',
    'Your code is the only way to sign in. Oculve can’t restore it if it’s lost.':
        'Este código es la única forma de iniciar sesión. Oculve no puede recuperarlo si lo pierdes.',
    'I’ve saved my access code somewhere safe.':
        'He guardado mi código de acceso en un lugar seguro.',
    'By continuing, you agree to the ': 'Al continuar, aceptas los ',
    'Terms of Service': 'Términos del servicio',
    'Get my access code': 'Obtener mi código de acceso',
    'Continue setup': 'Continuar configuración',
    'Try again to create your code.':
        'No se pudo crear el código. Inténtalo de nuevo.',
    'One access code keeps your account yours.':
        'Un código de acceso mantiene tu cuenta bajo tu control.',
    'No email or password needed.': 'No necesitas correo ni contraseña.',
    'One last step': 'Un último paso',
    'Keep your access code somewhere safe. You will use it whenever you sign in.':
        'Guarda tu código de acceso en un lugar seguro. Lo necesitarás cada vez que inicies sesión.',
    'Your code is the only way to access your account.':
        'Este código es la única forma de acceder a tu cuenta.',
    'Create my account': 'Crear mi cuenta',
    'Saved': 'Guardado',
    'Welcome to Oculve': 'Bienvenido a Oculve',
    'Start your secure connection in a few simple steps.':
        'Inicia tu conexión segura en unos sencillos pasos.',
    'Already have an account? Sign in': 'Ya tengo una cuenta · Iniciar sesión',
    'No email. No password. Just your access code.':
        'Sin correo ni contraseña. Solo tu código de acceso.',
    'This code is your sign-in key': 'Este código es tu clave de acceso',
    'Use this code to sign in to Oculve. No email or password needed.':
        'Usa este código para entrar en Oculve. No necesitas correo ni contraseña.',
    'Copy code': 'Copiar código',
    'Save to file': 'Guardar en un archivo',
    'I have saved my access code somewhere safe.':
        'He guardado mi código de acceso en un lugar seguro.',
    'If you lose this code, you cannot recover your account.':
        'Si pierdes este código, no podrás recuperar tu cuenta.',
    '2FA active': '2FA activa',
    '2FA off': '2FA desactivada',
    '2FA / TOTP': '2FA / TOTP',
    'ACCESS CODE': 'CÓDIGO DE ACCESO',
    'Account': 'Cuenta',
    'Account usage': 'Uso de la cuenta',
    'Active': 'Activa',
    'Active days': 'Días activos',
    'All time': 'todo el tiempo',
    'Relative to most-used server': 'En relación con el servidor más usado',
    'Session totals are unavailable until connection data is received.':
        'Los totales de sesión no están disponibles hasta recibir datos de conexión.',
    'Session data not received yet.': 'Aún no se han recibido datos de sesión.',
    'Add rule': 'Añadir regla',
    'Advanced core options': 'Opciones avanzadas del núcleo',
    'Advanced matchers': 'Coincidencias avanzadas',
    'Advanced routing rules': 'Reglas de enrutamiento avanzadas',
    'Advanced TLS': 'TLS avanzado',
    'Advanced XHTTP and XMUX': 'XHTTP y XMUX avanzados',
    'Alphabetical': 'Alfabético',
    'Allow invalid certificates': 'Permitir certificados no válidos',
    'Appearance': 'Apariencia',
    'Automatic selection': 'Selección automática',
    'Back': 'Volver',
    'Back to sign in': 'Volver al inicio de sesión',
    'Balance': 'Saldo',
    'Best ping': 'Menor latencia',
    'By proceeding, you agree to our ': 'Al continuar, aceptas nuestros ',
    'Cancel': 'Cancelar',
    'Sign in with passkey': 'Iniciar sesión con clave de acceso',
    'Verifying passkey…': 'Verificando la clave de acceso…',
    'Complete verification using your device.':
        'Completa la verificación con tu dispositivo.',
    'This device cannot use your passkey. Set up an authenticator code in your web account to sign in here.':
        'Este dispositivo no puede usar tu clave de acceso. Configura un autenticador en tu cuenta web para iniciar sesión aquí.',
    'Passkey is unavailable on this device. Use your authenticator code.':
        'La clave de acceso no está disponible en este dispositivo. Usa tu código de autenticación.',
    'No matching passkey is available on this device. Use your authenticator code.':
        'No hay una clave de acceso compatible en este dispositivo. Usa tu código de autenticación.',
    'Passkey is not configured for this app yet. Use your authenticator code.':
        'La clave de acceso aún no está configurada para esta aplicación. Usa tu código de autenticación.',
    'Passkey verification failed. Try again or use your authenticator code.':
        'La verificación falló. Inténtalo de nuevo o usa tu código de autenticación.',
    'Use your passkey to continue securely.':
        'Usa tu clave de acceso para continuar de forma segura.',
    'Certificate SHA-256 pin(s)': 'Huella(s) SHA-256 del certificado',
    'Certificate verification name': 'Nombre para verificar el certificado',
    'Change password': 'Cambiar contraseña',
    'Choose Android apps that use your regular connection.':
        'Elige las aplicaciones Android que usarán tu conexión normal.',
    'Choose how XHTTP carries upload and download.':
        'Elige cómo XHTTP transporta las subidas y descargas.',
    'Choose location': 'Elegir ubicación',
    'Client Logs': 'Registros del cliente',
    'ClientHello fingerprint': 'Huella ClientHello',
    'Close': 'Cerrar',
    'CONNECT': 'CONECTAR',
    'CONNECTED': 'CONECTADO',
    'CONNECTING': 'CONECTANDO',
    'CONNECTING…': 'CONECTANDO…',
    'Refreshing servers…': 'Actualizando servidores…',
    'Could not refresh servers. Showing the last saved locations.':
        'No se pudieron actualizar los servidores. Se muestran las ubicaciones guardadas.',
    'DISCONNECT': 'DESCONECTAR',
    'STOPPING': 'DETENIENDO',
    'STOPPING…': 'DETENIENDO…',
    'PROTECTED': 'PROTEGIDO',
    'UNPROTECTED': 'DESPROTEGIDO',
    'Connected. Tap to disconnect.': 'Conectado. Toca para desconectar.',
    'Connected': 'Conectado',
    'Disconnected': 'Desconectado',
    'Connect VPN': 'Conectar VPN',
    'Disconnect VPN': 'Desconectar VPN',
    'VPN connection in progress': 'Conexión VPN en curso',
    'Tap to connect': 'Toca para conectar',
    'Tap to retry.': 'Toca para volver a intentarlo.',
    'Dismiss': 'Cerrar',
    'The VPN runtime failed. Check permissions and connection settings.':
        'El servicio VPN ha fallado. Comprueba los permisos y la conexión.',
    'VPN disconnected. Reconnect to protect your traffic.':
        'VPN desconectada. Reconéctate para proteger tu tráfico.',
    'Your subscription is not active.': 'Tu suscripción no está activa.',
    'No compatible servers are available.':
        'No hay servidores compatibles disponibles.',
    'VPN permission was not granted.': 'No se concedió el permiso de VPN.',
    'Linux VPN support is not installed. Finish the Linux setup steps before connecting.':
        'El soporte VPN de Linux no está instalado. Completa los pasos de configuración de Linux antes de conectar.',
    'Windows needs administrator permission to create the VPN tunnel. Close Oculve and reopen it with Run as administrator.':
        'Windows necesita permisos de administrador para crear el túnel VPN. Cierra Oculve y vuelve a abrirlo con “Ejecutar como administrador”.',
    'Connection timed out. Please try another location.':
        'Se agotó el tiempo de conexión. Prueba otra ubicación.',
    'Could not establish the VPN. Check your account, VPN permission and server availability.':
        'No se pudo establecer la VPN. Comprueba tu cuenta, el permiso de VPN y la disponibilidad del servidor.',
    'The VPN could not be stopped. Check the system VPN settings.':
        'No se pudo detener la VPN. Comprueba los ajustes de VPN del sistema.',
    'Sorted by ping. Tap to sort alphabetically.':
        'Ordenado por latencia. Toca para ordenar alfabéticamente.',
    'Sorted alphabetically. Tap to sort by ping.':
        'Ordenado alfabéticamente. Toca para ordenar por latencia.',
    'Connection': 'Conexión',
    'Connection Settings': 'Ajustes de conexión',
    'Most users can leave these settings as they are.':
        'La mayoría puede dejar estos ajustes tal como están.',
    'DNS & network': 'DNS y red',
    'Choose how names are looked up and which IP versions to use.':
        'Elige cómo resolver nombres y qué versiones de IP usar.',
    'Choose which sites or Android apps bypass the VPN.':
        'Elige qué sitios o aplicaciones Android omiten la VPN.',
    'Secure connection': 'Conexión segura',
    'Keep the server defaults unless troubleshooting a connection.':
        'Mantén los valores predeterminados del servidor, salvo que estés solucionando un problema de conexión.',
    'Optional connection adjustments. Defaults work for most people.':
        'Los ajustes de conexión son opcionales. La configuración predeterminada funciona para la mayoría.',
    'Connection fingerprint': 'Huella de conexión',
    'Connection fragmentation': 'Fragmentación de la conexión',
    'Connection optimization': 'Optimización de conexión',
    'Connection policy': 'Política de conexión',
    'Continue': 'Continuar',
    'Core behavior & statistics': 'Comportamiento y estadísticas del núcleo',
    'Core version guard': 'Límite de versión del núcleo',
    'Create account': 'Crear cuenta',
    'Current cycle began': 'Inicio del ciclo actual',
    'Current period': 'Periodo actual',
    'Current VPN session': 'Sesión VPN actual',
    'Custom Xray JSON': 'JSON personalizado de Xray',
    'DNS & name resolution': 'DNS y resolución de nombres',
    'DNS resolver': 'Resolución DNS',
    'DNS servers': 'Servidores DNS',
    'Delete account': 'Eliminar cuenta',
    'Delete account?': '¿Eliminar la cuenta?',
    'This permanently deletes your Oculve account and VPN access.':
        'Esto eliminará permanentemente tu cuenta de Oculve y el acceso VPN.',
    'This action cannot be undone. Type the phrase below to confirm.':
        'Esta acción no se puede deshacer. Escribe la frase para confirmar.',
    'Confirmation phrase': 'Frase de confirmación',
    'Delete my account': 'ELIMINAR MI CUENTA',
    'Delete rule': 'Eliminar regla',
    'Diagnostics': 'Diagnóstico',
    'Direct connection': 'Conexión directa',
    'DPI Bypass': 'Evitar DPI',
    'Disconnect before changing location.':
        'Desconéctate antes de cambiar de ubicación.',
    'Devices': 'Dispositivos',
    'Domains': 'Dominios',
    'Downloaded': 'Descargado',
    'Downloads': 'Descargas',
    'Enable 2FA': 'Activar 2FA',
    'Enable for this location': 'Activar para esta ubicación',
    'Enable Mux': 'Activar Mux',
    'Enable sniffing': 'Activar inspección',
    'English': 'Inglés',
    'Enter your access code to access your secure network infrastructure.':
        'Introduce tu código de acceso para entrar en tu red segura.',
    'Enter your authenticator or recovery code to continue securely.':
        'Introduce tu código de autenticación o recuperación para continuar de forma segura.',
    'Expires': 'Caduca',
    'Excluded domains': 'Dominios excluidos',
    'Excluded IPs': 'IP excluidas',
    'Fingerprint': 'Huella',
    'Handshake method': 'Método de enlace',
    'Help & resources': 'Ayuda y recursos',
    'I will permanently lose access': 'perderé el acceso de forma permanente',
    'Language': 'Idioma',
    'Last 12 months': 'Últimos 12 meses',
    'Last 30 days': 'Últimos 30 días',
    'Usage history': 'Historial de uso',
    'Last seen': 'Última actividad',
    'Lifetime tracked': 'Total registrado',
    'Light': 'Claro',
    'Locations': 'Ubicaciones',
    'Log level': 'Nivel de registro',
    'Log out': 'Cerrar sesión',
    'Manage plan': 'Gestionar plan',
    'Maximum connections': 'Conexiones máximas',
    'Maximum concurrent requests': 'Solicitudes simultáneas máximas',
    'Maximum HTTP request count': 'Número máximo de solicitudes HTTP',
    'Maximum POST body bytes': 'Tamaño máximo del cuerpo POST (bytes)',
    'Maximum TLS version': 'Versión TLS máxima',
    'Metadata-only': 'Solo metadatos',
    'Minimum POST interval (ms)': 'Intervalo mínimo entre POST (ms)',
    'Mode': 'Modo',
    'Mux and XUDP': 'Mux y XUDP',
    'Network behavior': 'Comportamiento de red',
    'New to Oculve? Create account!': '¿Nuevo en Oculve? Crea una cuenta!',
    'No servers available. Check your subscription.':
        'No hay servidores disponibles. Revisa tu suscripción.',
    'Optimal': 'Óptimo',
    'Password': 'Contraseña',
    'Ping': 'Latencia',
    'Passkeys': 'Claves de acceso',
    'Per-user download statistics': 'Estadísticas de descarga por usuario',
    'Per-user online statistics': 'Estadísticas de conexión por usuario',
    'Per-user upload statistics': 'Estadísticas de subida por usuario',
    'Ping unavailable': 'Latencia no disponible',
    'Privacy': 'Privacidad',
    'Protocol & identity': 'Protocolo e identidad',
    'Refresh statistics': 'Actualizar estadísticas',
    'Registered devices': 'Dispositivos registrados',
    'Remaining': 'Restante',
    'Route traffic to': 'Enrutar tráfico a',
    'Routing & privacy': 'Enrutamiento y privacidad',
    'Save': 'Guardar',
    'Save for this location': 'Guardar para esta ubicación',
    'Security': 'Seguridad',
    'Security methods': 'Métodos de seguridad',
    'Server': 'Servidor',
    'Server authentication parameter':
        'Parámetro de autenticación del servidor',
    'Server address discovery': 'Detección de la dirección del servidor',
    'Servers': 'Servidores',
    'Settings': 'Ajustes',
    'Sign in': 'Iniciar sesión',
    'Sign up': 'Crear cuenta',
    'Sites outside the VPN': 'Sitios fuera de la VPN',
    'Sort': 'Ordenar',
    'Sort alphabetically': 'Ordenar alfabéticamente',
    'Sort by ping': 'Ordenar por latencia',
    'Statistics': 'Estadísticas',
    'Statistics are unavailable': 'Las estadísticas no están disponibles',
    'Stopping': 'DETENIENDO',
    'Support': 'Soporte',
    'System': 'Sistema',
    'Theme': 'Tema',
    'Traffic': 'Tráfico',
    'Traffic appearance': 'Apariencia del tráfico',
    'Traffic inspection': 'Inspección del tráfico',
    'Traffic sniffing': 'Inspección del tráfico',
    'Transport': 'Transporte',
    'Connection options': 'Opciones de conexión',
    'Transport security': 'Seguridad del transporte',
    'Try again': 'Intentar de nuevo',
    'DNS': 'DNS',
    'Choose an encrypted DNS provider and lookup address family.':
        'Elige un proveedor DNS cifrado y la familia de direcciones para las consultas.',
    'DNS address family': 'Familia de direcciones DNS',
    'TLS identity': 'Identidad TLS',
    'This changes the TLS ClientHello only. Keep the server default unless you need another profile.':
        'Esto solo cambia el ClientHello de TLS. Mantén el valor predeterminado del servidor salvo que necesites otro perfil.',
    'Split tunneling': 'Túnel dividido',
    'Choose domains or apps that use your regular connection.':
        'Elige los dominios o aplicaciones que usarán tu conexión normal.',
    'Fragmentation': 'Fragmentación',
    'Optional TLS hello splitting for supported TCP servers.':
        'División opcional del saludo TLS para servidores TCP compatibles.',
    'Choose how much connection information is recorded.':
        'Elige cuánta información de conexión se registra.',
    'Access and DNS query logs are disabled.':
        'Los registros de acceso y de consultas DNS están desactivados.',
    'TRY AGAIN': 'INTENTAR DE NUEVO',
    'Your traffic is protected.': 'Tu tráfico está protegido.',
    'Setting up a secure connection…': 'Preparando una conexión segura…',
    'Disconnecting securely…': 'Desconectando de forma segura…',
    'Connection failed. Tap to retry.':
        'Error de conexión. Toca para intentarlo de nuevo.',
    'Tap to protect your connection.': 'Toca para proteger tu conexión.',
    'Turkish': 'Turco',
    'UDP/443 behavior': 'Comportamiento UDP/443',
    'Unlimited': 'Ilimitado',
    'Unlimited data': 'Datos ilimitados',
    'Unknown': 'Desconocido',
    'Uploaded': 'Subido',
    'VERIFICATION CODE': 'CÓDIGO DE VERIFICACIÓN',
    'Verify your account': 'Verifica tu cuenta',
    'Welcome Back': 'Te damos la bienvenida',
    'XHTTP transport': 'Transporte XHTTP',
    'Xray core': 'Núcleo Xray',
    'Xray logs': 'Registros de Xray',
    'Access code copied.': 'Código de acceso copiado.',
    'Access code visible. Tap to copy.': 'Código visible. Toca para copiarlo.',
    'Access code hidden. Tap to reveal.': 'Código oculto. Toca para mostrarlo.',
    'Active subscription': 'Suscripción activa',
    'Address family': 'Familia de direcciones',
    'Address interleave': 'Intercalado de direcciones',
    'Address race delay': 'Retraso entre intentos de direcciones',
    'ALPN': 'ALPN',
    'Avoid reading application payloads. HTTP, TLS and QUIC content sniffers are disabled.':
        'Evita inspeccionar el contenido de las aplicaciones. La inspección HTTP, TLS y QUIC está desactivada.',
    'BBR, CUBIC and Reno are applied on Linux only.':
        'BBR, CUBIC y Reno solo se aplican en Linux.',
    'Buffer size': 'Tamaño del búfer',
    'Certificate checks, ALPN, ECH, key logging and curves':
        'Certificados, ALPN, ECH, registro de claves y curvas',
    'Client option used by stream-up and stream-one.':
        'Opción del cliente utilizada por stream-up y stream-one.',
    'Comma-separated protocol names.':
        'Nombres de protocolo separados por comas.',
    'Connection idle timeout (seconds)':
        'Tiempo límite de inactividad (segundos)',
    'Controls how Xray resolves the proxy server domain.':
        'Controla cómo Xray resuelve el dominio del servidor proxy.',
    'Controls how Xray resolves IPv4 and IPv6.':
        'Controla cómo Xray resuelve IPv4 e IPv6.',
    'Controls how Xray reuses TCP connections and carries UDP. Changes apply after reconnecting.':
        'Controla la reutilización de conexiones TCP y el transporte UDP de Xray. Se aplica al reconectar.',
    'Core default': 'Valor predeterminado del núcleo',
    'Custom HTTP headers (JSON object)':
        'Encabezados HTTP personalizados (objeto JSON)',
    'Disable DNS cache': 'Desactivar caché DNS',
    'Disable fallback': 'Desactivar alternativa',
    'Disable fallback on domain match':
        'Desactivar alternativa al coincidir el dominio',
    'Disabled': 'Desactivado',
    'Do not try another resolver after a failure.':
        'No pruebes otro resolvedor si se produce un error.',
    'ECH config or DNS lookup URL': 'Configuración ECH o URL de consulta DNS',
    'EDNS client subnet (optional)': 'Subred de cliente EDNS (opcional)',
    'Enabled': 'Activado',
    'FakeDNS': 'FakeDNS',
    'Force IPv4': 'Forzar IPv4',
    'Force IPv4, then IPv6': 'Forzar IPv4 y luego IPv6',
    'Force IPv6': 'Forzar IPv6',
    'Force IPv6, then IPv4': 'Forzar IPv6 y luego IPv4',
    'Happy Eyeballs': 'Conexión rápida IPv4/IPv6',
    'HTTP headers / method / path': 'Encabezados, método y ruta HTTP',
    'HTTP host override (optional)': 'Host HTTP personalizado (opcional)',
    'IPv4 only': 'Solo IPv4',
    'IPv4, then IPv6': 'IPv4 y luego IPv6',
    'IPv6 only': 'Solo IPv6',
    'IPv6, then IPv4': 'IPv6 y luego IPv4',
    'Keep matching domains on their selected resolver.':
        'Mantén los dominios coincidentes en el resolvedor seleccionado.',
    'Leave both off to match TCP and UDP.':
        'Deja ambos desactivados para coincidir con TCP y UDP.',
    'Leave empty for privacy': 'Déjalo vacío para proteger tu privacidad',
    'Limit parallel TCP connection attempts.':
        'Limita los intentos de conexión TCP en paralelo.',
    'Maximum concurrent attempts': 'Máximo de intentos simultáneos',
    'Maximum reusable seconds': 'Tiempo máximo de reutilización (segundos)',
    'Multiplex TCP connections': 'Multiplexar conexiones TCP',
    'Network interface': 'Interfaz de red',
    'One Xray domain matcher per line.':
        'Un comparador de dominios Xray por línea.',
    'One IP, CIDR or geoip matcher per line.':
        'Un comparador IP, CIDR o geoip por línea.',
    'Parallel DNS queries': 'Consultas DNS paralelas',
    'Prefer IPv6': 'Preferir IPv6',
    'Profile default': 'Valor predeterminado del perfil',
    'Proxy server DNS strategy': 'Estrategia DNS del servidor proxy',
    'Race multiple configured resolvers.':
        'Prueba en paralelo los resolvedores configurados.',
    'Record traffic received by Xray outbounds.':
        'Registrar el tráfico recibido por las salidas de Xray.',
    'Record traffic sent by Xray outbounds.':
        'Registrar el tráfico enviado por las salidas de Xray.',
    'Record traffic sent by local Xray inbounds.':
        'Registrar el tráfico enviado por las entradas locales de Xray.',
    'Record traffic received by local Xray inbounds.':
        'Registrar el tráfico recibido por las entradas locales de Xray.',
    'Requires an Xray inbound user with an email identity.':
        'Requiere un usuario de entrada Xray con identidad de correo electrónico.',
    'Serve stale DNS answers': 'Usar respuestas DNS caducadas',
    'Stale answer lifetime': 'Vigencia de las respuestas caducadas',
    'TCP Fast Open': 'TCP Fast Open',
    'TLS session resumption': 'Reanudación de sesión TLS',
    'Use system hosts file': 'Usar el archivo hosts del sistema',
    'VLESS Encryption': 'Cifrado VLESS',
    'XHTTP host override (optional)': 'Host XHTTP personalizado (opcional)',
    'd remaining': ' días restantes',
    'days remaining': 'días restantes',
    'passkeys': 'claves de acceso',
    'registered': 'registrados',
    'GB left': 'GB restantes',
    'Next billing': 'Próxima facturación',
    'DPI BYPASS': 'EVITAR DPI',
    'Strategy': 'Estrategia',
    'Split': 'Dividir',
    'Split & reorder': 'Dividir y reordenar',
    'Reorder': 'Reordenar',
    'Reorder & split': 'Reordenar y dividir',
    'Retry DPI Bypass': 'Reintentar evasión DPI',
    'Clears learned strategies. Reconnects if active.':
        'Borra las estrategias aprendidas. Reconecta si está activo.',
    'Time left': 'Tiempo restante',
    'Are you sure?': '¿Estás seguro?',
    'Deleting…': 'Eliminando…',
    '2FA enabled': '2FA activada',
    'passkey': 'clave de acceso',
    'Limited': 'Limitada',
    'Expired': 'Caducada',
    'On hold': 'En pausa',
    'Account Setup': 'Configuración de la cuenta',
    'Save your unique access code to initialize your Oculve account.':
        'Guarda tu código de acceso único para crear tu cuenta de Oculve.',
    'YOUR UNIQUE ACCESS CODE': 'TU CÓDIGO DE ACCESO ÚNICO',
    'GO TO DASHBOARD': 'IR AL PANEL',
    'Terms': 'Términos',
    'Scan this code with your authenticator app, then enter the six-digit code it generates.':
        'Escanea este código con tu aplicación de autenticación e introduce el código de seis dígitos que genera.',
    'MANUAL SETUP KEY': 'CLAVE DE CONFIGURACIÓN MANUAL',
    'These one-time codes will not be shown again. Keep them somewhere safe.':
        'Estos códigos de un solo uso no volverán a mostrarse. Guárdalos en un lugar seguro.',
    'Copy': 'Copiar',
    'Save file': 'Guardar archivo',
    'Authenticator code': 'Código de autenticación',
    'No registered devices': 'No hay dispositivos registrados',
    'Remove TOTP': 'Quitar TOTP',
    'Set up authenticator': 'Configurar autenticador',
    'Copy setup key': 'Copiar clave de configuración',
    'Save recovery codes': 'Guardar códigos de recuperación',
    'Done': 'Listo',
    'DELETE MY ACCOUNT': 'ELIMINAR MI CUENTA',
    'Reset all devices': 'Restablecer todos los dispositivos',
    'Remove passkey': 'Quitar clave de acceso',
    'Connection events': 'Eventos de conexión',
    'Refresh diagnostics': 'Actualizar diagnóstico',
    'APP EVENTS': 'EVENTOS DE LA APLICACIÓN',
    'No connection attempts yet.': 'Aún no hay intentos de conexión.',
    'TCP PING CHECKS': 'PRUEBAS DE PING TCP',
    'No server ping checks have been recorded.':
        'No se han registrado pruebas de ping de servidores.',
    'XRAY DIAGNOSTICS': 'DIAGNÓSTICO DE XRAY',
    'Save transport settings': 'Guardar ajustes de transporte',
    'Must match the server inbound.':
        'Debe coincidir con la entrada del servidor.',
    '0-RTT is faster when the server permits it.':
        '0-RTT es más rápido cuando el servidor lo permite.',
    'Paste the client parameter from xray mlkem768':
        'Pega el parámetro de cliente de xray mlkem768',
    'This value is specific to the server. The client cannot create a matching server parameter by itself.':
        'Este valor es específico del servidor. El cliente no puede crear por sí solo un parámetro de servidor coincidente.',
    'Padding and delay pattern (optional)':
        'Patrón de relleno y demora (opcional)',
    'Use dot-separated probability-min-max blocks; leave empty for Xray defaults.':
        'Usa bloques probabilidad-mínimo-máximo separados por puntos; déjalo vacío para usar los valores predeterminados de Xray.',
    'Path override (optional)': 'Ruta personalizada (opcional)',
    'Header padding bytes': 'Bytes de relleno de encabezado',
    'Leave blank unless using this limit':
        'Déjalo en blanco si no usas este límite',
    'Connection reuse limit': 'Límite de reutilización de conexión',
    '0 means core default': '0 significa valor predeterminado del núcleo',
    'HTTP keepalive period (seconds)': 'Intervalo de keepalive HTTP (segundos)',
    '0 uses core default; -1 disables':
        '0 usa el valor predeterminado del núcleo; -1 lo desactiva',
    'Separate download settings (JSON)':
        'Ajustes de descarga independientes (JSON)',
    'The upload and download sides can use different IPs, domains, transports or security.':
        'La carga y la descarga pueden usar distintas IP, dominios, transportes o medidas de seguridad.',
    'Additional client extra settings (JSON)':
        'Ajustes adicionales del cliente (JSON)',
    'Client-supported XHTTP fields only. SSE response options and buffered-post limits are server-side.':
        'Solo admite los campos XHTTP compatibles con el cliente. Las opciones de respuesta SSE y los límites de buffered-post se configuran en el servidor.',
    'Native uTLS Hello profile (optional)':
        'Perfil nativo uTLS Hello (opcional)',
    'Overrides the browser preset above. Use a Hello name supported by this Xray core.':
        'Sustituye el perfil de navegador anterior. Usa un nombre Hello compatible con este núcleo de Xray.',
    'Disables certificate verification and is unsafe on public networks.':
        'Desactiva la verificación de certificados y no es seguro en redes públicas.',
    'Leave on Core default unless required.':
        'Mantén el valor predeterminado del núcleo salvo que sea necesario cambiarlo.',
    'Cipher suites (optional)': 'Conjuntos de cifrado (opcional)',
    'Separate Go cipher suite names with colons.':
        'Separa los nombres de conjuntos de cifrado de Go con dos puntos.',
    'Curve preferences': 'Preferencias de curvas',
    'Supported: CurveP256, CurveP384, CurveP521, X25519 and ML-KEM hybrids.':
        'Compatibles: CurveP256, CurveP384, CurveP521, X25519 e híbridos ML-KEM.',
    '64 hex characters; multiple separated by commas':
        '64 caracteres hexadecimales; separa varios con comas',
    'Disable system CA roots':
        'Desactivar las autoridades certificadoras del sistema',
    'Trust only CA certificates present in this profile or below.':
        'Confiar solo en los certificados de autoridad presentes en este perfil o en el contenido siguiente.',
    'Custom CA certificate (PEM)':
        'Certificado de autoridad personalizado (PEM)',
    'Adding a custom CA makes Xray trust only this CA for TLS verification.':
        'Al añadir una autoridad personalizada, Xray solo confiará en ella para verificar TLS.',
    'Requires server support; this does not enable TLS 0-RTT.':
        'Requiere compatibilidad del servidor; esto no activa TLS 0-RTT.',
    'TLS key log file path': 'Ruta del archivo de registro de claves TLS',
    'For Wireshark diagnostics only. Anyone with this file can decrypt captured traffic.':
        'Solo para diagnósticos de Wireshark. Cualquiera que tenga este archivo puede descifrar el tráfico capturado.',
    'Reduce a TCP handshake when the network allows it':
        'Reduce un intercambio TCP cuando la red lo permite',
    'Keepalive idle': 'Inactividad del keepalive',
    'Seconds before an idle TCP connection is checked':
        'Segundos antes de comprobar una conexión TCP inactiva',
    'Keepalive interval': 'Intervalo de keepalive',
    'Seconds between TCP keepalive probes':
        'Segundos entre comprobaciones keepalive de TCP',
    'Optional. Empty lets Xray choose the network.':
        'Opcional. Si se deja vacío, Xray elige la red.',
    'Save interface': 'Guardar interfaz',
    'Send through local IP': 'Enviar mediante IP local',
    'Optional source address; leave empty for automatic binding.':
        'Dirección de origen opcional; déjala vacía para enlazar automáticamente.',
    'Save source address': 'Guardar dirección de origen',
    'Races IPv4 and IPv6 TCP addresses. Requires an IP DNS strategy.':
        'Prueba en paralelo direcciones TCP IPv4 e IPv6. Requiere una estrategia DNS basada en IP.',
    'Delay before trying the next IP family.':
        'Demora antes de probar la siguiente familia de IP.',
    'Try IPv6 addresses before IPv4.':
        'Probar direcciones IPv6 antes que IPv4.',
    'Mix IPv4 and IPv6 addresses while racing.':
        'Alternar direcciones IPv4 e IPv6 durante las pruebas.',
    'TCP maximum segment size': 'Tamaño máximo de segmento TCP',
    'Optional MSS for TCP packets.': 'MSS opcional para paquetes TCP.',
    'TCP user timeout': 'Tiempo de espera TCP del usuario',
    'How long unacknowledged data may remain.':
        'Tiempo que los datos sin confirmar pueden permanecer pendientes.',
    'TCP congestion control': 'Control de congestión TCP',
    'TCP receive window clamp': 'Límite de ventana de recepción TCP',
    'Optional maximum advertised TCP window.':
        'Tamaño máximo opcional de la ventana TCP anunciada.',
    'Multipath TCP': 'TCP multipath',
    'Linux kernel 5.6 or later.': 'Se requiere Linux kernel 5.6 o posterior.',
    'Handshake timeout (seconds)':
        'Tiempo de espera del intercambio (segundos)',
    'Uplink-only timeout (seconds)':
        'Tiempo de espera solo de subida (segundos)',
    'Downlink-only timeout (seconds)':
        'Tiempo de espera solo de descarga (segundos)',
    'Request buffer (KB)': 'Búfer de solicitud (KB)',
    'Optional; Xray defaults depend on device architecture.':
        'Opcional; los valores predeterminados de Xray dependen de la arquitectura del dispositivo.',
    'Inbound upload statistics': 'Estadísticas de subida de entrada',
    'Inbound download statistics': 'Estadísticas de descarga de entrada',
    'Outbound upload statistics': 'Estadísticas de subida de salida',
    'Outbound download statistics': 'Estadísticas de descarga de salida',
    'Controls whether Xray resolves IPv4 and IPv6.':
        'Controla si Xray resuelve IPv4 e IPv6.',
    'Custom hosts': 'Hosts personalizados',
    'Resolve through the configured servers each time.':
        'Resolver cada vez mediante los servidores configurados.',
    'Return cached answers while refreshing them.':
        'Devolver respuestas almacenadas mientras se actualizan.',
    'Seconds after the cached DNS record expires.':
        'Segundos tras el vencimiento del registro DNS almacenado.',
    'Add device hosts mappings to Xray DNS.':
        'Añadir las asignaciones hosts del dispositivo al DNS de Xray.',
    'Give domains synthetic IPs so Xray can recover their names.':
        'Asignar IP sintéticas a los dominios para que Xray pueda recuperar sus nombres.',
    'TCP concurrency': 'Concurrencia TCP',
    'Maximum concurrent streams on one connection':
        'Máximo de flujos simultáneos en una conexión',
    'XUDP concurrency': 'Concurrencia XUDP',
    'UDP streams carried by XUDP': 'Flujos UDP transportados por XUDP',
    'Choose how QUIC traffic uses XUDP':
        'Elige cómo se transporta el tráfico QUIC mediante XUDP',
    'Minimum version': 'Versión mínima',
    'Maximum version': 'Versión máxima',
    'FinalMask object': 'Objeto FinalMask',
    'Xray config object': 'Objeto de configuración Xray',
    'One per line. Also supports geosite: and keyword:.':
        'Uno por línea. También admite geosite: y keyword:.',
    'Destination ports': 'Puertos de destino',
    'Source ports': 'Puertos de origen',
    'Local inbound ports': 'Puertos de entrada locales',
    'Inbound tags': 'Etiquetas de entrada',
    'Supported by Xray on Windows and Linux.':
        'Compatible con Xray en Windows y Linux.',
    'Values are regular expressions. Requires traffic sniffing.':
        'Los valores son expresiones regulares. Requiere inspección del tráfico.',
    'Rule name (optional)': 'Nombre de la regla (opcional)',
    'Webhook URL': 'URL del webhook',
    'Xray sends matching connection details to this address.':
        'Xray envía a esta dirección los detalles de las conexiones coincidentes.',
    'Duplicate suppression (seconds)': 'Supresión de duplicados (segundos)',
    'Webhook headers (JSON object)': 'Encabezados del webhook (objeto JSON)',
    'I have securely saved my access code. I understand that if I lose it, ':
        'He guardado de forma segura mi código de acceso. Entiendo que, si lo pierdo, ',
    ' to my account.': ' a mi cuenta.',
    'This permanently deletes your VPN account and access. Type DELETE MY ACCOUNT to continue.':
        'Esta acción elimina permanentemente tu cuenta VPN y el acceso. Escribe ELIMINAR MI CUENTA para continuar.',
    'Applies to TLS and Reality profiles on the next connection.':
        'Se aplica a los perfiles TLS y Reality en la próxima conexión.',
    'Uses the hybrid ML-KEM-768 + X25519 handshake.':
        'Usa el intercambio híbrido ML-KEM-768 + X25519.',
    'ML-KEM-768 + X25519 (Xray hybrid post-quantum handshake)':
        'ML-KEM-768 + X25519 (intercambio poscuántico híbrido de Xray)',
    'These controls are applied only to subscription profiles using XHTTP. Save from the page header; reconnect to apply.':
        'Estos controles solo se aplican a perfiles de suscripción que usan XHTTP. Guarda desde el encabezado de la página y vuelve a conectar para aplicarlos.',
    'Padding, request behavior, reuse and split download':
        'Relleno, solicitudes, reutilización y descarga dividida',
    'XMUX connection limits': 'Límites de conexión XMUX',
    'TLS-only controls apply to TLS profiles. SNI and the ClientHello fingerprint also apply to Reality. Changes take effect after reconnecting.':
        'Los controles exclusivos de TLS se aplican a perfiles TLS. SNI y la huella ClientHello también se aplican a Reality. Los cambios se aplican al reconectar.',
    'TCP connection': 'Conexión TCP',
    'These Xray socket settings apply to the next connection.':
        'Estos ajustes de socket de Xray se aplican en la próxima conexión.',
    'Xray level 0 timeouts and request buffer. Values apply after reconnecting; leave buffer empty to use the platform default.':
        'Tiempos de espera de nivel 0 y búfer de solicitudes de Xray. Se aplican al reconectar; deja el búfer vacío para usar el valor predeterminado de la plataforma.',
    'Counts named users active within the last 20 seconds.':
        'Cuenta los usuarios identificados que estuvieron activos en los últimos 20 segundos.',
    'Choose Xray DNS transports, address families and fallback behavior. Changes apply after reconnecting.':
        'Elige transportes DNS de Xray, familias de direcciones y comportamiento alternativo. Los cambios se aplican al reconectar.',
    'FakeDNS is active in Xray. After disconnecting, cached synthetic addresses can briefly remain on the device.':
        'FakeDNS está activo en Xray. Tras desconectarte, las direcciones sintéticas almacenadas pueden permanecer brevemente en el dispositivo.',
    'Add one domain per line. Traffic to these sites uses your regular connection after the next VPN reconnect.':
        'Añade un dominio por línea. Tras reconectar la VPN, el tráfico de estos sitios usará tu conexión normal.',
    'Match domains, addresses, ports, processes, or HTTP traffic and send it through proxy, direct, or block.':
        'Filtra dominios, direcciones, puertos, procesos o tráfico HTTP y envíalos por el proxy, directamente o bloquéalos.',
    'Detect destination names in tunneled traffic for Xray routing. Reconnect to apply.':
        'Detecta nombres de destino en el tráfico tunelizado para el enrutamiento de Xray. Reconecta para aplicar.',
    'Inspect traffic for route matching.':
        'Inspecciona el tráfico para aplicar reglas de enrutamiento.',
    'Use the detected domain for rules; keep the original IP as the connection target.':
        'Usa el dominio detectado en las reglas y conserva la IP original como destino de conexión.',
    'FakeDNS requires sniffing; Xray keeps FakeDNS recovery enabled while it is active.':
        'FakeDNS requiere inspección; Xray mantiene activa la recuperación de FakeDNS mientras esta función está habilitada.',
    'Installed Xray core': 'Núcleo Xray instalado',
    'Xray itself blocks startup outside these optional version bounds. Leave both blank to clear the guard; reconnect to apply.':
        'Xray impide el inicio fuera de estos límites de versión opcionales. Deja ambos en blanco para quitar el límite y reconecta para aplicar.',
    'Configure Xray TCP and UDP masks or QUIC tuning for the selected proxy. The core validates mask-specific options when you connect.':
        'Configura las máscaras TCP y UDP de Xray o los ajustes QUIC del proxy seleccionado. El núcleo valida las opciones de máscara al conectar.',
    'Choose which sanitized Xray diagnostics are captured. Raw connection details and file logs stay disabled.':
        'Elige qué diagnósticos anonimizados de Xray guardar. Los detalles sin filtrar de conexión y los registros en archivo permanecen desactivados.',
    'Sniffed protocol': 'Protocolo detectado',
    'Webhook on match (optional)': 'Webhook al coincidir (opcional)',
    'Selected apps use your regular connection. All other apps stay protected by Oculve. Changes apply after the next connection.':
        'Las aplicaciones seleccionadas usan tu conexión normal. Oculve protege todas las demás. Los cambios se aplican en la próxima conexión.',
    'No passkeys': 'No hay claves de acceso',
    'Paused': 'En pausa',
    'Protocols': 'Protocolos',
    'VPN proxy': 'Proxy VPN',
    'Block': 'Bloquear',
    'Network': 'Red',
    'gRPC header disguise': 'Ocultar el encabezado gRPC',
    'Suppress header': 'Omitir encabezado',
    'Send header': 'Enviar encabezado',
    'Pause passkeys': 'Pausar claves de acceso',
    'Resume passkeys': 'Reanudar claves de acceso',
    'Pause passkeys?': '¿Pausar las claves de acceso?',
    'Resume passkeys?': '¿Reanudar las claves de acceso?',
    'Pause': 'Pausar',
    'Resume': 'Reanudar',
    'Remove passkey?': '¿Quitar la clave de acceso?',
    'Remove TOTP?': '¿Quitar TOTP?',
    'Reset all devices?': '¿Restablecer todos los dispositivos?',
    'This security key will no longer work for sign in.':
        'Esta clave de seguridad ya no se podrá usar para iniciar sesión.',
    'Open Oculve': 'Abrir Oculve',
    'Network & DNS': 'Red y DNS',
    'DNS provider': 'Proveedor DNS',
    'SORT': 'ORDENAR',
    'DNS & IP': 'DNS e IP',
    'Choose a private DNS service and IP family.':
        'Elige un DNS privado y la familia de direcciones IP.',
    'Automatic': 'Automático',
    'IPv4 + IPv6': 'IPv4 + IPv6',
    'Connection privacy': 'Privacidad de conexión',
    'Use the server profile defaults.': 'Usar los ajustes del servidor.',
    'The selected server does not use TLS or Reality.':
        'El servidor seleccionado no usa TLS ni Reality.',
    'TLS fingerprint': 'Huella TLS',
    'Server default': 'Predeterminada del servidor',
    'The fingerprint should match your server and takes effect after reconnecting.':
        'La huella debe coincidir con tu servidor y se aplica al volver a conectarte.',
    'Bypass domains': 'Dominios excluidos de la VPN',
    'Enter one domain per line. These sites bypass the VPN.':
        'Escribe un dominio por línea. Estos sitios omiten la VPN.',
    'Android app routing': 'Enrutamiento de aplicaciones Android',
    'Advanced': 'Avanzado',
    'Diagnostics and optional connection behavior.':
        'Diagnóstico y opciones adicionales de conexión.',
    'Diagnostic detail': 'Detalle de diagnóstico',
    'Only errors, warnings and basic connection information are recorded.':
        'Solo se registran errores, advertencias e información básica de conexión.',
    'TLS hello fragmentation': 'Fragmentación del saludo TLS',
    'Can help on restricted networks, but may reduce speed. Use only when needed.':
        'Puede ayudar en redes restringidas, pero reducir la velocidad. Úsala solo si hace falta.',
    'Fragmentation is available for VLESS Reality over TCP.':
        'La fragmentación está disponible para VLESS Reality sobre TCP.',
    'Choose sites that should use your regular connection.':
        'Elige los sitios que usarán tu conexión normal.',
    'Choose option': 'Elegir opción',
    'Error': 'Error',
    'Warning': 'Advertencia',
    'Info': 'Información',
    'Chrome': 'Chrome',
    'Firefox': 'Firefox',
    'Safari': 'Safari',
    'Choose a DNS provider. The provider can see the domain names you look up.':
        'Elige un proveedor DNS. Este proveedor podrá ver los nombres de dominio que consultas.',
    'Changes apply after you reconnect.':
        'Los cambios se aplican al volver a conectarte.',
    'Traffic routing': 'Enrutamiento del tráfico',
    'Domains outside the VPN': 'Dominios fuera de la VPN',
    'Sites listed here use your regular connection. Add one domain per line.':
        'Los sitios de esta lista usarán tu conexión normal. Añade un dominio por línea.',
    'example.com': 'ejemplo.com',
    'Save domains': 'Guardar dominios',
    'Could not save settings.': 'No se pudieron guardar los ajustes.',
    'Settings saved.': 'Ajustes guardados.',
    'Android apps outside the VPN': 'Aplicaciones Android fuera de la VPN',
    'Desktop': 'Escritorio',
    'Tray & menu bar': 'Bandeja del sistema y barra de menús',
    'Left-click action': 'Acción del clic izquierdo',
    'Right-click action': 'Acción del clic derecho',
    'Open or hide the app': 'Mostrar u ocultar la aplicación',
    'Connect or disconnect VPN': 'Conectar o desconectar la VPN',
    'Choose a location': 'Elegir una ubicación',
    'Show the tray menu': 'Mostrar el menú de la bandeja',
    'On Linux, tray click behavior is controlled by the desktop environment. Use the Oculve tray menu for connection and location actions.':
        'En Linux, el entorno de escritorio controla los clics de la bandeja. Usa el menú de Oculve para conectarte y elegir ubicación.',
    'Tap to view options': 'Toca para ver las opciones',
    'Retry': 'Reintentar',
    'Sign in again': 'Volver a iniciar sesión',
    'Devices reset. Your subscription link has changed.':
        'Dispositivos restablecidos. Tu enlace de suscripción ha cambiado.',
    'Recovery codes copied.': 'Códigos de recuperación copiados.',
    'Direct local API': 'API local directa',
    'Could not load installed apps.':
        'No se pudieron cargar las aplicaciones instaladas.',
    'Permanently delete?': '¿Eliminar permanentemente?',
    'Your account and VPN access cannot be restored.':
        'No se podrán restaurar tu cuenta ni el acceso VPN.',
    'Delete permanently': 'Eliminar permanentemente',
    'Quit Oculve': 'Salir de Oculve',
    'Merge advanced Xray options into every imported server. Object fields merge recursively; arrays replace the matching field. Reconnect to apply. Invalid core options prevent connection.':
        'Combina las opciones avanzadas de Xray con cada servidor importado. Los campos de objeto se combinan de forma recursiva; las matrices sustituyen el campo correspondiente. Reconecta para aplicar los cambios. Las opciones no válidas del núcleo impiden la conexión.',
    'Not set up': 'Sin configurar',
    'Pause 2FA?': '¿Pausar la autenticación en dos pasos?',
    'Resume 2FA?': '¿Reanudar la autenticación en dos pasos?',
    'This changes the authenticator requirement for future sign-ins.':
        'Esto cambia si se exigirá autenticación en futuros inicios de sesión.',
    'Confirm': 'Confirmar',
    'Remove authenticator?': '¿Quitar el autenticador?',
    'This removes your authenticator secret and recovery codes.':
        'Esto elimina el secreto del autenticador y los códigos de recuperación.',
    'Remove': 'Quitar',
    'Authenticator removed.': 'Autenticador eliminado.',
    '2FA updated.': 'Autenticación en dos pasos actualizada.',
    'This affects passkey sign-in on your account.':
        'Esto afecta el inicio de sesión con claves de acceso de tu cuenta.',
    'Passkeys can be toggled back on at any time.':
        'Puedes volver a activar las claves de acceso cuando quieras.',
    'Passkeys updated.': 'Claves de acceso actualizadas.',
    'Passkey': 'Clave de acceso',
    'This passkey will no longer sign in to your account.':
        'Esta clave de acceso ya no permitirá iniciar sesión en tu cuenta.',
    'Passkey removed.': 'Clave de acceso eliminada.',
    'This device': 'Este dispositivo',
    'Security key': 'Clave de seguridad',
    'Synced': 'Sincronizada',
    'Device only': 'Solo en el dispositivo',
    'Added': 'Añadida',
    'Last used': 'Último uso',
    'Registered device': 'Dispositivo registrado',
    'Unknown OS': 'Sistema operativo desconocido',
    'Last active': 'Última actividad',
    'Authenticator sign-in will be disabled.':
        'Se desactivará el inicio de sesión con autenticador.',
    'Connection setup': 'Configuración de conexión',
    'Performance': 'Rendimiento',
    'Apps outside the VPN': 'Aplicaciones fuera de la VPN',
    'Enter the code from your authenticator.':
        'Introduce el código de tu aplicación de autenticación.',
    'FinalMask': 'FinalMask',
    'IP / CIDR': 'IP / CIDR',
    'Local inbound IP / CIDR': 'IP / CIDR de entrada local',
    'Measuring VPN server ping': 'Midiendo el ping del servidor VPN',
    'One endpoint or Xray DNS server JSON object per line. Supports UDP, TCP, DoH, DoQ and localhost. +local bypasses proxy routing; h2c is unencrypted.':
        'Escribe un servidor DNS o un objeto JSON de Xray por línea. Admite UDP, TCP, DoH, DoQ y localhost. +local evita el proxy; h2c no está cifrado.',
    'One mapping per line (for example domain:example.com=93.184.216.34). Separate multiple targets with |.':
        'Una asignación por línea (por ejemplo, domain:example.com=93.184.216.34). Separa los destinos con |.',
    'Paste a static ECHConfig or use udp://, https:// or h2c://.':
        'Pega un ECHConfig estático o usa udp://, https:// o h2c://.',
    'Process name / path': 'Nombre o ruta del proceso',
    'Route-only': 'Solo para enrutamiento',
    'SNI / server name': 'SNI / nombre del servidor',
    'Setup key copied.': 'Clave de configuración copiada.',
    'Source IP / CIDR': 'IP / CIDR de origen',
    'Use Xray FinalMask JSON: tcp, udp, and/or quicParams. Leave {} to remove app-level overrides.':
        'Usa el JSON FinalMask de Xray: tcp, udp o quicParams. Deja {} para quitar las modificaciones de la aplicación.',
    'User / email': 'Usuario / correo electrónico',
    'milliseconds': 'milisegundos',
  };

  static const _tr = <String, String>{
    'Tray & Window': 'Tepsi ve Pencere',
    'CLICK ACTIONS': 'TIKLAMA İŞLEMLERİ',
    'Left click': 'Sol tıklama',
    'Right click': 'Sağ tıklama',
    'Open or hide app': 'Uygulamayı aç veya gizle',
    'Show tray menu': 'Tepsi menüsünü göster',
    'On Linux, click behavior depends on the desktop environment.':
        'Linux üzerinde tıklama davranışı masaüstü ortamına bağlıdır.',
    'WINDOW BEHAVIOR': 'PENCERE DAVRANIŞI',
    'Hide when focus is lost': 'Odak kaybolunca gizle',
    'Keep the app running in the tray.':
        'Uygulama tepside çalışmaya devam eder.',
    'When closing the window': 'Pencere kapatıldığında',
    'Hide to tray': 'Tepsiye gizle',
    'TRAY APPEARANCE': 'TEPSİ GÖRÜNÜMÜ',
    'Status indicator': 'Durum göstergesi',
    'Connection state': 'Bağlantı durumu',
    'App icon': 'Uygulama simgesi',
    'MENU PREVIEW': 'MENÜ ÖNİZLEMESİ',
    'Preview of the tray menu.': 'Tepsi menüsünün önizlemesi.',
    'Could not save tray settings. Please try again.':
        'Tepsi ayarları kaydedilemedi. Yeniden deneyin.',
    'Connection error': 'Bağlantı hatası',
    'Loading statistics': 'İstatistikler yükleniyor',
    'Loading': 'Yükleniyor',
    'Preparing your account and servers…':
        'Hesabın ve sunucuların hazırlanıyor…',
    'Saving…': 'Kaydediliyor…',

    'macOS tunnel uses IPv4.': 'macOS tüneli IPv4 kullanır.',
    'Retry interrupted sessions. Manual Disconnect cancels retries.':
        'Kesilen oturumları yeniden dener. Elle bağlantıyı kesmek denemeleri durdurur.',
    'Could not start LAN sharing. Check your address, port and password.':
        'Paylaşım başlatılamadı. Adres, bağlantı noktası ve parolayı kontrol edin.',

    'Provider': 'Sağlayıcı',
    'Custom': 'Özel',
    'Custom DNS over HTTPS URL': 'Özel HTTPS DNS adresi',
    'IP lookup': 'IP sorgulama',
    'Network-aware': 'Ağa göre',
    'Uses the address types available on your network.':
        'Ağınızda kullanılabilen adres türlerini sorgular.',
    'Queries both IPv4 and IPv6 records.': 'IPv4 ve IPv6 kayıtlarını sorgular.',
    'Queries IPv4 records only.': 'Yalnızca IPv4 kayıtlarını sorgular.',
    'Queries IPv6 records only.': 'Yalnızca IPv6 kayıtlarını sorgular.',
    'VPN BYPASS': 'VPN DIŞINDA',
    'SPLIT TUNNELING': 'BÖLÜNMÜŞ TÜNELLEME',
    'Domain routing': 'Alan adı yönlendirme',
    'Route these domains': 'Bu alan adlarını yönlendir',
    'Route domains': 'Alan adlarını yönlendir',
    'Except selected': 'Seçilenler hariç',
    'Only selected': 'Yalnızca seçilenler',
    'Except selected domains': 'Seçilenler hariç',
    'Only selected domains': 'Yalnızca seçilenler',
    'Choose domains for VPN routing.': 'VPN yönlendirmesi için alan adı seçin.',
    'Websites outside VPN': 'VPN dışında kalan siteler',
    'No websites added': 'Henüz site eklenmedi',
    'websites': 'site',
    'domains': 'alan adı',
    'Domain': 'Alan adı',
    'Add website': 'Site ekle',
    'These websites bypass the VPN. Changes apply after reconnecting.':
        'Bu siteler VPN dışında kalır. Değişiklikler yeniden bağlanınca uygulanır.',
    'CONNECTION': 'BAĞLANTI',
    'Automatic reconnect': 'Otomatik yeniden bağlanma',
    'Retry an interrupted session. Manual Disconnect cancels retries. System tunnel recovery stays enabled.':
        'Kesilen bağlantıyı yeniden dener. Elle bağlantıyı kesmek denemeleri durdurur. Sistem tünel kurtarması açık kalır.',
    'Kill switch': 'Bağlantı koruması',
    'System-managed': 'Sistem yönetir',
    'Platform dependent': 'Platforma bağlı',
    'System protection is armed.': 'Sistem koruması etkin.',
    'System protection activates when you connect.':
        'Sistem koruması bağlandığınızda etkinleşir.',
    'Traffic protection stays enabled during tunnel recovery. Disconnecting manually ends the VPN session and its protection. Certain essential system traffic is exempted by macOS.':
        'Tünel yeniden kurulurken koruma devam eder. Elle bağlantıyı kesmek VPN oturumunu ve korumasını sonlandırır. macOS bazı temel sistem trafiğini hariç tutar.',
    'Traffic protection depends on your platform. System-level verification is required before this feature can be enabled.':
        'Koruma platforma bağlıdır. Etkinleştirilmeden önce sistem düzeyinde doğrulanmalıdır.',
    'Windows installs system traffic protection before the VPN starts. It stays active during tunnel recovery and ends when you disconnect.':
        'Windows, VPN başlamadan önce sistem trafik korumasını kurar. Tünel kurtarılırken koruma sürer ve bağlantıyı kestiğinizde kaldırılır.',
    'Linux installs a firewall guard before VPN routing starts. It stays active during recovery and is removed when you stop the VPN.':
        'Linux, VPN yönlendirmesi başlamadan önce güvenlik duvarı korumasını kurar. Kurtarma sırasında sürer ve VPN’i durdurduğunuzda kaldırılır.',
    'TLS fragmentation': 'TLS parçalama',
    'For compatible connections': 'Uyumlu bağlantılar için',
    'Available for VLESS Reality over TCP.':
        'TCP üzerinden VLESS Reality bağlantılarında kullanılabilir.',
    'Fragmentation settings': 'Parçalama ayarları',
    'Only the TLS hello is fragmented. Smaller fragments or longer delays may reduce speed.':
        'Yalnızca TLS başlangıç mesajı parçalanır. Küçük parçalar veya uzun gecikmeler hızı azaltabilir.',
    'Only the TLS hello is fragmented. Settings save automatically; reconnect to apply. Smaller fragments or longer delays may reduce speed.':
        'Yalnızca TLS başlangıç mesajı parçalanır. Ayarlar otomatik kaydedilir ve yeniden bağlanınca uygulanır. Küçük parçalar veya uzun gecikmeler hızı azaltabilir.',
    'Fragment length (bytes)': 'Parça boyutu (bayt)',
    'Delay (milliseconds)': 'Gecikme (milisaniye)',
    'Maximum splits': 'En fazla parça',
    '1–16384, for example 100-200': '1–16384, örneğin 100-200',
    '0–1000, for example 10-20': '0–1000, örneğin 10-20',
    '1–32, for example 3-6': '1–32, örneğin 3-6',
    'LOCAL NETWORK': 'YEREL AĞ',
    'LAN proxy sharing': 'Yerel ağda VPN paylaşımı',
    'Share VPN connection': 'VPN bağlantısını paylaş',
    'HTTP and SOCKS5 proxy with password authentication.':
        'Parola korumalı HTTP ve SOCKS5 proxy.',
    'Local address': 'Yerel adres',
    'Proxy port': 'Proxy bağlantı noktası',
    'Username': 'Kullanıcı adı',
    'New password': 'Yeni parola',
    'Sharing is active.': 'Paylaşım etkin.',
    'Sharing starts after the VPN connects. Reconnect after changes.':
        'Paylaşım VPN bağlanınca başlar. Değişikliklerden sonra yeniden bağlanın.',
    'Sharing is off.': 'Paylaşım kapalı.',
    'Ready after reconnect': 'Yeniden bağlanınca hazır',
    'LAN proxy sharing is currently available on macOS.':
        'Yerel ağda proxy paylaşımı şu anda macOS üzerinde kullanılabilir.',
    'Set this address and port as the proxy on your other device. Both devices must be on the same local network. TCP traffic only; this does not create a Wi-Fi hotspot.':
        'Diğer cihazınızda bu adresi ve bağlantı noktasını proxy olarak ayarlayın. İki cihaz aynı yerel ağda olmalıdır. Yalnızca TCP trafiği desteklenir; Wi-Fi erişim noktası oluşturmaz.',
    'When your computer starts': 'Bilgisayar açıldığında',
    'Oculve will not start automatically.': 'Oculve otomatik başlamaz.',
    'Open Oculve without connecting to the VPN.':
        'Oculve açılır, VPN bağlantısı kurulmaz.',
    'Open Oculve and connect to the VPN automatically.':
        'Oculve açılır ve VPN’e otomatik bağlanır.',
    'Could not update startup settings.': 'Başlangıç ayarı değiştirilemedi.',
    'Could not load startup settings. Tap to retry.':
        'Başlangıç ayarı yüklenemedi. Tekrar dene.',
    'Could not connect at startup.': 'Başlangıçta VPN bağlantısı kurulamadı.',
    'Off': 'Kapalı',
    'Open': 'Aç',
    'Connect': 'Bağlan',
    'On': 'Açık',
    'ACCOUNT USAGE': 'HESAP KULLANIMI',
    'DATA USED': 'KULLANILAN VERİ',
    'Data used in the current account period.':
        'Hesabın geçerli döneminde kullanılan veri.',
    'Active days (all time)': 'Aktif gün (tüm zamanlar)',
    'Auto': 'Otomatik',
    'CURRENT PERIOD': 'MEVCUT DÖNEM',
    'SESSION COUNTERS': 'OTURUM SAYAÇLARI',
    'SERVER USAGE': 'SUNUCU KULLANIMI',
    'active days, all time': 'etkin gün, toplam',
    'CURRENT SESSION': 'MEVCUT OTURUM',
    '30 days': '30 gün',
    '12 months': '12 ay',
    '30d': '30g',
    '12m': '12a',
    'Daily data usage': 'Günlük veri kullanımı',
    'Monthly data usage': 'Aylık veri kullanımı',
    'Server usage': 'Sunucu kullanımı',
    'View all servers': 'Tüm sunucuları göster',
    'Show fewer servers': 'Daha az sunucu göster',
    'No server usage yet.': 'Henüz sunucu kullanımı yok.',
    'No usage recorded for this period.': 'Bu dönemde kayıtlı kullanım yok.',
    'Startup': 'Başlangıç',
    'STARTUP': 'BAŞLANGIÇ',
    'Launch at login': 'Oturum açılınca başlat',
    'Open Oculve in the menu bar when you sign in. This does not connect the VPN.':
        'Oturum açtığınızda Oculve menü çubuğunda açılır. VPN otomatik bağlanmaz.',
    'Approve Oculve in System Settings → General → Login Items.':
        'Sistem Ayarları → Genel → Giriş Öğeleri bölümünde Oculve için izin verin.',
    'Refresh status': 'Durumu yenile',
    'Login startup is currently available on macOS.':
        'Oturum açıldığında başlatma şu anda macOS üzerinde kullanılabilir.',
    'Could not update login startup. Check System Settings.':
        'Başlangıç ayarı güncellenemedi. Sistem Ayarlarını kontrol edin.',
    'DIAGNOSTICS': 'TANILAMA',
    'Errors': 'Hatalar',
    'Warnings': 'Uyarılar',
    'Detailed': 'Ayrıntılı',
    'Troubleshooting report': 'Sorun giderme raporu',
    'Export without account codes or credentials.':
        'Hesap kodu ve parolalar dahil edilmeden dışa aktarılır.',
    'Export troubleshooting report': 'Sorun giderme raporunu dışa aktar',
    'Changes apply after reconnecting.':
        'Değişiklikler yeniden bağlanınca uygulanır.',
    'Restore defaults': 'Varsayılanlara dön',
    'Restore connection defaults?': 'Bağlantı ayarları sıfırlansın mı?',
    'This resets DNS, bypass websites, fragmentation, reconnect preferences and LAN sharing. Login startup stays unchanged.':
        'DNS, VPN dışındaki siteler, parçalama, yeniden bağlanma ve yerel ağ paylaşımı sıfırlanır. Başlangıç ayarı korunur.',
    'Save DNS': 'DNS kaydet',
    'DNS saved. Reconnect to apply.':
        'DNS kaydedildi. Uygulamak için yeniden bağlanın.',
    'Could not load LAN sharing settings.':
        'Yerel ağ paylaşımı ayarları yüklenemedi.',
    'Could not save connection settings. Check your input and try again.':
        'Bağlantı ayarları kaydedilemedi. Girdiğiniz değerleri kontrol edin.',
    'Could not save the troubleshooting report.':
        'Sorun giderme raporu kaydedilemedi.',
    'Check your LAN address, port, username and password. Use at least 12 characters for the password.':
        'Yerel adres, bağlantı noktası, kullanıcı adı ve parolayı kontrol edin. Parola en az 12 karakter olmalıdır.',
    'LAN sharing saved. Reconnect to apply these settings.':
        'Paylaşım kaydedildi. Uygulamak için yeniden bağlanın.',
    'LAN sharing stopped.': 'Yerel ağ paylaşımı durduruldu.',
    'LAN sharing stopped. Check your local network.':
        'Paylaşım durduruldu. Yerel ağınızı kontrol edin.',
    'Proxy address copied.': 'Proxy adresi kopyalandı.',
    'Enter valid numeric ranges for fragment length, delay and splits.':
        'Parça boyutu, gecikme ve parça sayısı için geçerli aralıklar girin.',
    'Enter a valid HTTPS DNS URL without credentials or a fragment.':
        'Kullanıcı bilgisi veya # içermeyen geçerli bir HTTPS DNS adresi girin.',
    'macOS currently carries IPv4 only. IPv6 lookups are unavailable in this tunnel.':
        'macOS tüneli şu anda yalnızca IPv4 taşır. Bu tünelde IPv6 sorguları kullanılamaz.',

    'Created on': 'Oluşturulma tarihi',
    'Two-factor authentication on': 'İki aşamalı doğrulama açık',
    'Two-factor authentication off': 'İki aşamalı doğrulama kapalı',

    'SUBSCRIPTION': 'ABONELİK',
    'Expires on': 'Bitiş tarihi',
    'Data usage': 'Veri kullanımı',
    'Manage subscription': 'Aboneliği yönet',
    'ACCOUNT SETTINGS': 'HESAP AYARLARI',
    'Show access code': 'Erişim kodunu göster',
    'Hide access code': 'Erişim kodunu gizle',
    'Copy access code': 'Erişim kodunu kopyala',

    'Statistics unavailable': 'İstatistikler kullanılamıyor',
    'Could not reach the service securely. Check your connection.':
        'Hizmete güvenli bağlantı kurulamadı. İnternet bağlantını kontrol et.',
    'Could not generate an access code.': 'Erişim kodu oluşturulamadı.',
    'Your access code or session is invalid. Please sign in again.':
        'Erişim kodun veya oturumun geçersiz. Lütfen tekrar giriş yap.',
    'Access denied. Check your account status.':
        'Erişim reddedildi. Hesap durumunu kontrol et.',
    'Subscription access was rejected. Your device limit may be reached.':
        'Abonelik erişimi reddedildi. Cihaz sınırına ulaşmış olabilirsin.',
    'Could not read your device identity. Please restart the app and try again.':
        'Cihaz kimliği okunamadı. Uygulamayı yeniden başlatıp tekrar dene.',
    'The service rejected this request. Check your details and try again.':
        'İstek reddedildi. Girdiğin bilgileri kontrol edip tekrar dene.',
    'Enter valid website domains, such as example.com.':
        'example.com gibi geçerli web sitesi alan adları gir.',
    'Choose a supported DNS provider.': 'Desteklenen bir DNS sağlayıcısı seç.',
    'Add at most 32 bypass domains.':
        'VPN dışında kalacak en fazla 32 alan adı ekle.',
    'Choose at most 100 apps to bypass.':
        'VPN dışında kalacak en fazla 100 uygulama seç.',
    'Something went wrong. Please try again.':
        'Bir şeyler ters gitti. Lütfen tekrar dene.',
    'Too many attempts. Please wait and try again.':
        'Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.',
    'The service is temporarily unavailable. Please try again.':
        'Hizmet şu anda kullanılamıyor. Lütfen biraz sonra tekrar dene.',
    'Could not connect to the service. Check your internet connection and try again.':
        'Hizmete bağlanılamadı. İnternet bağlantını kontrol edip tekrar dene.',
    'The service returned an invalid response. Please try again.':
        'Hizmet geçersiz bir yanıt verdi. Lütfen tekrar dene.',
    'Unable to load your account': 'Hesabın yüklenemedi',
    'Could not load app routing settings.':
        'Uygulama yönlendirme ayarları yüklenemedi.',
    'Statistics are currently unavailable. Try again shortly.':
        'İstatistikler şu anda kullanılamıyor. Biraz sonra tekrar dene.',
    'Your account was created, but server setup is still finishing. Sign in again shortly.':
        'Hesabın oluşturuldu ancak sunucu kurulumu henüz tamamlanmadı. Biraz sonra tekrar giriş yap.',
    'Could not create your sign-in key. Please try again.':
        'Giriş anahtarın oluşturulamadı. Lütfen tekrar dene.',
    'Could not load connection settings.': 'Bağlantı ayarları yüklenemedi.',
    'The request could not be completed. Please try again.':
        'İstek tamamlanamadı. Lütfen tekrar dene.',
    'Could not establish the VPN. Please try again.':
        'VPN bağlantısı kurulamadı. Lütfen tekrar dene.',
    'SEE THE UNSEEN': 'Görünmeyeni gör',
    'Your private connection starts here.': 'Özel bağlantın burada başlıyor.',
    'Set up your access key, save it somewhere safe, then choose a location for your first private connection.':
        'Erişim anahtarını oluştur, güvenli bir yere kaydet ve ilk özel bağlantın için bir konum seç.',
    'Already have an account?': 'Zaten hesabın var mı?',
    'Create your Oculve account in three quick steps.':
        'Oculve hesabını üç kısa adımda oluştur.',
    'No email or password required.': 'E-posta veya şifre gerekmez.',
    'Your sign-in key': 'Giriş anahtarın',
    'Generating your access code': 'Erişim kodun oluşturuluyor',
    'This is your access code. Tap it to copy; continuing saves it to your device.':
        'Bu senin erişim kodun. Kopyalamak için dokun; devam ettiğinde cihazına kaydedilecek.',
    'Ready to create your account?': 'Hesabını oluşturmaya hazır mısın?',
    'Your access code is saved. Keep the file private; you’ll need it each time you sign in.':
        'Erişim kodun kaydedildi. Dosyayı gizli tut; her girişinde bu kodu kullanacaksın.',
    'Access code saved to this device': 'Erişim kodu bu cihaza kaydedildi',
    'Choose a place to save your code before continuing.':
        'Devam etmeden önce kodunu kaydedeceğin yeri seç.',
    'Could not save your code. Choose a location and try again.':
        'Kodun kaydedilemedi. Bir konum seçip tekrar dene.',
    'Saving code…': 'Kod kaydediliyor…',
    'oculve-access-code.txt': 'oculve-access-code.txt',
    'Use this code every time you sign in to Oculve.':
        'Oculve’e her girişinde bu kodu kullan.',
    'YOUR ACCESS CODE': 'ERİŞİM KODUN',
    'Copied': 'Kopyalandı',
    'Saved to file': 'Dosyaya kaydedildi',
    'Save code': 'Kodu kaydet',
    'Oculve can’t recover a lost code.': 'Oculve kaybolan kodu kurtaramaz.',
    'Keep your code safe': 'Kodunu güvenli yerde sakla',
    'Your code is the only way to sign in. Oculve can’t restore it if it’s lost.':
        'Giriş yapmanın tek yolu bu kod. Kaybolursa Oculve geri yükleyemez.',
    'I’ve saved my access code somewhere safe.':
        'Erişim kodumu güvenli bir yere kaydettim.',
    'By continuing, you agree to the ': 'Devam ederek şunları kabul edersin: ',
    'Terms of Service': 'Kullanım Koşulları',
    'Get my access code': 'Erişim kodumu al',
    'Continue setup': 'Kuruluma devam et',
    'Try again to create your code.': 'Kodun oluşturulamadı. Tekrar dene.',
    'One access code keeps your account yours.':
        'Tek bir erişim kodu hesabının sana ait kalmasını sağlar.',
    'No email or password needed.': 'E-posta veya şifre gerekmez.',
    'One last step': 'Son bir adım',
    'Keep your access code somewhere safe. You will use it whenever you sign in.':
        'Erişim kodunu güvenli bir yerde sakla. Her giriş yaptığında bu kodu kullanacaksın.',
    'Your code is the only way to access your account.':
        'Hesabına erişmenin tek yolu bu koddur.',
    'Create my account': 'Hesabımı oluştur',
    'Saved': 'Kaydedildi',
    'Welcome to Oculve': 'Oculve’e hoş geldin',
    'Start your secure connection in a few simple steps.':
        'Güvenli bağlantına birkaç adımda başla.',
    'Already have an account? Sign in': 'Zaten hesabım var · Giriş yap',
    'No email. No password. Just your access code.':
        'E-posta yok. Şifre yok. Yalnızca giriş kodun.',
    'This code is your sign-in key': 'Bu kod senin giriş anahtarın',
    'Use this code to sign in to Oculve. No email or password needed.':
        'Oculve’e giriş yapmak için bu kodu kullanacaksın. E-posta veya şifre gerekmiyor.',
    'Copy code': 'Kodu kopyala',
    'Save to file': 'Dosyaya kaydet',
    'I have saved my access code somewhere safe.':
        'Giriş kodumu güvenli bir yere kaydettim.',
    'If you lose this code, you cannot recover your account.':
        'Bu kodu kaybedersen hesabını kurtaramazsın.',
    '2FA active': '2FA açık',
    '2FA off': '2FA kapalı',
    '2FA / TOTP': '2FA / TOTP',
    'ACCESS CODE': 'ERİŞİM KODU',
    'Account': 'Hesap',
    'Account usage': 'Hesap kullanımı',
    'Active': 'Aktif',
    'Active days': 'Aktif gün',
    'All time': 'tüm zamanlar',
    'Relative to most-used server': 'En çok kullanılan sunucuya göre',
    'Session totals are unavailable until connection data is received.':
        'Bağlantı verisi alınana kadar oturum toplamları kullanılamaz.',
    'Session data not received yet.': 'Oturum verisi henüz alınmadı.',
    'Add rule': 'Kural ekle',
    'Advanced core options': 'Gelişmiş çekirdek seçenekleri',
    'Advanced matchers': 'Gelişmiş eşleştirme',
    'Advanced routing rules': 'Gelişmiş yönlendirme kuralları',
    'Advanced TLS': 'Gelişmiş TLS',
    'Advanced XHTTP and XMUX': 'Gelişmiş XHTTP ve XMUX',
    'Alphabetical': 'Alfabetik',
    'Allow invalid certificates': 'Geçersiz sertifikalara izin ver',
    'Appearance': 'Görünüm',
    'Apps outside the VPN': 'VPN dışındaki uygulamalar',
    'Automatic selection': 'Otomatik seçim',
    'Back': 'Geri',
    'Back to sign in': 'Girişe dön',
    'Balance': 'Bakiye',
    'Best ping': 'En düşük ping',
    'By proceeding, you agree to our ': 'Devam ederek şunları kabul edersin: ',
    'Cancel': 'İptal',
    'Sign in with passkey': 'Geçiş anahtarıyla giriş yap',
    'Verifying passkey…': 'Geçiş anahtarı doğrulanıyor…',
    'Complete verification using your device.':
        'Cihazınla doğrulamayı tamamla.',
    'This device cannot use your passkey. Set up an authenticator code in your web account to sign in here.':
        'Bu cihaz geçiş anahtarını kullanamıyor. Burada giriş yapmak için web hesabından doğrulayıcı kodu kur.',
    'Passkey is unavailable on this device. Use your authenticator code.':
        'Bu cihazda geçiş anahtarı kullanılamıyor. Doğrulayıcı kodunu kullan.',
    'No matching passkey is available on this device. Use your authenticator code.':
        'Bu cihazda eşleşen geçiş anahtarı bulunamadı. Doğrulayıcı kodunu kullan.',
    'Passkey is not configured for this app yet. Use your authenticator code.':
        'Bu uygulama için geçiş anahtarı henüz yapılandırılmadı. Doğrulayıcı kodunu kullan.',
    'Passkey verification failed. Try again or use your authenticator code.':
        'Geçiş anahtarı doğrulanamadı. Tekrar dene veya doğrulayıcı kodunu kullan.',
    'Use your passkey to continue securely.':
        'Güvenli şekilde devam etmek için geçiş anahtarını kullan.',
    'Certificate SHA-256 pin(s)': 'Sertifika SHA-256 sabitleme değerleri',
    'Certificate verification name': 'Sertifika doğrulama adı',
    'Change password': 'Parolayı değiştir',
    'Choose Android apps that use your regular connection.':
        'Normal bağlantını kullanacak Android uygulamalarını seç.',
    'Choose how XHTTP carries upload and download.':
        'XHTTP yükleme ve indirmeyi nasıl taşısın seçin.',
    'Choose location': 'Konum seç',
    'Client Logs': 'İstemci kayıtları',
    'ClientHello fingerprint': 'ClientHello parmak izi',
    'Close': 'Kapat',
    'CONNECT': 'BAĞLAN',
    'CONNECTED': 'BAĞLANDI',
    'CONNECTING': 'BAĞLANIYOR',
    'CONNECTING…': 'BAĞLANIYOR…',
    'Refreshing servers…': 'Sunucular yenileniyor…',
    'Could not refresh servers. Showing the last saved locations.':
        'Sunucular yenilenemedi. Son kaydedilen konumlar gösteriliyor.',
    'DISCONNECT': 'BAĞLANTIYI KES',
    'STOPPING': 'DURDURULUYOR',
    'STOPPING…': 'DURDURULUYOR…',
    'PROTECTED': 'KORUMADA',
    'UNPROTECTED': 'KORUMASIZ',
    'Connected. Tap to disconnect.': 'Bağlı. Kesmek için dokunun.',
    'Connected': 'Bağlı',
    'Disconnected': 'Bağlı değil',
    'Connect VPN': 'VPN’e bağlan',
    'Disconnect VPN': 'VPN bağlantısını kes',
    'VPN connection in progress': 'VPN bağlantısı sürüyor',
    'Tap to connect': 'Bağlanmak için dokunun',
    'Tap to retry.': 'Yeniden denemek için dokunun.',
    'Dismiss': 'Kapat',
    'The VPN runtime failed. Check permissions and connection settings.':
        'VPN altyapısı çalışmadı. İzinleri ve bağlantı ayarlarını kontrol edin.',
    'VPN disconnected. Reconnect to protect your traffic.':
        'VPN bağlantısı kesildi. Trafiğinizi korumak için yeniden bağlanın.',
    'Your subscription is not active.': 'Aboneliğiniz etkin değil.',
    'No compatible servers are available.': 'Uygun sunucu bulunamadı.',
    'VPN permission was not granted.': 'VPN izni verilmedi.',
    'Linux VPN support is not installed. Finish the Linux setup steps before connecting.':
        'Linux VPN desteği yüklü değil. Bağlanmadan önce Linux kurulum adımlarını tamamlayın.',
    'Windows needs administrator permission to create the VPN tunnel. Close Oculve and reopen it with Run as administrator.':
        'Windows’ta VPN tüneli için yönetici izni gerekir. Oculve’yi kapatıp “Yönetici olarak çalıştır” seçeneğiyle yeniden aç.',
    'Connection timed out. Please try another location.':
        'Bağlantı zaman aşımına uğradı. Başka bir konum deneyin.',
    'Could not establish the VPN. Check your account, VPN permission and server availability.':
        'VPN bağlantısı kurulamadı. Hesabınızı, VPN iznini ve sunucunun erişilebilirliğini kontrol edin.',
    'The VPN could not be stopped. Check the system VPN settings.':
        'VPN durdurulamadı. Sistem VPN ayarlarını kontrol edin.',
    'Sorted by ping. Tap to sort alphabetically.':
        'Ping değerine göre sıralı. Alfabetik sıralamak için dokunun.',
    'Sorted alphabetically. Tap to sort by ping.':
        'Alfabetik sıralı. Ping değerine göre sıralamak için dokunun.',
    'Connection': 'Bağlantı',
    'Connection Settings': 'Bağlantı Ayarları',
    'Most users can leave these settings as they are.':
        'Çoğu kullanıcı bu ayarları olduğu gibi bırakabilir.',
    'DNS & network': 'DNS ve ağ',
    'Choose how names are looked up and which IP versions to use.':
        'Alan adlarının nasıl çözümleneceğini ve hangi IP sürümlerinin kullanılacağını seç.',
    'Choose which sites or Android apps bypass the VPN.':
        'VPN dışından bağlanacak siteleri veya Android uygulamalarını seç.',
    'Secure connection': 'Güvenli bağlantı',
    'Keep the server defaults unless troubleshooting a connection.':
        'Bağlantı sorunlarını giderirken değiştirmediğin sürece sunucu varsayılanlarını kullan.',
    'Optional connection adjustments. Defaults work for most people.':
        'Bağlantı ayarları isteğe bağlıdır. Varsayılanlar çoğu kişi için uygundur.',
    'Connection fingerprint': 'Bağlantı parmak izi',
    'Connection fragmentation': 'Bağlantı parçalama',
    'Connection optimization': 'Bağlantı iyileştirme',
    'Connection policy': 'Bağlantı ilkesi',
    'Continue': 'Devam et',
    'Core behavior & statistics': 'Çekirdek davranışı ve istatistikler',
    'Core version guard': 'Çekirdek sürüm aralığı',
    'Create account': 'Hesap oluştur',
    'Current cycle began': 'Mevcut dönem başlangıcı',
    'Current period': 'Mevcut dönem',
    'Current VPN session': 'Mevcut VPN oturumu',
    'Custom Xray JSON': 'Özel Xray JSON',
    'DNS & name resolution': 'DNS ve ad çözümleme',
    'DNS resolver': 'DNS çözümleyicisi',
    'DNS servers': 'DNS sunucuları',
    'Delete account': 'Hesabı sil',
    'Delete account?': 'Hesap silinsin mi?',
    'This permanently deletes your Oculve account and VPN access.':
        'Bu işlem Oculve hesabınızı ve VPN erişiminizi kalıcı olarak siler.',
    'This action cannot be undone. Type the phrase below to confirm.':
        'Bu işlem geri alınamaz. Onaylamak için aşağıdaki ifadeyi yazın.',
    'Confirmation phrase': 'Onay ifadesi',
    'Delete my account': 'HESABIMI SİL',
    'Delete rule': 'Kuralı sil',
    'Diagnostics': 'Tanılama',
    'Direct connection': 'Doğrudan bağlantı',
    'DPI Bypass': 'DPI Bypass',
    'Disconnect before changing location.':
        'Konumu değiştirmeden önce bağlantıyı kes.',
    'Devices': 'Cihazlar',
    'Domains': 'Alan adları',
    'Downloaded': 'İndirilen',
    'Downloads': 'İndirmeler',
    'Enable 2FA': '2FA’yı aç',
    'Enable for this location': 'Bu konumda etkinleştir',
    'Enable Mux': 'Mux’ı etkinleştir',
    'Enable sniffing': 'Trafik incelemeyi etkinleştir',
    'English': 'İngilizce',
    'Enter your access code to access your secure network infrastructure.':
        'Güvenli ağınıza erişmek için erişim kodunuzu girin.',
    'Enter your authenticator or recovery code to continue securely.':
        'Güvenle devam etmek için doğrulama veya kurtarma kodunu gir.',
    'Expires': 'Bitiş tarihi',
    'Excluded domains': 'Hariç tutulan alan adları',
    'Excluded IPs': 'Hariç tutulan IP’ler',
    'Fingerprint': 'Parmak izi',
    'Handshake method': 'El sıkışma yöntemi',
    'Help & resources': 'Yardım ve kaynaklar',
    'I will permanently lose access': 'kalıcı olarak erişemeyeceğimi',
    'Language': 'Dil',
    'Last 12 months': 'Son 12 ay',
    'Last 30 days': 'Son 30 gün',
    'Usage history': 'Kullanım geçmişi',
    'Last seen': 'Son görülme',
    'Lifetime tracked': 'Toplam kullanım',
    'Light': 'Açık',
    'Locations': 'Sunucular',
    'Log level': 'Kayıt düzeyi',
    'Log out': 'Çıkış yap',
    'Manage plan': 'Planı yönet',
    'Maximum connections': 'En fazla bağlantı',
    'Maximum concurrent requests': 'En fazla eşzamanlı istek',
    'Maximum HTTP request count': 'En fazla HTTP istek sayısı',
    'Maximum POST body bytes': 'En yüksek POST gövde boyutu (bayt)',
    'Maximum TLS version': 'En yüksek TLS sürümü',
    'Metadata-only': 'Yalnızca üstveri',
    'Minimum POST interval (ms)': 'En düşük POST aralığı (ms)',
    'Minimum TLS version': 'En düşük TLS sürümü',
    'Mode': 'Mod',
    'Mux and XUDP': 'Mux ve XUDP',
    'Network behavior': 'Ağ davranışı',
    'New to Oculve? Create account!': 'Oculve’de yeni misin? Hesap oluştur!',
    'No servers available. Check your subscription.':
        'Kullanılabilir sunucu yok. Aboneliğini kontrol et.',
    'Optimal': 'En uygun',
    'Password': 'Parola',
    'Ping': 'Ping',
    'Passkeys': 'Geçiş anahtarları',
    'Per-user download statistics': 'Kullanıcı indirme istatistikleri',
    'Per-user online statistics': 'Kullanıcı çevrimiçi istatistikleri',
    'Per-user upload statistics': 'Kullanıcı yükleme istatistikleri',
    'Ping unavailable': 'Ping ölçülemedi',
    'Privacy': 'Gizlilik',
    'Protocol & identity': 'Protokol ve kimlik',
    'Refresh statistics': 'İstatistikleri yenile',
    'Registered devices': 'Kayıtlı cihazlar',
    'Remaining': 'Kalan',
    'Route traffic to': 'Trafiği şuraya yönlendir',
    'Route-only': 'Yalnızca yönlendirme için',
    'Routing & privacy': 'Yönlendirme ve gizlilik',
    'Save': 'Kaydet',
    'Save for this location': 'Bu konum için kaydet',
    'Security': 'Güvenlik',
    'Security methods': 'Güvenlik yöntemleri',
    'Server': 'Sunucu',
    'Server authentication parameter': 'Sunucu kimlik doğrulama parametresi',
    'Server address discovery': 'Sunucu adresini bulma',
    'Servers': 'Sunucular',
    'Session resumption': 'Oturum devam ettirme',
    'Settings': 'Ayarlar',
    'Sign in': 'Giriş yap',
    'Sign up': 'Kayıt ol',
    'Sites outside the VPN': 'VPN dışındaki siteler',
    'Sort': 'Sırala',
    'Sort alphabetically': 'Alfabetik sırala',
    'Sort by ping': 'Ping değerine göre sırala',
    'Statistics': 'İstatistikler',
    'Statistics are unavailable': 'İstatistikler şu anda kullanılamıyor',
    'Stopping': 'DURDURULUYOR',
    'Support': 'Destek',
    'System': 'Sistem',
    'Theme': 'Tema',
    'Traffic': 'Trafik',
    'Traffic appearance': 'Trafik görünümü',
    'Traffic inspection': 'Trafik inceleme',
    'Traffic sniffing': 'Trafik inceleme',
    'Transport': 'Taşıma',
    'Connection options': 'Bağlantı seçenekleri',
    'Transport security': 'Taşıma güvenliği',
    'Try again': 'Tekrar dene',
    'DNS': 'DNS',
    'Choose an encrypted DNS provider and lookup address family.':
        'Şifreli DNS sağlayıcısını ve sorgular için adres ailesini seçin.',
    'DNS address family': 'DNS adres ailesi',
    'TLS identity': 'TLS kimliği',
    'This changes the TLS ClientHello only. Keep the server default unless you need another profile.':
        'Bu yalnızca TLS ClientHello bilgisini değiştirir. Başka bir profil gerekmiyorsa sunucu varsayılanını kullanın.',
    'Split tunneling': 'Bölünmüş tünel',
    'Choose domains or apps that use your regular connection.':
        'Normal bağlantınızı kullanacak alan adlarını veya uygulamaları seçin.',
    'Fragmentation': 'Parçalama',
    'Optional TLS hello splitting for supported TCP servers.':
        'Desteklenen TCP sunucuları için isteğe bağlı TLS hello bölme.',
    'Choose how much connection information is recorded.':
        'Ne kadar bağlantı bilgisinin kaydedileceğini seçin.',
    'Access and DNS query logs are disabled.':
        'Erişim ve DNS sorgu kayıtları kapalıdır.',
    'TRY AGAIN': 'YENİDEN DENE',
    'Your traffic is protected.': 'Trafiğiniz korunuyor.',
    'Setting up a secure connection…': 'Güvenli bağlantı hazırlanıyor…',
    'Disconnecting securely…': 'Güvenli bağlantı kesiliyor…',
    'Connection failed. Tap to retry.':
        'Bağlantı başarısız. Yeniden denemek için dokunun.',
    'Tap to protect your connection.': 'Bağlantınızı korumak için dokunun.',
    'Turkish': 'Türkçe',
    'UDP/443 behavior': 'UDP/443 davranışı',
    'Unlimited': 'Sınırsız',
    'Unlimited data': 'Sınırsız veri',
    'Unknown': 'Bilinmiyor',
    'Uploaded': 'Yüklenen',
    'VERIFICATION CODE': 'DOĞRULAMA KODU',
    'Verify your account': 'Hesabını doğrula',
    'Welcome Back': 'Tekrar hoş geldin',
    'XHTTP transport': 'XHTTP taşıması',
    'Xray core': 'Xray çekirdeği',
    'Xray logs': 'Xray kayıtları',
    'Access code copied.': 'Erişim kodu kopyalandı.',
    'Access code visible. Tap to copy.': 'Kod görünür. Kopyalamak için dokun.',
    'Access code hidden. Tap to reveal.': 'Kod gizli. Göstermek için dokun.',
    'Active subscription': 'Aktif abonelik',
    'Address family': 'Adres ailesi',
    'Address interleave': 'Adresleri araya ekleme',
    'Address race delay': 'Adres denemeleri arasındaki gecikme',
    'ALPN': 'ALPN',
    'Avoid reading application payloads. HTTP, TLS and QUIC content sniffers are disabled.':
        'Uygulama içeriklerini incelemez. HTTP, TLS ve QUIC içerik algılayıcıları kapalıdır.',
    'BBR, CUBIC and Reno are applied on Linux only.':
        'BBR, CUBIC ve Reno yalnızca Linux’ta uygulanır.',
    'Buffer size': 'Arabellek boyutu',
    'Certificate checks, ALPN, ECH, key logging and curves':
        'Sertifika denetimi, ALPN, ECH, anahtar kaydı ve eğriler',
    'Client option used by stream-up and stream-one.':
        'stream-up ve stream-one tarafından kullanılan istemci seçeneği.',
    'Comma-separated protocol names.': 'Virgülle ayrılmış protokol adları.',
    'Connection idle timeout (seconds)':
        'Bağlantı boşta kalma zaman aşımı (saniye)',
    'Controls how Xray resolves the proxy server domain.':
        'Xray’in proxy sunucu alan adını nasıl çözeceğini belirler.',
    'Controls how Xray resolves IPv4 and IPv6.':
        'Xray’in IPv4 ve IPv6 adreslerini nasıl çözeceğini belirler.',
    'Controls how Xray reuses TCP connections and carries UDP. Changes apply after reconnecting.':
        'Xray’in TCP bağlantılarını nasıl yeniden kullanacağını ve UDP’yi nasıl taşıyacağını belirler. Yeniden bağlanınca uygulanır.',
    'Core default': 'Çekirdek varsayılanı',
    'Custom HTTP headers (JSON object)': 'Özel HTTP başlıkları (JSON nesnesi)',
    'Disable DNS cache': 'DNS önbelleğini kapat',
    'Disable fallback': 'Yedek çözümlemeyi kapat',
    'Disable fallback on domain match':
        'Alan adı eşleşmesinde yedek çözümlemeyi kapat',
    'Disabled': 'Kapalı',
    'Do not try another resolver after a failure.':
        'Hata durumunda başka bir çözümleyici deneme.',
    'ECH config or DNS lookup URL': 'ECH yapılandırması veya DNS sorgu URL’si',
    'EDNS client subnet (optional)': 'EDNS istemci alt ağı (isteğe bağlı)',
    'Enabled': 'Açık',
    'FakeDNS': 'FakeDNS',
    'Force IPv4': 'IPv4 kullan',
    'Force IPv4, then IPv6': 'Önce IPv4, sonra IPv6',
    'Force IPv6': 'IPv6 kullan',
    'Force IPv6, then IPv4': 'Önce IPv6, sonra IPv4',
    'Happy Eyeballs': 'Happy Eyeballs',
    'HTTP headers / method / path': 'HTTP başlıkları / yöntemi / yolu',
    'HTTP host override (optional)': 'HTTP host geçersiz kılma (isteğe bağlı)',
    'IPv4 only': 'Yalnızca IPv4',
    'IPv4, then IPv6': 'Önce IPv4, sonra IPv6',
    'IPv6 only': 'Yalnızca IPv6',
    'IPv6, then IPv4': 'Önce IPv6, sonra IPv4',
    'Keep matching domains on their selected resolver.':
        'Eşleşen alan adlarını seçili çözümleyicide tut.',
    'Leave both off to match TCP and UDP.':
        'TCP ve UDP’yi eşleştirmek için ikisini de kapalı bırak.',
    'Leave empty for privacy': 'Gizlilik için boş bırak',
    'Limit parallel TCP connection attempts.':
        'Paralel TCP bağlantı denemelerini sınırlar.',
    'Maximum concurrent attempts': 'En fazla eşzamanlı deneme',
    'Maximum reusable seconds': 'En uzun yeniden kullanım süresi (saniye)',
    'Multiplex TCP connections': 'TCP bağlantılarını çokla',
    'Network interface': 'Ağ arayüzü',
    'One Xray domain matcher per line.':
        'Her satıra bir Xray alan adı eşleştiricisi yaz.',
    'One IP, CIDR or geoip matcher per line.':
        'Her satıra bir IP, CIDR veya geoip eşleştiricisi yaz.',
    'Parallel DNS queries': 'Paralel DNS sorguları',
    'Prefer IPv6': 'IPv6’yı tercih et',
    'Profile default': 'Profil varsayılanı',
    'Proxy server DNS strategy': 'Proxy sunucusu DNS stratejisi',
    'Race multiple configured resolvers.':
        'Yapılandırılmış çözümleyicileri paralel dene.',
    'Record traffic received by Xray outbounds.':
        'Xray çıkışlarından alınan trafiği kaydet.',
    'Record traffic sent by Xray outbounds.':
        'Xray çıkışlarından gönderilen trafiği kaydet.',
    'Record traffic sent by local Xray inbounds.':
        'Yerel Xray girişlerinden gönderilen trafiği kaydet.',
    'Record traffic received by local Xray inbounds.':
        'Yerel Xray girişlerine alınan trafiği kaydet.',
    'Requires an Xray inbound user with an email identity.':
        'E-posta kimliği olan bir Xray giriş kullanıcısı gerektirir.',
    'Serve stale DNS answers': 'Süresi dolmuş DNS yanıtlarını kullan',
    'Stale answer lifetime': 'Süresi dolmuş yanıtların saklama süresi',
    'TCP Fast Open': 'TCP Fast Open',
    'TLS session resumption': 'TLS oturumunu sürdürme',
    'Use system hosts file': 'Sistem hosts dosyasını kullan',
    'VLESS Encryption': 'VLESS şifrelemesi',
    'd remaining': ' gün kaldı',
    'days remaining': 'gün kaldı',
    'passkeys': 'geçiş anahtarı',
    'registered': 'kayıtlı',
    'GB left': 'GB kaldı',
    'Next billing': 'Sonraki fatura',
    'DPI BYPASS': 'DPI BYPASS',
    'Strategy': 'Strateji',
    'Split': 'Parçalama',
    'Split & reorder': 'Parçala ve sırala',
    'Reorder': 'Yeniden sıralama',
    'Reorder & split': 'Sırala ve parçala',
    'Retry DPI Bypass': 'DPI Bypass’ı yeniden dene',
    'Clears learned strategies. Reconnects if active.':
        'Öğrenilen stratejileri temizler. Açıksa yeniden bağlanır.',
    'Time left': 'Kalan süre',
    'Are you sure?': 'Emin misin?',
    'Deleting…': 'Siliniyor…',
    '2FA enabled': '2FA açık',
    'passkey': 'geçiş anahtarı',
    'Limited': 'Kısıtlı',
    'Expired': 'Süresi dolmuş',
    'On hold': 'Askıda',
    'Account Setup': 'Hesap kurulumu',
    'Save your unique access code to initialize your Oculve account.':
        'Oculve hesabını oluşturmak için sana özel erişim kodunu kaydet.',
    'YOUR UNIQUE ACCESS CODE': 'SANA ÖZEL ERİŞİM KODU',
    'GO TO DASHBOARD': 'PANELE GİT',
    'Terms': 'Koşullar',
    'Scan this code with your authenticator app, then enter the six-digit code it generates.':
        'Bu kodu doğrulama uygulamanla tara ve oluşturduğu altı haneli kodu gir.',
    'MANUAL SETUP KEY': 'MANUEL KURULUM ANAHTARI',
    'These one-time codes will not be shown again. Keep them somewhere safe.':
        'Bu tek kullanımlık kodlar tekrar gösterilmez. Güvenli bir yerde sakla.',
    'Copy': 'Kopyala',
    'Save file': 'Dosyayı kaydet',
    'Authenticator code': 'Doğrulama kodu',
    'No registered devices': 'Kayıtlı cihaz yok',
    'Remove TOTP': 'TOTP’yi kaldır',
    'Set up authenticator': 'Doğrulama uygulamasını kur',
    'Copy setup key': 'Kurulum anahtarını kopyala',
    'Save recovery codes': 'Kurtarma kodlarını kaydet',
    'Done': 'Tamam',
    'DELETE MY ACCOUNT': 'HESABIMI SİL',
    'Reset all devices': 'Tüm cihazları sıfırla',
    'Remove passkey': 'Geçiş anahtarını kaldır',
    'Connection events': 'Bağlantı olayları',
    'Refresh diagnostics': 'Tanılamayı yenile',
    'APP EVENTS': 'UYGULAMA OLAYLARI',
    'No connection attempts yet.': 'Henüz bağlantı denemesi yok.',
    'TCP PING CHECKS': 'TCP PİNG KONTROLLERİ',
    'No server ping checks have been recorded.':
        'Henüz sunucu ping kontrolü kaydedilmedi.',
    'XRAY DIAGNOSTICS': 'XRAY TANILAMASI',
    'Save transport settings': 'Taşıma ayarlarını kaydet',
    'Must match the server inbound.': 'Sunucudaki inbound ile aynı olmalı.',
    '0-RTT is faster when the server permits it.':
        'Sunucu izin veriyorsa 0-RTT daha hızlıdır.',
    'Paste the client parameter from xray mlkem768':
        'xray mlkem768 istemci parametresini yapıştır',
    'This value is specific to the server. The client cannot create a matching server parameter by itself.':
        'Bu değer sunucuya özeldir. İstemci tek başına eşleşen bir sunucu parametresi oluşturamaz.',
    'Padding and delay pattern (optional)':
        'Dolgu ve gecikme deseni (isteğe bağlı)',
    'Use dot-separated probability-min-max blocks; leave empty for Xray defaults.':
        'Olasılık-en az-en çok bloklarını nokta ile ayır; Xray varsayılanları için boş bırak.',
    'Path override (optional)': 'Yol geçersiz kılma (isteğe bağlı)',
    'Header padding bytes': 'Başlık dolgu baytı',
    'Leave blank unless using this limit': 'Bu sınırı kullanmıyorsan boş bırak',
    'Connection reuse limit': 'Bağlantı yeniden kullanım sınırı',
    '0 means core default': '0, çekirdek varsayılanı demektir',
    'HTTP keepalive period (seconds)': 'HTTP keepalive aralığı (saniye)',
    '0 uses core default; -1 disables':
        '0 çekirdek varsayılanını kullanır; -1 devre dışı bırakır',
    'Separate download settings (JSON)': 'Ayrı indirme ayarları (JSON)',
    'The upload and download sides can use different IPs, domains, transports or security.':
        'Yükleme ve indirme taraflarında farklı IP, alan adı, taşıma veya güvenlik kullanılabilir.',
    'Additional client extra settings (JSON)': 'Ek istemci ayarları (JSON)',
    'Client-supported XHTTP fields only. SSE response options and buffered-post limits are server-side.':
        'Yalnızca istemcinin desteklediği XHTTP alanları kullanılabilir. SSE yanıt seçenekleri ve buffered-post sınırları sunucu tarafındadır.',
    'Native uTLS Hello profile (optional)':
        'Yerel uTLS Hello profili (isteğe bağlı)',
    'Overrides the browser preset above. Use a Hello name supported by this Xray core.':
        'Yukarıdaki tarayıcı profilini geçersiz kılar. Bu Xray çekirdeğinin desteklediği bir Hello adı kullan.',
    'Disables certificate verification and is unsafe on public networks.':
        'Sertifika doğrulamasını kapatır ve herkese açık ağlarda güvenli değildir.',
    'Leave on Core default unless required.':
        'Gerekmedikçe çekirdek varsayılanında bırak.',
    'Cipher suites (optional)': 'Şifre takımları (isteğe bağlı)',
    'Separate Go cipher suite names with colons.':
        'Go şifre takımı adlarını iki nokta ile ayır.',
    'Curve preferences': 'Eğri tercihleri',
    'Supported: CurveP256, CurveP384, CurveP521, X25519 and ML-KEM hybrids.':
        'Desteklenenler: CurveP256, CurveP384, CurveP521, X25519 ve ML-KEM hibritleri.',
    '64 hex characters; multiple separated by commas':
        '64 onaltılık karakter; birden fazlasını virgülle ayır',
    'Disable system CA roots': 'Sistem CA köklerini devre dışı bırak',
    'Trust only CA certificates present in this profile or below.':
        'Yalnızca bu profilde veya aşağıda bulunan CA sertifikalarına güven.',
    'Custom CA certificate (PEM)': 'Özel CA sertifikası (PEM)',
    'Adding a custom CA makes Xray trust only this CA for TLS verification.':
        'Özel bir CA eklendiğinde Xray TLS doğrulaması için yalnızca bu CA’ya güvenir.',
    'Requires server support; this does not enable TLS 0-RTT.':
        'Sunucu desteği gerekir; bu ayar TLS 0-RTT’yi etkinleştirmez.',
    'TLS key log file path': 'TLS anahtar kayıt dosyası yolu',
    'For Wireshark diagnostics only. Anyone with this file can decrypt captured traffic.':
        'Yalnızca Wireshark tanılaması içindir. Bu dosyaya erişen herkes yakalanan trafiği çözebilir.',
    'Reduce a TCP handshake when the network allows it':
        'Ağ izin verdiğinde TCP el sıkışmasını azalt',
    'Keepalive idle': 'Keepalive boşta kalma süresi',
    'Seconds before an idle TCP connection is checked':
        'Boştaki TCP bağlantısı denetlenmeden önceki saniye',
    'Keepalive interval': 'Keepalive aralığı',
    'Seconds between TCP keepalive probes':
        'TCP keepalive yoklamaları arasındaki saniye',
    'Optional. Empty lets Xray choose the network.':
        'İsteğe bağlı. Boş bırakılırsa Xray ağı seçer.',
    'Save interface': 'Arayüzü kaydet',
    'Send through local IP': 'Yerel IP üzerinden gönder',
    'Optional source address; leave empty for automatic binding.':
        'İsteğe bağlı kaynak adresi; otomatik bağlama için boş bırak.',
    'Save source address': 'Kaynak adresini kaydet',
    'Races IPv4 and IPv6 TCP addresses. Requires an IP DNS strategy.':
        'IPv4 ve IPv6 TCP adreslerini paralel dener. IP DNS stratejisi gerekir.',
    'Delay before trying the next IP family.':
        'Diğer IP ailesini denemeden önceki gecikme.',
    'Try IPv6 addresses before IPv4.': 'IPv4’ten önce IPv6 adreslerini dene.',
    'Mix IPv4 and IPv6 addresses while racing.':
        'Paralel denemelerde IPv4 ve IPv6 adreslerini karıştır.',
    'TCP maximum segment size': 'TCP en büyük segment boyutu',
    'Optional MSS for TCP packets.':
        'TCP paketleri için isteğe bağlı MSS değeri.',
    'TCP user timeout': 'TCP kullanıcı zaman aşımı',
    'How long unacknowledged data may remain.':
        'Onaylanmamış verinin ne kadar bekleyebileceği.',
    'TCP congestion control': 'TCP tıkanıklık kontrolü',
    'TCP receive window clamp': 'TCP alım penceresi sınırı',
    'Optional maximum advertised TCP window.':
        'İsteğe bağlı en büyük TCP pencere duyurusu.',
    'Multipath TCP': 'Çok yollu TCP',
    'Linux kernel 5.6 or later.': 'Linux kernel 5.6 veya üzeri gerekir.',
    'Handshake timeout (seconds)': 'El sıkışma zaman aşımı (saniye)',
    'Uplink-only timeout (seconds)': 'Yalnızca yükleme zaman aşımı (saniye)',
    'Downlink-only timeout (seconds)': 'Yalnızca indirme zaman aşımı (saniye)',
    'Request buffer (KB)': 'İstek arabelleği (KB)',
    'Optional; Xray defaults depend on device architecture.':
        'İsteğe bağlı; Xray varsayılanları cihaz mimarisine bağlıdır.',
    'Inbound upload statistics': 'Gelen yükleme istatistikleri',
    'Inbound download statistics': 'Gelen indirme istatistikleri',
    'Outbound upload statistics': 'Giden yükleme istatistikleri',
    'Outbound download statistics': 'Giden indirme istatistikleri',
    'Controls whether Xray resolves IPv4 and IPv6.':
        'Xray’in IPv4 ve IPv6 adreslerini çözümleyip çözümlemeyeceğini belirler.',
    'Custom hosts': 'Özel hosts kayıtları',
    'Resolve through the configured servers each time.':
        'Her seferinde yapılandırılmış sunucular üzerinden çözümle.',
    'Return cached answers while refreshing them.':
        'Önbellekteki yanıtları yenilerken de kullan.',
    'Seconds after the cached DNS record expires.':
        'Önbellekteki DNS kaydı süresi dolduktan sonraki saniye.',
    'Add device hosts mappings to Xray DNS.':
        'Cihazın hosts eşlemelerini Xray DNS’e ekle.',
    'Give domains synthetic IPs so Xray can recover their names.':
        'Xray’in alan adlarını geri bulabilmesi için onlara sentetik IP ver.',
    'TCP concurrency': 'TCP eşzamanlılığı',
    'Maximum concurrent streams on one connection':
        'Tek bağlantıdaki en fazla eşzamanlı akış',
    'XUDP concurrency': 'XUDP eşzamanlılığı',
    'UDP streams carried by XUDP': 'XUDP ile taşınan UDP akışları',
    'Choose how QUIC traffic uses XUDP':
        'QUIC trafiğinin XUDP’yi nasıl kullanacağını seç',
    'Minimum version': 'En düşük sürüm',
    'Maximum version': 'En yüksek sürüm',
    'FinalMask object': 'FinalMask nesnesi',
    'Xray config object': 'Xray yapılandırma nesnesi',
    'One per line. Also supports geosite: and keyword:.':
        'Her satıra bir tane yaz. geosite: ve keyword: de desteklenir.',
    'Destination ports': 'Hedef portlar',
    'Source ports': 'Kaynak portlar',
    'Local inbound ports': 'Yerel giriş portları',
    'Inbound tags': 'Giriş etiketleri',
    'Supported by Xray on Windows and Linux.':
        'Windows ve Linux’ta Xray tarafından desteklenir.',
    'Values are regular expressions. Requires traffic sniffing.':
        'Değerler düzenli ifadedir. Trafik incelemesi gerekir.',
    'Rule name (optional)': 'Kural adı (isteğe bağlı)',
    'Webhook URL': 'Webhook URL’si',
    'Xray sends matching connection details to this address.':
        'Xray eşleşen bağlantı ayrıntılarını bu adrese gönderir.',
    'Duplicate suppression (seconds)': 'Yinelenenleri bastırma (saniye)',
    'Webhook headers (JSON object)': 'Webhook başlıkları (JSON nesnesi)',
    'I have securely saved my access code. I understand that if I lose it, ':
        'Erişim kodumu güvenli bir yerde sakladım. Kaybedersem ',
    ' to my account.': ' biliyorum.',
    'This permanently deletes your VPN account and access. Type DELETE MY ACCOUNT to continue.':
        'Bu işlem VPN hesabını ve erişimini kalıcı olarak siler. Devam etmek için HESABIMI SİL yaz.',
    'Applies to TLS and Reality profiles on the next connection.':
        'Sonraki bağlantıda TLS ve Reality profillerine uygulanır.',
    'Uses the hybrid ML-KEM-768 + X25519 handshake.':
        'ML-KEM-768 + X25519 hibrit el sıkışmasını kullanır.',
    'ML-KEM-768 + X25519 (Xray hybrid post-quantum handshake)':
        'ML-KEM-768 + X25519 (Xray hibrit kuantum sonrası el sıkışması)',
    'These controls are applied only to subscription profiles using XHTTP. Save from the page header; reconnect to apply.':
        'Bu kontroller yalnızca XHTTP kullanan abonelik profillerine uygulanır. Sayfa başlığından kaydet ve uygulamak için yeniden bağlan.',
    'Padding, request behavior, reuse and split download':
        'Dolgu, istek davranışı, yeniden kullanım ve bölünmüş indirme',
    'XMUX connection limits': 'XMUX bağlantı sınırları',
    'TLS-only controls apply to TLS profiles. SNI and the ClientHello fingerprint also apply to Reality. Changes take effect after reconnecting.':
        'Yalnızca TLS kontrolleri TLS profillerine uygulanır. SNI ve ClientHello parmak izi Reality için de geçerlidir. Değişiklikler yeniden bağlandıktan sonra uygulanır.',
    'TCP connection': 'TCP bağlantısı',
    'These Xray socket settings apply to the next connection.':
        'Bu Xray soket ayarları sonraki bağlantıda uygulanır.',
    'Xray level 0 timeouts and request buffer. Values apply after reconnecting; leave buffer empty to use the platform default.':
        'Xray seviye 0 zaman aşımı ve istek arabelleği. Değerler yeniden bağlanınca uygulanır; platform varsayılanı için arabelleği boş bırak.',
    'Counts named users active within the last 20 seconds.':
        'Son 20 saniye içinde etkin olan isimli kullanıcıları sayar.',
    'Choose Xray DNS transports, address families and fallback behavior. Changes apply after reconnecting.':
        'Xray DNS taşıma türlerini, adres ailelerini ve yedek davranışını seç. Değişiklikler yeniden bağlanınca uygulanır.',
    'FakeDNS is active in Xray. After disconnecting, cached synthetic addresses can briefly remain on the device.':
        'Xray’de FakeDNS etkin. Bağlantıyı kestikten sonra önbellekteki sentetik adresler kısa süre cihazda kalabilir.',
    'Add one domain per line. Traffic to these sites uses your regular connection after the next VPN reconnect.':
        'Her satıra bir alan adı ekle. VPN’e yeniden bağlandıktan sonra bu sitelerin trafiği normal bağlantını kullanır.',
    'Match domains, addresses, ports, processes, or HTTP traffic and send it through proxy, direct, or block.':
        'Alan adı, adres, port, işlem veya HTTP trafiğini eşleştirip proxy üzerinden geçir, doğrudan ilet veya engelle.',
    'Detect destination names in tunneled traffic for Xray routing. Reconnect to apply.':
        'Xray yönlendirmesi için tünel trafiğindeki hedef adlarını algılar. Uygulamak için yeniden bağlan.',
    'Inspect traffic for route matching.':
        'Yönlendirme eşleştirmesi için trafiği inceler.',
    'Use the detected domain for rules; keep the original IP as the connection target.':
        'Kurallar için algılanan alan adını kullan; bağlantı hedefi olarak özgün IP’yi koru.',
    'FakeDNS requires sniffing; Xray keeps FakeDNS recovery enabled while it is active.':
        'FakeDNS trafik incelemesi gerektirir; açık olduğu sürece Xray FakeDNS kurtarmasını etkin tutar.',
    'Installed Xray core': 'Yüklü Xray çekirdeği',
    'Xray itself blocks startup outside these optional version bounds. Leave both blank to clear the guard; reconnect to apply.':
        'Xray, isteğe bağlı sürüm sınırlarının dışında başlatmayı engeller. Sınırı kaldırmak için ikisini de boş bırak; uygulamak için yeniden bağlan.',
    'Configure Xray TCP and UDP masks or QUIC tuning for the selected proxy. The core validates mask-specific options when you connect.':
        'Seçili proxy için Xray TCP ve UDP maskelerini veya QUIC ayarlarını yapılandır. Çekirdek bağlanırken maskeye özel seçenekleri doğrular.',
    'Choose which sanitized Xray diagnostics are captured. Raw connection details and file logs stay disabled.':
        'Hangi arındırılmış Xray tanılamalarının kaydedileceğini seç. Ham bağlantı ayrıntıları ve dosya kayıtları kapalı kalır.',
    'Sniffed protocol': 'Algılanan protokol',
    'Webhook on match (optional)': 'Eşleşmede webhook (isteğe bağlı)',
    'Selected apps use your regular connection. All other apps stay protected by Oculve. Changes apply after the next connection.':
        'Seçilen uygulamalar normal bağlantını kullanır. Diğer tüm uygulamalar Oculve korumasında kalır. Değişiklikler sonraki bağlantıda uygulanır.',
    'No passkeys': 'Geçiş anahtarı yok',
    'Paused': 'Duraklatıldı',
    'Protocols': 'Protokoller',
    'VPN proxy': 'VPN proxy',
    'Block': 'Engelle',
    'Network': 'Ağ',
    'gRPC header disguise': 'gRPC başlığını gizle',
    'Suppress header': 'Başlığı gizle',
    'Send header': 'Başlığı gönder',
    'Pause passkeys': 'Geçiş anahtarlarını duraklat',
    'Resume passkeys': 'Geçiş anahtarlarını sürdür',
    'Pause passkeys?': 'Geçiş anahtarları duraklatılsın mı?',
    'Resume passkeys?': 'Geçiş anahtarları sürdürülsün mü?',
    'Pause': 'Duraklat',
    'Resume': 'Sürdür',
    'Remove passkey?': 'Geçiş anahtarı kaldırılsın mı?',
    'Remove TOTP?': 'TOTP kaldırılsın mı?',
    'Reset all devices?': 'Tüm cihazlar sıfırlansın mı?',
    'This security key will no longer work for sign in.':
        'Bu güvenlik anahtarı artık oturum açmak için kullanılamaz.',
    'Open Oculve': 'Oculve’yi aç',
    'Network & DNS': 'Ağ ve DNS',
    'DNS provider': 'DNS sağlayıcısı',
    'SORT': 'SIRALA',
    'DNS & IP': 'DNS ve IP',
    'Choose a private DNS service and IP family.':
        'Özel DNS sağlayıcısı ve IP ailesi seç.',
    'Automatic': 'Otomatik',
    'IPv4 + IPv6': 'IPv4 + IPv6',
    'Connection privacy': 'Bağlantı gizliliği',
    'Use the server profile defaults.':
        'Sunucu profilinin varsayılanlarını kullan.',
    'The selected server does not use TLS or Reality.':
        'Seçili sunucu TLS veya Reality kullanmıyor.',
    'TLS fingerprint': 'TLS parmak izi',
    'Server default': 'Sunucu varsayılanı',
    'The fingerprint should match your server and takes effect after reconnecting.':
        'Parmak izi sunucunla eşleşmeli; yeniden bağlandığında uygulanır.',
    'Bypass domains': 'VPN dışında kalacak alan adları',
    'Enter one domain per line. These sites bypass the VPN.':
        'Her satıra bir alan adı yaz. Bu siteler VPN dışından bağlanır.',
    'Android app routing': 'Android uygulama yönlendirmesi',
    'Advanced': 'Gelişmiş',
    'Diagnostics and optional connection behavior.':
        'Tanılama ve isteğe bağlı bağlantı davranışları.',
    'Diagnostic detail': 'Tanılama ayrıntısı',
    'Only errors, warnings and basic connection information are recorded.':
        'Yalnızca hatalar, uyarılar ve temel bağlantı bilgileri kaydedilir.',
    'TLS hello fragmentation': 'TLS el sıkışma parçalama',
    'Can help on restricted networks, but may reduce speed. Use only when needed.':
        'Kısıtlı ağlarda yardımcı olabilir ancak hızı düşürebilir. Yalnızca gerektiğinde kullan.',
    'Fragmentation is available for VLESS Reality over TCP.':
        'Parçalama yalnızca TCP üzerinden VLESS Reality için kullanılabilir.',
    'Choose sites that should use your regular connection.':
        'Normal internet bağlantını kullanacak siteleri seç.',
    'Choose option': 'Seçenek belirle',
    'Error': 'Hata',
    'Warning': 'Uyarı',
    'Info': 'Bilgi',
    'Chrome': 'Chrome',
    'Firefox': 'Firefox',
    'Safari': 'Safari',
    'Choose a DNS provider. The provider can see the domain names you look up.':
        'Bir DNS sağlayıcısı seç. Sorguladığın alan adlarını bu sağlayıcı görebilir.',
    'Changes apply after you reconnect.':
        'Değişiklikler yeniden bağlandığında uygulanır.',
    'Traffic routing': 'Trafik yönlendirme',
    'Domains outside the VPN': 'VPN dışında kalacak alan adları',
    'Sites listed here use your regular connection. Add one domain per line.':
        'Buradaki siteler normal bağlantını kullanır. Her satıra bir alan adı ekle.',
    'example.com': 'ornek.com',
    'Save domains': 'Alan adlarını kaydet',
    'Could not save settings.': 'Ayarlar kaydedilemedi.',
    'Settings saved.': 'Ayarlar kaydedildi.',
    'Android apps outside the VPN': 'VPN dışında kalacak Android uygulamaları',
    'Desktop': 'Masaüstü',
    'Tray & menu bar': 'Sistem tepsisi ve menü çubuğu',
    'Left-click action': 'Sol tıklama işlemi',
    'Right-click action': 'Sağ tıklama işlemi',
    'Open or hide the app': 'Uygulamayı göster veya gizle',
    'Connect or disconnect VPN': 'VPN’e bağlan veya bağlantıyı kes',
    'Choose a location': 'Konum seç',
    'Show the tray menu': 'Tepsi menüsünü göster',
    'On Linux, tray click behavior is controlled by the desktop environment. Use the Oculve tray menu for connection and location actions.':
        'Linux’ta tepsi tıklamalarını masaüstü ortamı yönetir. Bağlantı ve konum işlemleri için Oculve tepsi menüsünü kullan.',
    'Tap to view options': 'Seçenekleri görmek için dokun',
    'Retry': 'Yeniden dene',
    'Sign in again': 'Tekrar giriş yap',
    'Devices reset. Your subscription link has changed.':
        'Cihazlar sıfırlandı. Abonelik bağlantın değişti.',
    'Recovery codes copied.': 'Kurtarma kodları kopyalandı.',
    'Direct local API': 'Doğrudan yerel API',
    'Could not load installed apps.': 'Yüklü uygulamalar yüklenemedi.',
    'Permanently delete?': 'Kalıcı olarak silinsin mi?',
    'Your account and VPN access cannot be restored.':
        'Hesabın ve VPN erişimin geri yüklenemez.',
    'Delete permanently': 'Kalıcı olarak sil',
    'Quit Oculve': 'Oculve’den çık',
    'Merge advanced Xray options into every imported server. Object fields merge recursively; arrays replace the matching field. Reconnect to apply. Invalid core options prevent connection.':
        'Gelişmiş Xray seçeneklerini içe aktarılan her sunucuya uygular. Nesne alanları özyinelemeli birleştirilir; diziler eşleşen alanı değiştirir. Uygulamak için yeniden bağlan. Geçersiz çekirdek seçenekleri bağlantıyı engeller.',
    'Not set up': 'Kurulmadı',
    'Pause 2FA?': '2FA duraklatılsın mı?',
    'Resume 2FA?': '2FA yeniden başlatılsın mı?',
    'This changes the authenticator requirement for future sign-ins.':
        'Bu, sonraki oturum açmalarda doğrulama uygulamasının istenip istenmeyeceğini değiştirir.',
    'Confirm': 'Onayla',
    'Remove authenticator?': 'Doğrulama uygulaması kaldırılsın mı?',
    'This removes your authenticator secret and recovery codes.':
        'Doğrulama uygulaması gizli anahtarını ve kurtarma kodlarını kaldırır.',
    'Remove': 'Kaldır',
    'Authenticator removed.': 'Doğrulama uygulaması kaldırıldı.',
    '2FA updated.': '2FA güncellendi.',
    'This affects passkey sign-in on your account.':
        'Bu, hesabındaki geçiş anahtarıyla oturum açmayı etkiler.',
    'Passkeys can be toggled back on at any time.':
        'Geçiş anahtarlarını istediğin zaman yeniden etkinleştirebilirsin.',
    'Passkeys updated.': 'Geçiş anahtarları güncellendi.',
    'Passkey': 'Geçiş anahtarı',
    'This passkey will no longer sign in to your account.':
        'Bu geçiş anahtarı artık hesabında oturum açamaz.',
    'Passkey removed.': 'Geçiş anahtarı kaldırıldı.',
    'This device': 'Bu cihaz',
    'Security key': 'Güvenlik anahtarı',
    'Synced': 'Eşitlendi',
    'Device only': 'Yalnızca cihazda',
    'Added': 'Eklendi',
    'Last used': 'Son kullanım',
    'Registered device': 'Kayıtlı cihaz',
    'Unknown OS': 'Bilinmeyen işletim sistemi',
    'Last active': 'Son etkinlik',
    'Authenticator sign-in will be disabled.':
        'Doğrulama uygulamasıyla oturum açma devre dışı bırakılacak.',
    'Connection setup': 'Bağlantı kurulumu',
    'Performance': 'Performans',
    'Enter the code from your authenticator.':
        'Doğrulama uygulamanızdaki kodu girin.',
    'FinalMask': 'FinalMask',
    'IP / CIDR': 'IP / CIDR',
    'Local inbound IP / CIDR': 'Yerel gelen bağlantı IP / CIDR',
    'Measuring VPN server ping': 'VPN sunucusu ping değeri ölçülüyor',
    'One endpoint or Xray DNS server JSON object per line. Supports UDP, TCP, DoH, DoQ and localhost. +local bypasses proxy routing; h2c is unencrypted.':
        'Her satıra bir adres veya Xray DNS sunucusu JSON nesnesi yazın. UDP, TCP, DoH, DoQ ve localhost desteklenir. +local proxy yönlendirmesini atlar; h2c şifrelenmemiştir.',
    'One mapping per line (for example domain:example.com=93.184.216.34). Separate multiple targets with |.':
        'Her satıra bir eşleme yazın (ör. domain:example.com=93.184.216.34). Birden çok hedefi | ile ayırın.',
    'Paste a static ECHConfig or use udp://, https:// or h2c://.':
        'Statik bir ECHConfig yapıştırın veya udp://, https:// ya da h2c:// kullanın.',
    'Process name / path': 'İşlem adı / yolu',
    'SNI / server name': 'SNI / sunucu adı',
    'Setup key copied.': 'Kurulum anahtarı kopyalandı.',
    'Source IP / CIDR': 'Kaynak IP / CIDR',
    'Use Xray FinalMask JSON: tcp, udp, and/or quicParams. Leave {} to remove app-level overrides.':
        'Xray FinalMask JSON biçimini kullanın: tcp, udp ve/veya quicParams. Uygulama düzeyindeki geçersiz kılmaları kaldırmak için {} bırakın.',
    'User / email': 'Kullanıcı / e-posta',
    'milliseconds': 'milisaniye',
  };

  static String translate(String source, String languageCode) =>
      switch (languageCode) {
        'es' => _es[source] ?? source,
        'tr' => _tr[source] ?? source,
        _ => source,
      };

  static bool hasTranslation(String source, String languageCode) =>
      switch (languageCode) {
        'es' => _es.containsKey(source),
        'tr' => _tr.containsKey(source),
        _ => true,
      };
}

extension AppStringsContext on BuildContext {
  String tr(String source) =>
      AppStrings.translate(source, Localizations.localeOf(this).languageCode);

  String daysRemaining(int count) {
    final language = Localizations.localeOf(this).languageCode;
    return switch (language) {
      'es' => count == 1 ? '1 día restante' : '$count días restantes',
      'tr' => '$count gün kaldı',
      _ => '$count d remaining',
    };
  }

  String saveApps(int count) {
    final language = Localizations.localeOf(this).languageCode;
    return switch (language) {
      'es' =>
        count == 1 ? 'Guardar 1 aplicación' : 'Guardar $count aplicaciones',
      'tr' => '$count uygulamayı kaydet',
      _ => count == 1 ? 'Save 1 app' : 'Save $count apps',
    };
  }
}
