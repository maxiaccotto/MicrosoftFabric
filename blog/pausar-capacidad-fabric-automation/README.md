# Pausar Microsoft Fabric automáticamente con Azure Automation

Runbook de PowerShell para pausar y reanudar una capacidad de Microsoft Fabric con horarios, desde Azure Automation y con identidad administrada. Sirve para ambientes de desarrollo y testing, y también para producción cuando la capacidad solo se usa para una carga nocturna.

📖 Post completo: _Próximamente_
🎥 Video con la demo: _Próximamente_

## Qué incluye

| Archivo | Qué hace |
|---|---|
| `runbook-pausar-reanudar.ps1` | Runbook que pausa o reanuda la capacidad según el parámetro `Accion`. Consulta el estado antes de actuar, valida la respuesta de Azure y espera a que la capacidad quede `Paused` o `Active` |
| `rol-personalizado.json` | Rol de Azure con solo las 4 acciones necesarias (read, write, suspend y resume), como recomienda Microsoft en lugar de Contributor |

## Requisitos

- Una capacidad de Microsoft Fabric (SKU F) en Azure.
- Una cuenta de Azure Automation con **identidad administrada asignada por el sistema** activada.
- Runbook de PowerShell con runtime **7.2 o superior** (los módulos `Az.Accounts` vienen incluidos).

## Cómo usarlo

1. **Crear el rol:** completá `<id-de-suscripcion>` y `<grupo-de-recursos>` en `rol-personalizado.json` y crealo:
   ```powershell
   New-AzRoleDefinition -InputFile .\rol-personalizado.json
   ```
2. **Asignar el rol** sobre la capacidad de Fabric (Control de acceso (IAM) → Agregar asignación de rol) a la identidad administrada de la cuenta de Automation.
3. **Crear el runbook** (Runbooks → Crear un runbook, tipo PowerShell), pegar `runbook-pausar-reanudar.ps1`, probarlo en el **Panel de prueba** y **Publicar**.
4. **Programarlo** con dos programaciones (Vincular a programación), con tu zona horaria:
   - "Reanudar 8:00", de lunes a viernes, con `Accion = Reanudar`
   - "Pausar 19:00", con `Accion = Pausar`

En cada programación se cargan los parámetros: `SubscriptionId`, `ResourceGroupName` y `CapacityName`, más `Accion`. Tus datos quedan en Azure, no en el código.

## A tener en cuenta

- **Al pausar se factura** el consumo suavizado y los excedentes que quedaban pendientes, y el contenido de la capacidad no está disponible hasta reanudar.
- **En producción con carga nocturna:** si el modelo semántico usa **Direct Lake** o está en un workspace de la capacidad, al pausarla los reportes dejan de funcionar. Para pausar en producción, el modelo tiene que estar en **Import** y en un workspace **fuera de la capacidad** (Pro o PPU), y el refresh tiene que terminar antes de pausar.
- **Las URLs con `?`:** en PowerShell, `"$variable?api-version=..."` no funciona, porque `?` puede ser parte del nombre de una variable. Por eso el runbook usa `"${basePath}?api-version=..."`. Y `Invoke-AzRestMethod` no falla ante un error HTTP: hay que revisar `StatusCode`, como hace el runbook.
- El ahorro depende del horario: prendida de lunes a viernes de 8 a 18 son 50 de las 168 horas semanales, cerca de un 70% menos de horas facturadas.

---
## Sobre el autor

**Maximiliano (Maxi) Accotto** es socio fundador de [TriggerDB Consulting](https://www.triggerdb.com)
y especialista en SQL Server y la plataforma de datos de Microsoft, con más de 20 años de experiencia.
Fue 14 veces Microsoft MVP en Data Platform y hoy es MVP Reconnect.

**TriggerDB** es una consultora especializada en SQL Server, Azure SQL, Power BI y Microsoft Fabric:
DBA, performance, migraciones, arquitectura de datos, IA empresarial y capacitaciones.
Oficinas en Buenos Aires y Miami.

🌐 [triggerdb.com](https://www.triggerdb.com) · 🎥 [YouTube](https://www.youtube.com/@maxiaccotto) ·
💼 [LinkedIn](https://www.linkedin.com/in/maxiaccotto/) · ✉️ info@triggerdb.com
