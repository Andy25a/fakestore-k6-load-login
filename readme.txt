EJERCICIO 1 - PRUEBA DE CARGA LOGIN CON FAKE STORE API (K6)
================================================================

1. Descripción general
----------------------
Este proyecto implementa una prueba de carga sobre el endpoint de login:
https://fakestoreapi.com/auth/login

La solución se desarrolla con K6 y datos parametrizados desde CSV, cumpliendo los objetivos de throughput (TPS), tiempo de respuesta máximo y tasa de error definidos para el ejercicio.
Con esta base, la prueba queda versionada como código, se puede repetir en otra máquina y deja evidencia en archivos (JSON, HTML, log) bajo la carpeta reports.

2. Objetivo y alcance
---------------------
Ejecutar una prueba de carga del endpoint de login y validar de forma automática:
- Al menos 20 peticiones por segundo (TPS).
- Tiempo de respuesta máximo de 1,5 segundos.
- Tasa de error técnica menor al 3 % (según métrica estándar de K6).

Alcance de la automatización:
- Petición HTTP POST con cuerpo JSON (usuario y contraseña) leídos del CSV.
- Umbrales (thresholds) en el script para fallar la ejecución si no se cumplen los límites.
- Checks por iteración para trazabilidad en el reporte HTML.

3. Stack tecnológico
--------------------
- k6: 0.49.0 o superior
- PowerShell: 5.1 o superior
- Windows 10/11

Opcional:
- k6-html-reporter: 3.x o superior (reporte HTML adicional; el script ya genera HTML vía handleSummary).

4. Estructura del proyecto
--------------------------
Ruta base: carpeta raíz del proyecto tras clonar o descomprimir el repositorio (donde están run.cmd, run.ps1 y la carpeta scripts).
Ejemplo en Windows: C:\Users\andii\fakestore-k6-load-login

Estructura principal:
- scripts/login-load-test.js: escenario de carga, umbrales, checks y generación de reportes (JSON/HTML).
- data/users.csv: datos parametrizados (user, passwd).
- run.ps1: flujo de ejecución (k6, rutas con marca de tiempo, log, dashboard web opcional, apertura del HTML).
- run.cmd: acceso rápido; invoca run.ps1. Cómo usarlo: ver sección 7.
- readme.txt: este documento.
- conclusiones.txt: hallazgos y conclusiones del ejercicio.
- reports/html/: reportes HTML por ejecución (k6-reporter embebido).
- reports/summaries/: resumen JSON por ejecución.
- reports/dashboard/: export HTML del dashboard web de k6 (si se activó).
- reports/logs/: log de consola por ejecución.

5. Datos de prueba utilizados (parametrizados)
----------------------------------------------
Los datos no están hardcodeados en el script de iteración: se cargan desde data/users.csv mediante SharedArray.

Columnas:
- user
- passwd

Valores de ejemplo (mismo contenido que en el CSV del repositorio):
- donero,ewedon
- kevinryan,kev02937@
- johnd,m38rmF$
- derek,jklg*_56
- mor_2314,83r5^_

Nota:
Son credenciales de demostración del API de ejemplo; no deben reutilizarse en sistemas reales.

6. Pre-requisitos
-----------------
- Sistema operativo Windows con PowerShell habilitado para ejecutar scripts.
- k6 instalado y disponible en PATH (o en la ruta por defecto C:\Program Files\k6\k6.exe, que run.ps1 intenta como respaldo).
- Conexión a Internet.

7. Cómo ejecutar el proyecto
----------------------------
Hay dos formas de lanzar la misma automatización. Use solo una (el resultado es el mismo salvo preferencias de consola).

--- Opción 1: usar run.cmd (la más simple)

run.cmd es un archivo que ya está en la carpeta del proyecto.

