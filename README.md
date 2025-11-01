# Flujo de trabajo: Conversión batch editable <-> PDF (n8n + LibreOffice)

Este repositorio contiene un worker bash que convierte documentos editables a PDF usando LibreOffice (`soffice`) y un workflow de n8n que permite dispararlo por Cron o por Webhook HTTP. El README recoge los pasos para importar, ejecutar y verificar el flujo en WSL (Debian) usando `n8n start`.

## Requisitos

- WSL Debian (o Linux) con usuario que ejecuta n8n (en este repo: `rodrigo`).
- n8n instalado y accesible (UI por defecto en `http://localhost:5678`).
- LibreOffice (`soffice`) instalado en el sistema.
- Bash, `timeout`, `flock`, `nohup`, `curl`.

Estructura relevante del repo:

- `scripts/convert_worker.sh` — worker batch (lock, timeout, logging).
- `scripts/n8n_invoke_probe.sh` — wrapper llamado por n8n; registra `exec_node.log` y lanza el worker en background.
- `n8n/workflow-batch-folder-converter-webhook-active.json` — workflow preparado para importar (activo).
- Carpetas runtime: `input/`, `output/`, `processed/`, `failed/`, `logs/`.

---

## 1) Arrancar n8n (WSL)

En una ventana de WSL (o terminal donde quieras iniciar n8n manualmente), ejecuta:

```bash
# inicia n8n (si lo instalaste globalmente)
n8n start
```

Si usas systemd, pm2 o Docker, arranca n8n según tu método habitual.

> Nota: la UI por defecto está en `http://localhost:5678`.

---

## 2) Importar el workflow en la UI de n8n

1. Abre `http://localhost:5678` y entra en Workflows.
2. Pulsa `Import` y selecciona `n8n/workflow-batch-folder-converter-webhook-active.json` del repo.
3. Una vez importado, abre el workflow para editarlo.

---

## 3) Configurar el nodo `Execute Batch Convert`

El nodo `Execute` del workflow sólo expone un campo llamado **Command**. Pega exactamente esta línea en dicho campo (usa la ruta absoluta del repo):

```
/bin/bash -lc "/home/rodrigo/GitHub/FlujosDeTrabajo/scripts/n8n_invoke_probe.sh /home/rodrigo/GitHub/FlujosDeTrabajo/logs /home/rodrigo/GitHub/FlujosDeTrabajo/.convert_lock 300"
```

Qué hace esta llamada:
- Fuerza el uso de `/bin/bash` y ejecuta la cadena con `-lc` (login-like + comando). 
- `n8n_invoke_probe.sh` grabará una línea en `./logs/exec_node.log` y lanzará el worker en background con `nohup`.

---

## 4) Test / Producción: Test URL vs Production URL

- **Test URL**: la URL que ves en el editor (normalmente contiene `/webhook-test/...`). Úsala para pruebas interactivas desde el editor.
- **Production URL**: la URL que usarán clientes reales. Para que funcione, el workflow debe estar marcado `Active`.

Para invocar desde un cliente externo (o desde un script), copia la **Production URL** del nodo Webhook y úsala con `curl`.

---

## 5) Ejecución y verificación (ventanas A y B)

Sigue estos pasos en dos terminales para verificar interactivamente:

- Ventana A — monitor (tail):

```bash
# Ver trazas en tiempo real
cd /home/rodrigo/GitHub/FlujosDeTrabajo
tail -n 0 -f ./logs/exec_node.log ./logs/convert.log
```

- Ventana B — disparar el webhook (ejemplo con header secreto `X-Worker-Token`):

```bash
curl -v -X POST 'http://localhost:5678/webhook-test/batch-convert' \
  -H 'Content-Type: application/json' \
  -H 'X-Worker-Token: mi_secreto' \
  -d '{}'
```

Notas:
- Si estás en producción, sustituye la `Test URL` por la `Production URL` (copiar desde el nodo Webhook) y asegúrate que el workflow esté `Active`.
- El `n8n_invoke_probe.sh` registrará en `./logs/exec_node.log` la invocación; después verás la actividad del worker en `./logs/convert.log` y los `*.pdf` en `./output`.
tar czf ~/FlujosDeTrabajo_backup_${TS}.tar.gz -C /home/rodrigo GitHub/FlujosDeTrabajo
tail -n 200 ./logs/convert.log
---