Pasos con doble clic (sin abrir CMD a mano):
  Paso 1: Abra el Explorador de archivos de Windows.
  Paso 2: Entre en la carpeta del proyecto (la que tiene run.cmd y run.ps1).
  Paso 3: Haga doble clic en run.cmd.
  Paso 4: Espere a que termine la ventana; al finalizar puede abrirse el reporte HTML en el navegador.

Pasos desde CMD o PowerShell:
  Paso 1: Abra CMD o PowerShell (o la terminal del IDE).
  Paso 2: Vaya a la carpeta del proyecto. Ejemplo: cd C:\Users\andii\fakestore-k6-load-login
  Paso 3: Escriba run.cmd y pulse Enter.
  Paso 4: Espere a que termine el proceso.

--- Opción 2: invocar PowerShell usted mismo

  Paso 1: Abra CMD o PowerShell.
  Paso 2: Vaya a la carpeta del proyecto con cd (igual que en la Opción 1).
  Paso 3: Ejecute:
          powershell -ExecutionPolicy Bypass -File .\run.ps1
  Paso 4: Espere a que finalice.

Parámetros opcionales (al final de la línea, tanto con run.cmd como con el comando de la Opción 2):
- -NoWebDashboard   (no activa el dashboard web de k6 en http://127.0.0.1:5665 durante la prueba)
- -SkipOpenReport   (no abre el reporte HTML al terminar; igualmente se generan archivos en reports\)

Ejemplos:
  run.cmd -NoWebDashboard
  powershell -ExecutionPolicy Bypass -File .\run.ps1 -SkipOpenReport

8. Ejecución alternativa (solo k6)
----------------------------------
Opción para quien quiera ejecutar k6 directamente, sin run.ps1/run.cmd.

Comando de ejemplo:

  k6 run -e REPORT_TIMESTAMP=manual-001 -e REPORT_SUMMARY_FILE=reports/summaries/k6-summary-manual-001.json -e REPORT_HTML_FILE=reports/html/k6-report-manual-001.html .\scripts\login-load-test.js

Resultado:
- Genera JSON y HTML según las rutas indicadas en -e.
- No ejecuta la misma envoltura que run.ps1 (log unificado, dashboard, etc.).

9. Entregables del repositorio
-------------------------------
Esta sección enumera lo que acompaña al proyecto:
- Código fuente del script de carga (K6).
- Datos parametrizados (CSV).
- Scripts de ejecución (run.ps1 / run.cmd).
- Archivos generados en reports tras cada ejecución (cuando ya se ha corrido la prueba).
- Instrucciones (readme.txt).
- Hallazgos y conclusiones (conclusiones.txt).

10. Verificación posterior a la ejecución
-----------------------------------------
Al finalizar, conviene revisar:
1) La consola no muestra fallo de umbrales (thresholds) de k6.
2) Existen archivos nuevos en reports\summaries, reports\html y reports\logs (y en reports\dashboard si usó el dashboard web).
3) El resumen JSON y el HTML permiten comprobar TPS, duración máxima y tasa de error.

En el reporte HTML, la pestaña "Checks & Groups" muestra los checks por petición. Las tres validaciones principales del ejercicio (TPS, tiempo máximo, error) se evalúan como thresholds globales en el JSON y en el resumen de k6.

11. Consideraciones técnicas
----------------------------
- El servicio es público: latencia y disponibilidad pueden variar según red y hora.
- La tasa de error del ejercicio se basa en la métrica http_req_failed de k6; el formato de Rate en k6 es entre 0 y 1 (por eso rate<0.03 equivale a <3 %).
- run.ps1 ajusta codificación de consola y filtra secuencias ANSI en el log para lectura más clara en editor de texto.

12. Resultado esperado
----------------------
La ejecución final debe completar satisfactoriamente:
- Completar el escenario de carga sin violar los umbrales definidos en login-load-test.js.
- Dejar evidencia en reports (JSON, HTML, log; y dashboard exportado si aplica).
- Permitir concluir si se cumplieron los requisitos de TPS, tiempo de respuesta y tasa de error a partir del informe generado.
